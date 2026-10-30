import Combine
import Foundation

/// One clock for every notch time label: a single whole-second timer shared by all windows.
///
/// It ticks only while a window is actually on screen and at least one time label is showing, so
/// a hidden or sleeping display, or a notch with no time label, does no work. The clock is frozen for snapshots and tests, where time must not
/// advance between renders.
@MainActor
final class NotchClock: ObservableObject {
    @Published private(set) var now: Date

    private var timer: Timer?
    private var consumers: Set<UUID> = []
    private var labels: Set<UUID> = []
    private var frozenAt: Date?

    init(now: Date = Date()) {
        self.now = now
    }

    /// The number of windows currently relying on ticks. Zero means the timer is stopped.
    var activeConsumers: Int { consumers.count }
    /// The number of time labels currently on screen.
    var showingLabels: Int { labels.count }
    var isRunning: Bool { timer != nil }
    var isFrozen: Bool { frozenAt != nil }

    /// A window on screen starts depending on the clock, a hidden one stops. The timer runs while
    /// a window is active and a time label is showing; the first tick lands on the next whole second.
    func setActive(_ active: Bool, consumer: UUID) {
        if active {
            consumers.insert(consumer)
        } else {
            consumers.remove(consumer)
        }
        update()
    }

    /// A time label appeared or disappeared; with none showing, the timer stops.
    func setShowing(_ showing: Bool, label: UUID) {
        if showing {
            labels.insert(label)
        } else {
            labels.remove(label)
        }
        update()
    }

    private func update() {
        if consumers.isEmpty || labels.isEmpty {
            stop()
        } else {
            start()
        }
    }

    /// Stops ticking and pins `now` for snapshots and deterministic tests. Consumers may still
    /// register, but no timer is scheduled while frozen.
    func freeze(at date: Date) {
        stop()
        frozenAt = date
        now = date
    }

    func unfreeze() {
        frozenAt = nil
    }

    /// The first whole second strictly after `date`; exposed so the boundary rule is testable.
    nonisolated static func nextBoundary(after date: Date) -> Date {
        let reference = date.timeIntervalSinceReferenceDate
        let next = reference.rounded(.up)
        // An exact boundary is "now", not the next second; nudge past it.
        return Date(timeIntervalSinceReferenceDate: next == reference ? next + 1 : next)
    }

    private func start() {
        guard timer == nil, frozenAt == nil, !Motion.isSnapshot else { return }
        // A label shown after a pause must not read the time the clock stopped at.
        let current = Date()
        if current.timeIntervalSince(now) >= 1 { now = current }
        let timer = Timer(fire: Self.nextBoundary(after: Date()), interval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// One clock tick. Internal so tests can drive it without waiting for the run loop.
    func tick() {
        guard frozenAt == nil else { return }
        now = Date()
    }
}
