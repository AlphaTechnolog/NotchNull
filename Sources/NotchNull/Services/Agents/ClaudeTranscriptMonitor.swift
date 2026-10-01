import Foundation

/// Live Claude Code sessions from local transcripts (~/.claude/projects/*/*.jsonl), so sessions
/// appear without any setup. The optional hooks add instant approval alerts on top; this monitor
/// never overrides a hook's "needs you" state.
@MainActor
final class ClaudeTranscriptMonitor {
    private let store: AgentSessionStore
    private let queue = DispatchQueue(label: "dev.notchnull.claude-transcripts", qos: .utility)
    private nonisolated(unsafe) let reader = JSONLTailReader()
    private nonisolated(unsafe) var known: [URL: Observed] = [:]
    private var timer: Timer?

    private struct Observed {
        var sessionID: String
        var cwd: String
        var status: AgentSession.Status
        var detail: String?
    }

    private enum Change {
        case update(id: String, cwd: String, status: AgentSession.Status, detail: String?, silent: Bool)
        case quiet(id: String)
    }

    init(store: AgentSessionStore) {
        self.store = store
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        poll()
    }

    private func poll() {
        queue.async { [weak self] in
            guard let self else { return }
            let changes = self.scan()
            DispatchQueue.main.async {
                MainActor.assumeIsolated { changes.forEach(self.apply) }
            }
        }
    }

    private func apply(_ change: Change) {
        guard Preferences.shared.agentsEnabled else { return }
        switch change {
        case .update(let id, let cwd, let status, let detail, _):
            let current = store.sessions.first { $0.id == id }
            // Hooks know about approvals; transcripts cannot, so keep a hook's needs-you until the
            // transcript shows real progress (a tool result or the end of the turn).
            if current?.status.isNeedsYou == true, status == .running, current?.detail == detail { return }
            store.upsert(id: id, provider: .claude) { session in
                session.cwd = cwd
                session.status = status
                if let detail { session.detail = detail }
            }
        case .quiet(let id):
            guard let current = store.sessions.first(where: { $0.id == id }), current.status == .running else { return }
            store.upsert(id: id, provider: .claude) { $0.status = .idle }
        }
    }

    // MARK: Scanning (background queue)

    private nonisolated func scan() -> [Change] {
        let now = Date()
        let active = recentTranscripts(since: now.addingTimeInterval(-Constants.Agents.codexActiveWindow))
        var changes: [Change] = []
        for file in active {
            let firstSight = known[file] == nil
            if firstSight {
                let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? UInt64) ?? 0
                reader.seed(file, at: size > 196_608 ? size - 196_608 : 0)
                known[file] = Observed(sessionID: file.deletingPathExtension().lastPathComponent, cwd: "", status: .idle)
            }
            guard var observed = known[file] else { continue }
            let before = observed.status
            let beforeDetail = observed.detail
            reader.readNewLines(of: file, markers: ["\"type\":\"user\"".utf8Data, "\"type\":\"assistant\"".utf8Data, "\"subtype\":\"turn_duration\"".utf8Data]) { line in
                guard let json = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                      json["isSidechain"] as? Bool != true,
                      let type = json["type"] as? String else { return }
                if let id = json["sessionId"] as? String { observed.sessionID = id }
                if let cwd = json["cwd"] as? String { observed.cwd = cwd }
                let message = json["message"] as? [String: Any] ?? [:]
                switch type {
                case "user":
                    switch Self.userLine(json) {
                    case .turn(let prompt):
                        observed.status = .running
                        if let prompt { observed.detail = prompt }
                    case .interrupted:
                        // No Stop hook fires for an interrupt; this line is the only sign the turn ended.
                        observed.status = .idle
                    case .bookkeeping:
                        break
                    }
                case "assistant":
                    switch message["stop_reason"] as? String {
                    case "end_turn", "stop_sequence", "max_tokens":
                        // The final message is written block by block: a thinking-only line comes
                        // first, then the text. Only the text (or turn_duration) closes the turn,
                        // so the banner never shows the last tool as the summary.
                        guard let summary = Self.text(of: message).flatMap({ ClaudeHookHandler.summary($0, limit: 160) }) else { break }
                        observed.status = .done
                        observed.detail = summary
                    case "tool_use":
                        observed.status = .running
                        if let tool = Self.tool(of: message) { observed.detail = "Using \(tool)…" }
                    default:
                        observed.status = .running
                    }
                case "system" where json["subtype"] as? String == "turn_duration":
                    if observed.status == .running {
                        observed.status = .done
                        if observed.detail?.hasPrefix("Using ") == true { observed.detail = "Finished its turn" }
                    }
                default:
                    break
                }
            }
            known[file] = observed
            if firstSight || observed.status != before || observed.detail != beforeDetail {
                guard !observed.cwd.isEmpty else { continue }
                changes.append(.update(id: observed.sessionID, cwd: observed.cwd, status: observed.status, detail: observed.detail, silent: firstSight))
            }
        }
        // Transcripts that went quiet are no longer live.
        for (file, observed) in known where !active.contains(file) {
            known[file] = nil
            reader.forget(file)
            changes.append(.quiet(id: observed.sessionID))
        }
        return changes
    }

    enum UserLine: Equatable {
        case turn(prompt: String?)
        case interrupted
        case bookkeeping
    }

    /// Not every `user` line starts a turn: Claude Code also writes one for an interrupt, for the
    /// output of local commands (`/model`, `/context`, `!ls`) and for its own notes to the model.
    nonisolated static func userLine(_ json: [String: Any]) -> UserLine {
        if json["isMeta"] as? Bool == true || json["isCompactSummary"] as? Bool == true { return .bookkeeping }
        let message = json["message"] as? [String: Any] ?? [:]
        guard let text = message["content"] as? String ?? text(of: message) else { return .turn(prompt: nil) }
        let start = text.drop(while: \.isWhitespace)
        if start.hasPrefix(Constants.Agents.claudeInterruptPrefix) { return .interrupted }
        if Constants.Agents.claudeLocalOutputPrefixes.contains(where: { start.hasPrefix($0) }) { return .bookkeeping }
        return .turn(prompt: message["content"] is String ? ClaudeHookHandler.summary(text, limit: 80) : nil)
    }

    private nonisolated static func text(of message: [String: Any]) -> String? {
        (message["content"] as? [[String: Any]])?.first { $0["type"] as? String == "text" }?["text"] as? String
    }

    private nonisolated static func tool(of message: [String: Any]) -> String? {
        (message["content"] as? [[String: Any]])?.last { $0["type"] as? String == "tool_use" }?["name"] as? String
    }

    private nonisolated func recentTranscripts(since date: Date) -> [URL] {
        let fm = FileManager.default
        guard let projects = try? fm.contentsOfDirectory(at: Constants.Paths.claudeProjects, includingPropertiesForKeys: nil) else { return [] }
        var result: [URL] = []
        for project in projects {
            guard let files = try? fm.contentsOfDirectory(at: project, includingPropertiesForKeys: [.contentModificationDateKey]) else { continue }
            for file in files where file.pathExtension == "jsonl" {
                let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                if modified >= date { result.append(file) }
            }
        }
        return result
    }
}
