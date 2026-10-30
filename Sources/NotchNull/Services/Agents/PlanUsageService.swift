import Combine
import Foundation
import SwiftUI

/// Limits of every other coding subscription found on this Mac (see `PlanProviders`). Providers
/// without a key are never contacted; a key on an account without that plan hides the provider.
@MainActor
final class PlanUsageService: ObservableObject {
    /// Subscriptions with a key, in registry order; those without a plan are left out.
    @Published private(set) var usages: [PlanUsage] = []
    /// Why the active OpenCode Console account could (not) be used, for Settings. Nil when the
    /// export path is off (legacy behavior) or before the first refresh.
    @Published private(set) var openCodeAccount: OpenCodeAuthExport.Selection?

    private var timer: Timer?
    private var inFlight = false
    /// A refresh asked for while one ran, e.g. a consent change; it runs as soon as that one ends.
    private var refreshQueued = false
    /// True from a refresh's start until it and any refresh queued behind it have finished.
    var isRefreshing: Bool { inFlight }
    private let loadSources: @Sendable (_ accountUsageAllowed: Bool) -> PlanCredentialSources
    private let accountUsageAllowed: @MainActor () -> Bool
    private let planUsageEnabled: @MainActor () -> Bool
    private var warnedWindows: Set<String> = []
    private var cancellables: Set<AnyCancellable> = []
    var onWarning: ((String, UsageWindow) -> Void)?

    /// The defaults read this Mac; tests inject the sources and both switches to drive a refresh.
    init(
        loadSources: @escaping @Sendable (_ accountUsageAllowed: Bool) -> PlanCredentialSources = { PlanCredentialSources.load(accountUsageAllowed: $0) },
        accountUsageAllowed: @escaping @MainActor () -> Bool = { Preferences.shared.opencodeAccountUsageAllowed },
        planUsageEnabled: @escaping @MainActor () -> Bool = { Preferences.shared.planUsageEnabled }
    ) {
        self.loadSources = loadSources
        self.accountUsageAllowed = accountUsageAllowed
        self.planUsageEnabled = planUsageEnabled
    }

    func start() {
        Preferences.shared.$planUsageEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in enabled ? self?.resume() : self?.pause() }
            .store(in: &cancellables)
        // A consent change resolves the account now instead of at the next tick.
        Preferences.shared.$opencodeAccountUsageAllowed
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] allowed in
                guard Preferences.shared.planUsageEnabled else { return }
                self?.accountConsentChanged(allowed: allowed)
            }
            .store(in: &cancellables)
    }

    /// Revoking drops the account token at once; the refresh then re-reads the keys without it.
    func accountConsentChanged(allowed: Bool) {
        if !allowed, openCodeAccount != nil { openCodeAccount = nil }
        refresh()
    }

    /// OpenCode Go's limits, which the opencode agent block shows when opencode is watched.
    var openCodeGo: PlanUsage? { usages.first { $0.id == OpenCodeGoPlan.planID } }

    /// Fixture entry point for snapshot rendering.
    func preview(_ usages: [PlanUsage], openCodeAccount: OpenCodeAuthExport.Selection? = nil) {
        self.usages = usages
        self.openCodeAccount = openCodeAccount
    }

    private func resume() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Constants.Agents.planUsageInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    private func pause() {
        timer?.invalidate()
        timer = nil
        refreshQueued = false
        withAnimation(Motion.state) {
            usages = []
            openCodeAccount = nil
        }
    }

    func refresh() {
        // Plan usage turned off: nothing is read, including a refresh queued before the pause.
        guard planUsageEnabled() else { return }
        guard !inFlight else {
            refreshQueued = true
            return
        }
        inFlight = true
        // Reading the active account is a separate consent on top of plan usage; without it the
        // export is never run and only the legacy environment/auth.json keys are used.
        let accountUsageAllowed = accountUsageAllowed()
        let loadSources = loadSources
        Task {
            defer {
                inFlight = false
                if refreshQueued {
                    refreshQueued = false
                    refresh()
                }
            }
            let (found, account) = await Task.detached(priority: .utility) { () -> ([(any PlanProvider, PlanCredential)], OpenCodeAuthExport.Selection?) in
                let sources = loadSources(accountUsageAllowed)
                let credentials = PlanProviders.all.compactMap { provider in provider.credential(in: sources).map { (provider, $0) } }
                return (credentials, sources.openCodeAccount)
            }.value
            guard isCurrent(accountUsageAllowed) else { return }
            if openCodeAccount != account { openCodeAccount = account }
            let results = await withTaskGroup(of: (Int, Result<PlanSnapshot, PlanError>).self) { group in
                for (index, (provider, credential)) in found.enumerated() {
                    group.addTask {
                        do { return (index, .success(try await provider.fetch(credential))) }
                        catch let error as PlanError { return (index, .failure(error)) }
                        catch { return (index, .failure(.unavailable(error.localizedDescription))) }
                    }
                }
                var collected: [Int: Result<PlanSnapshot, PlanError>] = [:]
                for await (index, result) in group { collected[index] = result }
                return collected
            }
            guard isCurrent(accountUsageAllowed) else { return }
            apply(found.enumerated().compactMap { index, pair in results[index].map { (pair.0, pair.1, $0) } })
        }
    }

    /// Whether a read may still be published: plan usage is on and the account consent it was made
    /// under has not changed. A changed consent queues a refresh that reads again under the new one.
    private func isCurrent(_ accountUsageAllowed: Bool) -> Bool {
        guard planUsageEnabled() else { return false }
        guard accountUsageAllowed == self.accountUsageAllowed() else {
            refreshQueued = true
            return false
        }
        return true
    }

    func apply(_ results: [(provider: any PlanProvider, credential: PlanCredential, result: Result<PlanSnapshot, PlanError>)]) {
        let now = Date()
        var next: [PlanUsage] = []
        for (provider, credential, result) in results {
            let previous = usages.first { $0.id == provider.id }
            var usage = PlanUsage(id: provider.id, title: provider.title, monogram: provider.monogram, tint: provider.tint, source: credential.source)
            switch result {
            case .success(let snapshot):
                usage.plan = snapshot.plan
                usage.windows = snapshot.windows
                usage.updatedAt = now
                usage.state = .ready
                warn(provider.title, snapshot.windows)
            case .failure(.noSubscription):
                continue
            case .failure(.signedOut(let message)):
                if provider.id == OpenCodeGoPlan.planID, previous?.updatedAt == nil { continue }
                usage.state = .signedOut(message)
            case .failure(.unavailable(let message)):
                // Finding a generic OpenCode key is not evidence of a paid Go subscription.
                if provider.id == OpenCodeGoPlan.planID, previous?.updatedAt == nil { continue }
                // Keep the last good numbers through a failed refresh.
                usage.plan = previous?.plan
                usage.windows = previous?.windows ?? []
                usage.updatedAt = previous?.updatedAt
                usage.state = .unavailable(message)
                Log.agents.notice("\(provider.title, privacy: .public) usage unavailable: \(message, privacy: .public)")
            }
            next.append(usage)
        }
        if next != usages { withAnimation(Motion.state) { usages = next } }
    }

    private func warn(_ provider: String, _ windows: [UsageWindow]) {
        for window in windows where window.severity != .normal {
            guard warnedWindows.insert(window.warningKey(provider: provider)).inserted else { continue }
            onWarning?(provider, window)
        }
    }
}
