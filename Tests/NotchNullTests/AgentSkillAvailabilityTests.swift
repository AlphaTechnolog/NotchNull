import XCTest
@testable import NotchNull

final class AgentSkillAvailabilityTests: XCTestCase {
    func testAgentSkillProvidersMapToTheirAgentProviders() {
        XCTAssertEqual(NotchHome.Agent.claude.provider, .claude)
        XCTAssertEqual(NotchHome.Agent.codex.provider, .codex)
    }

    func testRowsShowInstalledAgentsAndLinkedButAbsentAgents() {
        XCTAssertEqual(NotchHome.Agent.visible(installed: [], linked: []), [])
        XCTAssertEqual(NotchHome.Agent.visible(installed: [.claude], linked: []), [.claude])
        XCTAssertEqual(NotchHome.Agent.visible(installed: [], linked: [.codex]), [.codex])
        XCTAssertEqual(NotchHome.Agent.visible(installed: [.claude], linked: [.codex]), [.claude, .codex])
    }
}
