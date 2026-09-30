import Foundation

enum AgentProvider: String, CaseIterable, Identifiable {
    case claude, codex, opencode
    var id: String { rawValue }
    var title: String {
        switch self {
        case .claude: "Claude Code"
        case .codex: "Codex"
        case .opencode: "opencode"
        }
    }
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

    /// Fraction of the window already elapsed, when the window length is known.
    func elapsedFraction(at now: Date = Date()) -> Double? {
        guard let resetsAt, let duration, duration > 0 else { return nil }
        let remaining = resetsAt.timeIntervalSince(now)
        return max(0, min(1, 1 - remaining / duration))
    }

    /// If usage continues at the average rate so far, when the window hits 100%.
    /// `nil` when the limit would not be reached before reset or there is too little signal.
    func projectedExhaustion(at now: Date = Date()) -> Date? {
        guard let duration, let resetsAt, let elapsed = elapsedFraction(at: now), elapsed > 0.05, percent > 1 else { return nil }
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
