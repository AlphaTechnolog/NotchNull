import XCTest
@testable import NotchNull

final class TimerCustomTests: XCTestCase {
    func testCustomTotalAcceptsClockTriples() {
        XCTAssertEqual(TimerService.total(hours: 0, minutes: 5, seconds: 0), 300)
        XCTAssertEqual(TimerService.total(hours: 1, minutes: 30, seconds: 0), 5_400)
        XCTAssertEqual(TimerService.total(hours: 0, minutes: 0, seconds: 1), 1)
        XCTAssertEqual(TimerService.total(hours: 99, minutes: 59, seconds: 59), 99 * 3_600 + 59 * 60 + 59)
    }

    func testCustomTotalRejectsZeroAndOutOfRange() {
        XCTAssertNil(TimerService.total(hours: 0, minutes: 0, seconds: 0))
        XCTAssertNil(TimerService.total(hours: 0, minutes: 60, seconds: 0))
        XCTAssertNil(TimerService.total(hours: 0, minutes: 0, seconds: 60))
        XCTAssertNil(TimerService.total(hours: 100, minutes: 0, seconds: 0))
        XCTAssertNil(TimerService.total(hours: -1, minutes: 0, seconds: 0))
    }
}
