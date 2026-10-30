import XCTest
@testable import NotchNull

final class AgentProviderVisibilityTests: XCTestCase {
    private let allEnabled: [AgentProvider: Bool] = Dictionary(
        uniqueKeysWithValues: AgentProvider.allCases.map { ($0, true) }
    )

    func testVisibilityPreservesProviderOrderForZeroThroughThreeInstalled() {
        XCTAssertEqual(AgentProvider.visible(installed: [], enabled: allEnabled), [])
        XCTAssertEqual(AgentProvider.visible(installed: [.opencode], enabled: allEnabled), [.opencode])
        XCTAssertEqual(AgentProvider.visible(installed: [.opencode, .claude], enabled: allEnabled), [.claude, .opencode])
        XCTAssertEqual(AgentProvider.visible(installed: Set(AgentProvider.allCases), enabled: allEnabled), AgentProvider.allCases)
    }

    func testDisabledPreferenceHidesAnInstalledProvider() {
        var enabled = allEnabled
        enabled[.codex] = false
        XCTAssertEqual(AgentProvider.visible(installed: Set(AgentProvider.allCases), enabled: enabled), [.claude, .opencode])
    }
}
