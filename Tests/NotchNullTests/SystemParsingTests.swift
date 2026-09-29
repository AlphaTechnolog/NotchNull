import XCTest
@testable import NotchNull

final class SystemParsingTests: XCTestCase {
    func testPowerModeReadsHighPowerFromPmsetOutput() {
        let output = """
        System-wide power settings:
        Currently in use:
         standby              1
         powermode            2
         sleep                1 (sleep prevented by caffeinate)
        """
        XCTAssertEqual(PowerModeReader.parse(output), .high)
    }

    func testPowerModeReadsLowAndAutomatic() {
        XCTAssertEqual(PowerModeReader.parse(" powermode 1\n"), .low)
        XCTAssertEqual(PowerModeReader.parse(" powermode 0\n"), .automatic)
    }

    func testPowerModeFallsBackToLegacyLowPowerKey() {
        XCTAssertEqual(PowerModeReader.parse(" lowpowermode 1\n sleep 1\n"), .low)
        XCTAssertNil(PowerModeReader.parse(" sleep 1\n"))
    }

    func testBatteryTintFollowsEnergyModeBeforeCharging() {
        var state = BatteryState(percent: 80, isPluggedIn: true, hasBattery: true)
        XCTAssertEqual(state.tint, Theme.Accent.battery)
        state.powerMode = .low
        XCTAssertEqual(state.tint, Theme.Accent.lowPower)
        state.powerMode = .high
        XCTAssertEqual(state.tint, Theme.Accent.highPower)
    }

    func testSummaryJoinsLinesAndDropsMarkdown() {
        let text = "## Done\n\n**Added** the `pricing` section.\nTests pass."
        XCTAssertEqual(ClaudeHookHandler.summary(text, limit: 160), "Done. Added the pricing section. Tests pass.")
    }

    func testSummarySkipsTagWrappedMessages() {
        XCTAssertNil(ClaudeHookHandler.summary("<task-notification>\n<task-id>abc</task-id>\n</task-notification>", limit: 80))
    }

    func testSummaryStopsAtLimitOnWholeLines() {
        let text = "First sentence here.\nSecond sentence that is rather long and would overflow."
        XCTAssertEqual(ClaudeHookHandler.summary(text, limit: 30), "First sentence here.")
    }
}
