import Foundation

enum AgentProvider: String, CaseIterable, Identifiable {
    case claude, codex, opencode
    var id: String { rawValue }

    static func visible(installed: Set<AgentProvider>, enabled: [AgentProvider: Bool]) -> [AgentProvider] {
        allCases.filter { installed.contains($0) && enabled[$0] == true }
    }

    var title: String {
        switch self {
        case .claude: "Claude Code"
        case .codex: "Codex"
        case .opencode: "opencode"
        }
    }
}

enum AgentAvailabilityCopy {
    static let noAgentsInstalledTitle = "No coding agents found"
    static let noAgentsInstalledDetail = "Install Claude Code, Codex or opencode to see usage here."

    static func sessionsEmptyDetail(installed: Set<AgentProvider>) -> String {
        guard !installed.isEmpty else { return "Install a supported coding agent to see live sessions here." }
        let names = AgentProvider.allCases.filter(installed.contains).map(\.title)
        let joined = ListFormatter.localizedString(byJoining: names)
        return "\(joined) sessions appear here while they are working."
    }
}

struct AgentSettingsAvailability: Equatable {
    let installed: Set<AgentProvider>

    var showsClaude: Bool { installed.contains(.claude) }
    var showsCodex: Bool { installed.contains(.codex) }
    var showsOpenCode: Bool { installed.contains(.opencode) }
    var showsAgentSessionSettings: Bool { !installed.isEmpty }
    var showsNoAgentsNotice: Bool { installed.isEmpty }
    var showsOpenCodeAccountConsent: Bool { showsOpenCode }
}

struct OrphanedAgentIntegrations: Equatable {
    let claudeHooks: Bool
    let opencodePlugin: Bool

    init(installed: Set<AgentProvider>, hooksInstalled: Bool, opencodePluginInstalled: Bool) {
        claudeHooks = !installed.contains(.claude) && hooksInstalled
        opencodePlugin = !installed.contains(.opencode) && opencodePluginInstalled
    }

    var isEmpty: Bool { !claudeHooks && !opencodePlugin }
}

/// One rate-limit window (5-hour session, weekly, model-scoped weekly…).
struct UsageWindow: Identifiable, Equatable {
    enum Severity: String { case normal, warning, critical }

    let id: String
    let label: String
    let percent: Double
    let resetsAt: Date?
    let duration: TimeInterval?
    let severity: Severity

    init(id: String, label: String, percent: Double, resetsAt: Date?, duration: TimeInterval?, severity: Severity? = nil) {
        self.id = id
        self.label = label
        self.percent = max(0, min(100, percent))
        self.resetsAt = resetsAt
        self.duration = duration
        self.severity = severity ?? (percent >= 90 ? .critical : percent >= 75 ? .warning : .normal)
    }

    /// Identity of one warning: the same window, in the same reset cycle, at the same severity.
    /// Servers report the reset with sub-second jitter (16:59:59.79 one poll, 17:00:00.07 the
    /// next), so the cycle is the nearest hour; real resets are at least a window length apart.
    func warningKey(provider: String) -> String {
        let cycle = ((resetsAt?.timeIntervalSince1970 ?? 0) / 3600).rounded()
        return "\(provider)-\(id)-\(Int(cycle))-\(severity.rawValue)"
    }

    /// Fraction of the window already elapsed, when the window length is known.
    func elapsedFraction(at now: Date = Date()) -> Double? {
        guard let resetsAt, let duration, duration > 0 else { return nil }
        let remaining = resetsAt.timeIntervalSince(now)
        return max(0, min(1, 1 - remaining / duration))
    }

    /// If usage continues at the average rate so far, when the window hits 100%.
    /// `nil` when already exhausted, the limit would not be reached before reset, or there is
    /// too little signal. An exhausted window must show its reset, not a prediction of "now".
    func projectedExhaustion(at now: Date = Date()) -> Date? {
        guard let duration, let resetsAt, resetsAt > now, let elapsed = elapsedFraction(at: now), elapsed > 0.05, percent > 1, percent < 100 else { return nil }
        let elapsedSeconds = elapsed * duration
        let rate = percent / elapsedSeconds
        let hit = now.addingTimeInterval((100 - percent) / rate)
        return hit < resetsAt ? hit : nil
    }

    /// Rates in percent per `unit` seconds (a day for weekly windows, an hour for shorter ones):
    /// how fast the window is being used so far, and the most that can be used from now on and
    /// still last until the reset.
    func rates(at now: Date = Date()) -> (unit: TimeInterval, used: Double, budget: Double)? {
        guard let duration, let resetsAt, let elapsed = elapsedFraction(at: now), elapsed > 0.02 else { return nil }
        let unit: TimeInterval = duration >= 86_400 ? 86_400 : 3_600
        let elapsedUnits = elapsed * duration / unit
        let remainingUnits = max(resetsAt.timeIntervalSince(now), 60) / unit
        return (unit, percent / elapsedUnits, (100 - percent) / remainingUnits)
    }

    /// Usage relative to an even pace through the window (1.0 = exactly on pace).
    func paceRatio(at now: Date = Date()) -> Double? {
        guard let elapsed = elapsedFraction(at: now), elapsed > 0.02 else { return nil }
        return (percent / 100) / elapsed
    }
}

struct UsageShare: Identifiable, Equatable {
    let id: String
    let label: String
    let percent: Double
}

struct ProviderUsage: Equatable {
    enum State: Equatable {
        case loading
        case ready
        case signedOut(String)
        case unavailable(String)
    }

    var provider: AgentProvider
    var plan: String?
    var windows: [UsageWindow] = []
    var breakdown: [UsageShare] = []
    var updatedAt: Date?
    var state: State = .loading

    static func placeholder(_ provider: AgentProvider) -> ProviderUsage { ProviderUsage(provider: provider) }

    /// The window a user most likely cares about right now: the most used one.
    var primary: UsageWindow? { windows.max { $0.percent < $1.percent } }
}

/// Token totals derived from local agent logs.
struct TokenTally: Equatable {
    var today: Int = 0
    var output: Int = 0
    /// 24 hourly buckets for today, index = hour of day.
    var hourly: [Int] = Array(repeating: 0, count: 24)
    var messages: Int = 0
}
