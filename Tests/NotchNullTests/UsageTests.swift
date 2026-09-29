import XCTest
@testable import NotchNull

final class UsageTests: XCTestCase {
    func testParsesClaudeLimitsArrayIntoWindowsAndSkipsEmptyScopedLimits() throws {
        let json = """
        {"limits":[
          {"kind":"session","group":"session","percent":14,"severity":"normal","resets_at":"2026-09-29T00:49:59.790654+00:00","scope":null},
          {"kind":"weekly_all","group":"weekly","percent":37,"severity":"normal","resets_at":"2026-10-03T16:59:59.790676+00:00","scope":null},
          {"kind":"weekly_scoped","group":"weekly","percent":0,"severity":"normal","resets_at":"2026-10-03T17:00:00+00:00","scope":{"model":{"display_name":"Fable"}}}
        ],
        "seven_day_breakdown":{"rows":[{"key":"claude_code","display_name":"Claude Code","percent":100}]}}
        """
        let parsed = try ClaudeUsageService.parse(Data(json.utf8))
        XCTAssertEqual(parsed.windows.map(\.label), ["5 hours", "Week"])
        XCTAssertEqual(parsed.windows.first?.percent, 14)
        XCTAssertEqual(parsed.windows.first?.duration, 5 * 3600)
        XCTAssertNotNil(parsed.windows.first?.resetsAt)
        XCTAssertEqual(parsed.breakdown.first?.label, "Claude Code")
    }

    func testFallsBackToLegacyUtilizationFieldsWhenLimitsAreMissing() throws {
        let json = """
        {"five_hour":{"utilization":11.0,"resets_at":"2026-09-29T00:50:00.071709+00:00"},
         "seven_day":{"utilization":36.0,"resets_at":"2026-10-03T17:00:00.071730+00:00"},
         "seven_day_opus":null}
        """
        let parsed = try ClaudeUsageService.parse(Data(json.utf8))
        XCTAssertEqual(parsed.windows.map(\.percent), [11, 36])
    }

    func testProjectsExhaustionOnlyWhenPaceBeatsTheReset() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        // Half the 5h window elapsed with 80% used: runs out before reset.
        let hot = UsageWindow(id: "s", label: "5 hours", percent: 80, resetsAt: now.addingTimeInterval(2.5 * 3600), duration: 5 * 3600)
        let hit = try? XCTUnwrap(hot.projectedExhaustion(at: now))
        XCTAssertNotNil(hit)
        if let hit { XCTAssertLessThan(hit, now.addingTimeInterval(2.5 * 3600)) }
        // Same elapsed time with 30% used: never reaches 100% before reset.
        let calm = UsageWindow(id: "s", label: "5 hours", percent: 30, resetsAt: now.addingTimeInterval(2.5 * 3600), duration: 5 * 3600)
        XCTAssertNil(calm.projectedExhaustion(at: now))
        XCTAssertEqual(calm.paceRatio(at: now) ?? 0, 0.6, accuracy: 0.001)
    }

    /// The user's real week: 41% used with 4 d 15 h left. Used pace ≈ 17.3%/day, budget ≈ 12.8%/day,
    /// so at the current pace it runs out about 3.4 days from now (Friday morning), as claude.ai says.
    func testWeeklyPaceMatchesClaudeUsagePageForARealWeek() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let reset = now.addingTimeInterval(4 * 86_400 + 15 * 3_600)
        let week = UsageWindow(id: "w", label: "Week", percent: 41, resetsAt: reset, duration: 7 * 86_400)
        let rates = try XCTUnwrap(week.rates(at: now))
        XCTAssertEqual(rates.unit, 86_400)
        XCTAssertEqual(rates.used, 17.3, accuracy: 0.1)
        XCTAssertEqual(rates.budget, 12.76, accuracy: 0.1)
        let hit = try XCTUnwrap(week.projectedExhaustion(at: now))
        XCTAssertEqual(hit.timeIntervalSince(now) / 86_400, 3.41, accuracy: 0.05)
        XCTAssertLessThan(hit, reset)
    }

    func testSeverityDerivesFromPercentWhenNotProvided() {
        XCTAssertEqual(UsageWindow(id: "a", label: "", percent: 50, resetsAt: nil, duration: nil).severity, .normal)
        XCTAssertEqual(UsageWindow(id: "a", label: "", percent: 80, resetsAt: nil, duration: nil).severity, .warning)
        XCTAssertEqual(UsageWindow(id: "a", label: "", percent: 95, resetsAt: nil, duration: nil).severity, .critical)
    }
}
