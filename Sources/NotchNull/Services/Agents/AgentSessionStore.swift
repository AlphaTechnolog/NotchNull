import Combine
import Foundation
import SwiftUI

struct AgentSession: Identifiable, Equatable {
    enum Status: Equatable {
        case idle
        case running
        case needsYou(String)
        case done
    }

    let id: String
    let provider: AgentProvider
    var cwd: String
    var status: Status
    var turnStartedAt: Date?
    var lastTurnDuration: TimeInterval?
    var updatedAt: Date
    var terminalBundleID: String?
    var tty: String?
    var detail: String?
    var origin: String?

    var project: String {
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        return name.isEmpty ? provider.title : name
    }

    var needsAttention: Bool {
        if case .needsYou = status { return true }
        return false
    }
}

/// Live agent sessions from Claude Code hooks and Codex rollout logs. Drives the needs-you,
/// running and done activities.
@MainActor
final class AgentSessionStore: ObservableObject {
    @Published private(set) var sessions: [AgentSession] = []
    @Published private(set) var lastFinished: AgentSession?
    @Published private(set) var lastEventAt: Date?

    private var pruneTimer: Timer?
    private let center = ActivityCenter.shared

    init() {
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.prune() }
        }
    }

    var attention: AgentSession? {
        sessions.filter(\.needsAttention).max { $0.updatedAt < $1.updatedAt }
    }

    var running: [AgentSession] {
        sessions.filter { $0.status == .running }
    }

    var ordered: [AgentSession] {
        sessions.sorted { lhs, rhs in
            let rank: (AgentSession) -> Int = {
                switch $0.status {
                case .needsYou: 0
                case .running: 1
                case .done: 2
                case .idle: 3
                }
            }
            return rank(lhs) != rank(rhs) ? rank(lhs) < rank(rhs) : lhs.updatedAt > rhs.updatedAt
        }
    }

    func upsert(id: String, provider: AgentProvider, mutate: (inout AgentSession) -> Void) {
        let now = Date()
        var session = sessions.first { $0.id == id }
            ?? AgentSession(id: id, provider: provider, cwd: "", status: .idle, updatedAt: now)
        let previous = session.status
        mutate(&session)
        session.updatedAt = now
        if session.status == .running, previous != .running, !(previous.isNeedsYou) {
            session.turnStartedAt = session.turnStartedAt ?? now
        }
        if session.status == .done, previous == .running || previous.isNeedsYou {
            if let start = session.turnStartedAt { session.lastTurnDuration = now.timeIntervalSince(start) }
            session.turnStartedAt = nil
            lastFinished = session
            center.post(.agentDone, for: Constants.Agents.doneLingerSeconds)
            ActivityLog.shared.add(
                symbol: "checkmark.circle.fill", tint: Theme.Accent.success,
                title: "\(session.project) finished", detail: session.detail ?? session.provider.title
            )
        }
        if session.status == .idle { session.turnStartedAt = nil }
        // A summary that lands after the turn ended still belongs in the "done" banner.
        if session.status == .done, previous == .done, lastFinished?.id == id {
            lastFinished = session
        }

        withAnimation(Motion.state) {
            if let index = sessions.firstIndex(where: { $0.id == id }) {
                sessions[index] = session
            } else {
                sessions.append(session)
            }
        }
        lastEventAt = now
        syncActivities()
    }

    func remove(id: String) {
        withAnimation(Motion.state) { sessions.removeAll { $0.id == id } }
        syncActivities()
    }

    /// Clears a needs-you banner the user dismissed without answering in the terminal.
    func acknowledge(_ id: String) {
        guard let index = sessions.firstIndex(where: { $0.id == id }), sessions[index].needsAttention else { return }
        withAnimation(Motion.state) { sessions[index].status = .running }
        syncActivities()
    }

    private func syncActivities() {
        let prefs = Preferences.shared
        center.setPersistent(.needsYou, active: prefs.agentsEnabled && attention != nil)
        center.setPersistent(.agentRunning, active: prefs.agentsEnabled && prefs.agentWings && !running.isEmpty)
    }

    private func prune() {
        let cutoff = Date().addingTimeInterval(-Constants.Agents.sessionForgetAfter)
        let stale = sessions.filter { $0.updatedAt < cutoff && $0.status != .running }
        guard !stale.isEmpty else { return }
        withAnimation(Motion.state) { sessions.removeAll { stale.map(\.id).contains($0.id) } }
        syncActivities()
    }
}

extension AgentSession.Status {
    var isNeedsYou: Bool {
        if case .needsYou = self { return true }
        return false
    }
}
