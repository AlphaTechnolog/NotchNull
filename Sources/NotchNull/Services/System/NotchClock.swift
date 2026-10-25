import Combine
import Foundation

/// One clock for every notch time label: a single whole-second timer shared by all windows.
///
/// Windows activate it while they are actually on screen, so a hidden or sleeping display has no
/// clock consumer and no work. The clock is frozen for snapshots and tests, where time must not
/// advance between renders.
@MainActor
final class NotchClock: ObservableObject {
    @Published private(set) var now: Date

    private var timer: Timer?
    private var consumers: Set<UUID> = []
    private var frozenAt: Date?

    init(now: Date = Date()) {
        self.now = now
    }

    /// The number of windows currently relying on ticks. Zero means the timer is stopped.
    var activeConsumers: Int { consumers.count }
    var isRunning: Bool { timer != nil }
    var isFrozen: Bool { frozenAt != nil }

    /// A window starts or stops depending on the clock. The timer runs while at least one
    /// consumer is active; the first tick lands on the next whole second.
    func setActive(_ active: Bool, consumer: UUID) {
        if active {
            consumers.insert(consumer)
        } else {
            consumers.remove(consumer)
        }
        if consumers.isEmpty {
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
