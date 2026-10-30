import XCTest
@testable import NotchNull

final class OrphanedAgentIntegrationsTests: XCTestCase {
    func testClaudeHooksAreCleanupOnlyWhenClaudeIsAbsent() {
        let orphaned = OrphanedAgentIntegrations(installed: [], hooksInstalled: true, opencodePluginInstalled: false)
        XCTAssertTrue(orphaned.claudeHooks)
        XCTAssertFalse(orphaned.opencodePlugin)
        XCTAssertTrue(OrphanedAgentIntegrations(installed: [.claude], hooksInstalled: true, opencodePluginInstalled: false).isEmpty)
        XCTAssertTrue(OrphanedAgentIntegrations(installed: [], hooksInstalled: false, opencodePluginInstalled: false).isEmpty)
    }

    func testOpenCodePluginIsCleanupOnlyWhenOpenCodeIsAbsent() {
        let orphaned = OrphanedAgentIntegrations(installed: [], hooksInstalled: false, opencodePluginInstalled: true)
        XCTAssertFalse(orphaned.claudeHooks)
        XCTAssertTrue(orphaned.opencodePlugin)
        XCTAssertTrue(OrphanedAgentIntegrations(installed: [.opencode], hooksInstalled: false, opencodePluginInstalled: true).isEmpty)
        XCTAssertTrue(OrphanedAgentIntegrations(installed: [], hooksInstalled: false, opencodePluginInstalled: false).isEmpty)
    }
}
