import Combine
import XCTest
@testable import NotchNull

@MainActor
final class NotchClockTests: XCTestCase {
    func testBoundaryIsTheNextWholeSecond() {
        let partial = Date(timeIntervalSinceReferenceDate: 1_000.25)
        XCTAssertEqual(NotchClock.nextBoundary(after: partial).timeIntervalSinceReferenceDate, 1_001, accuracy: 0.0001)
        let exact = Date(timeIntervalSinceReferenceDate: 1_000)
        XCTAssertEqual(NotchClock.nextBoundary(after: exact).timeIntervalSinceReferenceDate, 1_001, accuracy: 0.0001)
    }

    func testOnePublicationPerTick() {
        let clock = NotchClock()
        var publications = 0
        let subscription = clock.$now.dropFirst().sink { _ in publications += 1 }
        clock.tick()
        XCTAssertEqual(publications, 1)
        withExtendedLifetime(subscription) {}
    }

    func testTimerStopsAtZeroConsumersAndKeepsRunningWhileAnyRemain() {
        let clock = NotchClock()
        let first = UUID()
        let second = UUID()
        clock.setShowing(true, label: UUID())
        clock.setActive(true, consumer: first)
        XCTAssertTrue(clock.isRunning)
        XCTAssertEqual(clock.activeConsumers, 1)
        clock.setActive(true, consumer: second)
        XCTAssertEqual(clock.activeConsumers, 2)
        clock.setActive(false, consumer: first)
        XCTAssertTrue(clock.isRunning)
        XCTAssertEqual(clock.activeConsumers, 1)
        clock.setActive(false, consumer: second)
        XCTAssertFalse(clock.isRunning)
        XCTAssertEqual(clock.activeConsumers, 0)
    }

    func testAVisibleWindowWithNoTimeLabelDoesNotTick() {
        let clock = NotchClock()
        let window = UUID()
        let label = UUID()
        clock.setActive(true, consumer: window)
        XCTAssertFalse(clock.isRunning, "no time label is showing")
        clock.setShowing(true, label: label)
        XCTAssertTrue(clock.isRunning)
        clock.setShowing(false, label: label)
        XCTAssertFalse(clock.isRunning)
        XCTAssertEqual(clock.showingLabels, 0)
        clock.setShowing(true, label: label)
        clock.setActive(false, consumer: window)
        XCTAssertFalse(clock.isRunning, "a label in a hidden window does not tick")
    }

    func testAClockStoppedForAWhileShowsTheCurrentTimeWhenALabelReturns() {
        let stale = Date().addingTimeInterval(-3_600)
        let clock = NotchClock(now: stale)
        clock.setActive(true, consumer: UUID())
        clock.setShowing(true, label: UUID())
        XCTAssertGreaterThan(clock.now.timeIntervalSince(stale), 3_000)
    }

    func testActivationTicksAtTheNextBoundary() async throws {
        let clock = NotchClock()
        let consumer = UUID()
        let before = Date()
        var ticked: Date?
        // Only the first tick: a later one landing before the sleep ends must not replace it.
        let subscription = clock.$now.dropFirst().first().sink { ticked = $0 }
        clock.setShowing(true, label: UUID())
        clock.setActive(true, consumer: consumer)
        try await Task.sleep(for: .milliseconds(1_500))
        let tick = try XCTUnwrap(ticked)
        XCTAssertLessThan(tick.timeIntervalSince(before), 1.5)
        let fraction = tick.timeIntervalSinceReferenceDate - tick.timeIntervalSinceReferenceDate.rounded(.down)
        XCTAssertTrue(fraction < 0.35 || fraction > 0.65, "tick \(tick) should land near a whole second")
        clock.setActive(false, consumer: consumer)
        withExtendedLifetime(subscription) {}
    }

    func testFrozenClockDoesNotRunOrAdvance() {
        let clock = NotchClock()
        let frozen = Date(timeIntervalSinceReferenceDate: 5_000)
        clock.freeze(at: frozen)
        XCTAssertTrue(clock.isFrozen)
        XCTAssertEqual(clock.now, frozen)
        clock.setShowing(true, label: UUID())
        clock.setActive(true, consumer: UUID())
        XCTAssertFalse(clock.isRunning, "a frozen clock must not schedule work")
        clock.tick()
        XCTAssertEqual(clock.now, frozen)
        clock.unfreeze()
        clock.tick()
        XCTAssertNotEqual(clock.now, frozen)
    }
}
