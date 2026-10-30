import XCTest
@testable import NotchNull

final class AgentAvailabilityCopyTests: XCTestCase {
    func testZeroInstalledCopyPointsToInstallingAnAgent() {
        XCTAssertTrue(AgentAvailabilityCopy.noAgentsInstalledDetail.contains("Claude Code"))
        XCTAssertTrue(AgentAvailabilityCopy.noAgentsInstalledDetail.contains("Codex"))
        XCTAssertTrue(AgentAvailabilityCopy.noAgentsInstalledDetail.contains("opencode"))
        XCTAssertTrue(AgentAvailabilityCopy.sessionsEmptyDetail(installed: []).contains("Install"))
    }

    func testSessionEmptyCopyNamesOnlyInstalledAgents() {
        for count in 1...3 {
            let installed = Set(AgentProvider.allCases.prefix(count))
            let detail = AgentAvailabilityCopy.sessionsEmptyDetail(installed: installed)
            for provider in AgentProvider.allCases {
                if installed.contains(provider) {
                    XCTAssertTrue(detail.contains(provider.title), "Missing \(provider.title) in: \(detail)")
                } else {
                    XCTAssertFalse(detail.contains(provider.title), "Unexpected \(provider.title) in: \(detail)")
                }
            }
        }
    }
}
