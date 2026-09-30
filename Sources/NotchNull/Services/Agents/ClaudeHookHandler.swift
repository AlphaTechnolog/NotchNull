import Foundation

/// Translates Claude Code hook payloads into session state.
@MainActor
struct ClaudeHookHandler {
    let store: AgentSessionStore

    func handle(_ request: AgentEventServer.Request) {
        guard let json = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
              let sessionID = json["session_id"] as? String,
              let event = json["hook_event_name"] as? String else { return }
        let cwd = json["cwd"] as? String
        let bundle = request.headers["x-term-bundle"].flatMap { $0.isEmpty ? nil : $0 }
            ?? request.headers["x-term-program"].flatMap { Constants.terminalBundleIDs[$0] }
        let tty = request.headers["x-tty"].flatMap { $0.isEmpty || $0.contains("?") ? nil : $0 }

        if event == "SessionEnd" {
            store.remove(id: sessionID)
            return
        }

        store.upsert(id: sessionID, provider: .claude) { session in
            if let cwd { session.cwd = cwd }
            if let bundle { session.terminalBundleID = bundle }
            if let tty { session.tty = tty }
            switch event {
            case "SessionStart":
                if session.status != .running { session.status = .idle }
            case "UserPromptSubmit":
                session.status = .running
                if let prompt = (json["prompt"] as? String).flatMap({ Self.summary($0, limit: 80) }) { session.detail = prompt }
            case "PermissionRequest":
                session.status = .needsYou(Self.describePermission(json))
            case "Notification":
                let kind = json["notification_type"] as? String
                let message = (json["message"] as? String) ?? "Claude needs your attention"
                if kind == "idle_prompt" {
                    if session.status != .running { session.status = .done }
                } else if kind == "permission_prompt" || message.localizedCaseInsensitiveContains("permission") {
                    if !session.status.isNeedsYou { session.status = .needsYou(message) }
                } else {
                    session.status = .needsYou(message)
                }
            case "PostToolUse":
                if session.status.isNeedsYou || session.status == .idle { session.status = .running }
            case "Stop":
                session.status = .done
                // The transcript's final text replaces this a moment later; never show the last tool.
                if session.detail?.hasPrefix("Using ") == true { session.detail = "Finished its turn" }
            default:
                break
            }
        }
    }

    static func describePermission(_ json: [String: Any]) -> String {
        let tool = (json["tool_name"] as? String) ?? "a tool"
        let input = json["tool_input"] as? [String: Any] ?? [:]
        switch tool {
        case "Bash":
            if let command = input["command"] as? String { return "Wants to run \(firstLine(command, limit: 64))" }
        case "Edit", "MultiEdit", "Write", "NotebookEdit":
            if let path = (input["file_path"] as? String) ?? (input["notebook_path"] as? String) {
                return "Wants to edit \(URL(fileURLWithPath: path).lastPathComponent)"
            }
        case "WebFetch":
            if let url = (input["url"] as? String).flatMap(URL.init(string:)), let host = url.host {
                return "Wants to fetch \(host)"
            }
        case "AskUserQuestion":
            // The question itself is what the user needs to see, not the tool's name.
            let questions = input["questions"] as? [[String: Any]] ?? []
            if let question = questions.first?["question"] as? String, !question.isEmpty {
                let more = questions.count > 1 ? " (+\(questions.count - 1) more)" : ""
                return firstLine(question, limit: 110) + more
            }
            return "Has a question for you"
        case "ExitPlanMode":
            return "Has a plan ready for your review"
        case "Read":
            if let path = input["file_path"] as? String { return "Wants to read \(URL(fileURLWithPath: path).lastPathComponent)" }
        case "Glob", "Grep":
            return "Wants to search the code"
        case "WebSearch":
            if let query = input["query"] as? String { return "Wants to search the web for “\(firstLine(query, limit: 60))”" }
        case "Task", "Agent":
            return "Wants to start a helper agent"
        default:
            break
        }
        return "Wants to use \(readableToolName(tool))"
    }

    /// `mcp__github__create_issue` → "create issue (github)"; `SomeTool` → "some tool".
    nonisolated static func readableToolName(_ tool: String) -> String {
        let parts = tool.components(separatedBy: "__")
        if parts.count >= 3, parts[0] == "mcp" {
            return "\(words(parts[2...].joined(separator: " "))) (\(words(parts[1])))"
        }
        return words(tool)
    }

    private nonisolated static func words(_ name: String) -> String {
        var result = ""
        for character in name {
            if character == "_" || character == "-" {
                result.append(" ")
            } else if character.isUppercase, let last = result.last, last.isLowercase {
                result.append(" ")
                result.append(character)
            } else {
                result.append(character)
            }
        }
        return result.lowercased().trimmingCharacters(in: .whitespaces)
    }

    nonisolated static func firstLine(_ text: String, limit: Int) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        return line.count > limit ? String(line.prefix(limit - 1)) + "…" : line
    }

    /// Readable plain-text summary of a message: markdown markers and tag-wrapped lines removed,
    /// consecutive lines joined until `limit`. Nil when nothing readable is left (e.g. a
    /// `<task-notification>` or slash-command wrapper).
    nonisolated static func summary(_ text: String, limit: Int) -> String? {
        let lines = text.split(whereSeparator: \.isNewline)
            .map { line -> String in
                var cleaned = line.trimmingCharacters(in: .whitespaces)
                while let first = cleaned.first, "#>-*".contains(first) { cleaned.removeFirst() }
                return cleaned
                    .replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "`", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty && !$0.hasPrefix("<") && !$0.hasPrefix("|") }
        guard !lines.isEmpty else { return nil }
        var result = ""
        for line in lines {
            let joined = result.isEmpty ? line : result + (result.hasSuffix(".") || result.hasSuffix(":") ? " " : ". ") + line
            if joined.count > limit {
                if result.isEmpty { return String(line.prefix(limit - 1)) + "…" }
                break
            }
            result = joined
        }
        return result
    }
}
