import Combine
import Foundation
import SwiftUI

/// Wires the agent services together and owns the latest usage warning shown in the notch.
@MainActor
final class AgentHub: ObservableObject {
    struct Warning: Equatable {
        let provider: String
        let window: UsageWindow
    }

    let sessions = AgentSessionStore()
    let claudeUsage = ClaudeUsageService()
    let claudeTokens = ClaudeTokenStats()
    let codex: CodexMonitor
    private(set) lazy var claudeTranscripts = ClaudeTranscriptMonitor(store: sessions)

    @Published private(set) var warning: Warning?
    @Published private(set) var hooksInstalled = ClaudeHookInstaller.isInstalled
    @Published private(set) var hookError: String?

    private var server: AgentEventServer?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        codex = CodexMonitor(store: sessions)
    }

    func start() {
        let warn: (String, UsageWindow) -> Void = { [weak self] provider, window in
            self?.warning = Warning(provider: provider, window: window)
            ActivityCenter.shared.post(.usageWarning, for: Constants.Durations.usageWarning)
            ActivityLog.shared.add(
                symbol: "gauge.with.dots.needle.67percent", tint: Theme.Accent.warning,
                title: "\(provider) \(window.label): \(Int((100 - window.percent).rounded()))% left", detail: Formatting.usageSummary(window)
            )
        }
        claudeUsage.onWarning = warn
        codex.onWarning = warn

        let handler = ClaudeHookHandler(store: sessions)
        let server = AgentEventServer(token: ClaudeHookInstaller.token()) { request in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard Preferences.shared.agentsEnabled else { return }
                    handler.handle(request)
                }
            }
        }
        server.start(port: Constants.Agents.eventServerPort)
        self.server = server

        claudeUsage.start()
        claudeTokens.start()
        claudeTranscripts.start()
        codex.start()

        // Re-publish nested changes so views observing the hub refresh.
        [sessions.objectWillChange, claudeUsage.objectWillChange, claudeTokens.objectWillChange, codex.objectWillChange]
            .forEach { publisher in
                publisher.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
            }
    }

    /// Fixture entry point for snapshot rendering.
    func preview(warning: Warning?, hooksInstalled: Bool) {
        self.warning = warning
        self.hooksInstalled = hooksInstalled
    }

    func installHooks() {
        do {
            try ClaudeHookInstaller.install()
            hookError = nil
        } catch {
            hookError = error.localizedDescription
        }
        withAnimation(Motion.state) { hooksInstalled = ClaudeHookInstaller.isInstalled }
    }

    func uninstallHooks() {
        do {
            try ClaudeHookInstaller.uninstall()
            hookError = nil
        } catch {
            hookError = error.localizedDescription
        }
        withAnimation(Motion.state) { hooksInstalled = ClaudeHookInstaller.isInstalled }
    }

    func usage(for provider: AgentProvider) -> ProviderUsage {
        provider == .claude ? claudeUsage.usage : codex.usage
    }

    func tokens(for provider: AgentProvider) -> TokenTally {
        provider == .claude ? claudeTokens.tokens : codex.tokens
    }
}
