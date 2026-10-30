import XCTest
@testable import NotchNull

@MainActor
final class AgentHubTests: XCTestCase {
    private var temporaryHome: URL!

    override func setUpWithError() throws {
        temporaryHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentHubTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryHome, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryHome)
    }

    func testRefreshPublishesAvailabilityWithoutChangingPreferences() throws {
        let preferences = Preferences.shared
        let savedCodexEnabled = preferences.codexEnabled
        defer { preferences.codexEnabled = savedCodexEnabled }
        preferences.codexEnabled = false

        let hub = AgentHub(installation: AgentInstallation(homeDirectory: temporaryHome))
        XCTAssertTrue(hub.installed.isEmpty)

        let projects = temporaryHome.appendingPathComponent(".claude/projects", isDirectory: true)
        try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
        hub.refreshInstalled()

        XCTAssertEqual(hub.installed, [.claude])
        XCTAssertFalse(preferences.codexEnabled)
    }

    func testAppActivationRefreshIsThrottledToTwoSeconds() throws {
        let hub = AgentHub(installation: AgentInstallation(homeDirectory: temporaryHome))
        let projects = temporaryHome.appendingPathComponent(".claude/projects", isDirectory: true)
        let t0 = Date(timeIntervalSince1970: 10_000)

        try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
        hub.refreshAfterAppActivation(at: t0)
        XCTAssertEqual(hub.installed, [.claude])

        try FileManager.default.removeItem(at: projects)
        hub.refreshAfterAppActivation(at: t0.addingTimeInterval(1.9))
        XCTAssertEqual(hub.installed, [.claude], "An activation inside the throttle window must not rescan")

        hub.refreshAfterAppActivation(at: t0.addingTimeInterval(2))
        XCTAssertTrue(hub.installed.isEmpty)
    }

    func testPreviewCanOverrideInstalledProviders() {
        let hub = AgentHub(installation: AgentInstallation(homeDirectory: temporaryHome))
        hub.preview(warning: nil, hooksInstalled: false, opencodePluginInstalled: false, installed: [.opencode])
        XCTAssertEqual(hub.installed, [.opencode])
    }
}
