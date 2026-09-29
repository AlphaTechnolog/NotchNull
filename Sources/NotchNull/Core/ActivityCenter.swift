import Combine
import Foundation

/// Everything that can slide out of the closed notch, highest priority first.
enum ActivityKind: Int, CaseIterable, Comparable {
    case hello
    case needsYou
    case volume
    case brightness
    case timerFinished
    case usageWarning
    /// Shown by your scripts, agents and widgets through the CLI or local API.
    case custom
    case agentDone
    case downloadKeep
    case downloadDone
    case downloadTrashed
    case charging
    case lowBattery
    case accessory
    case screenshot
    case trayAdded
    case meetingSoon
    case download
    case downloadExpiring
    case timer
    case agentRunning
    case music

    static func < (lhs: ActivityKind, rhs: ActivityKind) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Persistent activities stay up while their source is live; the rest expire on their own.
    var isPersistent: Bool {
        switch self {
        case .needsYou, .custom, .download, .downloadExpiring, .timer, .agentRunning, .music, .meetingSoon: true
        default: false
        }
    }
}

/// Arbitrates which activity owns the closed notch. Services post transient events or toggle
/// persistent ones; the notch renders `current`.
@MainActor
final class ActivityCenter: ObservableObject {
    static let shared = ActivityCenter()

    @Published private(set) var current: ActivityKind?
    /// Bumped on every post so an activity re-posted while visible can replay its entrance.
    @Published private(set) var pulse: Int = 0

    private var persistent: Set<ActivityKind> = []
    private var transient: [ActivityKind: Date] = [:]
    private var expiryTimer: Timer?

    func post(_ kind: ActivityKind, for duration: TimeInterval) {
        transient[kind] = Date().addingTimeInterval(duration)
        pulse &+= 1
        recompute()
    }

    func dismiss(_ kind: ActivityKind) {
        transient[kind] = nil
        persistent.remove(kind)
        recompute()
    }

    func setPersistent(_ kind: ActivityKind, active: Bool) {
        let changed = active ? persistent.insert(kind).inserted : persistent.remove(kind) != nil
        if changed { recompute() }
    }

    /// Re-evaluates after the user enables or disables activity kinds.
    func refresh() { recompute() }

    func isActive(_ kind: ActivityKind) -> Bool {
        persistent.contains(kind) || (transient[kind].map { $0 > Date() } ?? false)
    }

    private func recompute() {
        let now = Date()
        transient = transient.filter { $0.value > now }
        let disabled = UserDefaults.standard.stringArray(forKey: Preferences.Keys.disabledActivities) ?? []
        let candidates = persistent.union(transient.keys).filter { !disabled.contains($0.name) }
        let next = candidates.min()
        if next != current { current = next }
        scheduleExpiry()
    }

    private func scheduleExpiry() {
        expiryTimer?.invalidate()
        guard let soonest = transient.values.min() else { return }
        let interval = max(0.05, soonest.timeIntervalSinceNow + 0.01)
        expiryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.recompute() }
        }
    }
}
