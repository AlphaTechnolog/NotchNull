import XCTest
@testable import NotchNull

final class AgentSettingsAvailabilityTests: XCTestCase {
    func testNoInstalledAgentsShowsOnlyTheAvailabilityNoticeAmongAgentGroups() {
        let visibility = AgentSettingsAvailability(installed: [])
        XCTAssertTrue(visibility.showsNoAgentsNotice)
        XCTAssertFalse(visibility.showsClaude)
        XCTAssertFalse(visibility.showsCodex)
        XCTAssertFalse(visibility.showsOpenCode)
        XCTAssertFalse(visibility.showsAgentSessionSettings)
        XCTAssertFalse(visibility.showsOpenCodeAccountConsent)
    }

    func testEachInstalledAgentEnablesOnlyItsOwnSettingsGroup() {
        for provider in AgentProvider.allCases {
            let visibility = AgentSettingsAvailability(installed: [provider])
            XCTAssertEqual(visibility.showsClaude, provider == .claude)
            XCTAssertEqual(visibility.showsCodex, provider == .codex)
            XCTAssertEqual(visibility.showsOpenCode, provider == .opencode)
            XCTAssertTrue(visibility.showsAgentSessionSettings)
            XCTAssertEqual(visibility.showsOpenCodeAccountConsent, provider == .opencode)
            XCTAssertFalse(visibility.showsNoAgentsNotice)
        }
    }
}
