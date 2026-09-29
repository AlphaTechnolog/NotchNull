import XCTest
@testable import NotchNull

final class FormattingTests: XCTestCase {
    func testResetTimeUsesCountdownWhenCloseAndWeekdayWhenFar() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(Formatting.resetTime(now.addingTimeInterval(45 * 60), now: now), "in 45m")
        XCTAssertEqual(Formatting.resetTime(now.addingTimeInterval(4 * 3600 + 53 * 60), now: now), "in 4h 53m")
        XCTAssertFalse(Formatting.resetTime(now.addingTimeInterval(3 * 86_400), now: now).hasPrefix("in "))
    }

    func testMomentAddsTheDayWhenItIsNotToday() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 20))!
        let tomorrow = calendar.date(byAdding: .hour, value: 14, to: now)!
        XCTAssertTrue(Formatting.moment(tomorrow, now: now).hasPrefix("tomorrow"))
        let sameDay = calendar.date(byAdding: .minute, value: 30, to: now)!
        XCTAssertFalse(Formatting.moment(sameDay, now: now).contains("tomorrow"))
    }

    func testTokenCountsAreAbbreviated() {
        XCTAssertEqual(Formatting.tokens(950), "950")
        XCTAssertEqual(Formatting.tokens(18_420_000), "18.4M")
        XCTAssertEqual(Formatting.tokens(1_536_476_784), "1.54B")
    }

    func testTransferRatesStayShort() {
        XCTAssertEqual(Formatting.rate(0), "—")
        XCTAssertEqual(Formatting.rate(509), "0.5 KB/s")
        XCTAssertEqual(Formatting.rate(17_400), "17 KB/s")
        XCTAssertEqual(Formatting.rate(1_240_000), "1.2 MB/s")
        XCTAssertEqual(Formatting.rate(24_000_000), "24 MB/s")
    }
}
