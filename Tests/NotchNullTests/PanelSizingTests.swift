import XCTest
@testable import NotchNull

@MainActor
final class PanelSizingTests: XCTestCase {
    private let geometry = NotchGeometry(
        screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        notchSize: CGSize(width: 185, height: 32),
        hasHardwareNotch: true
    )

    private var saved: [String: Any] = [:]

    override func setUp() async throws {
        let preferences = Preferences.shared
        saved = [
            "panelWidth": preferences.panelWidth, "panelHeight": preferences.panelHeight,
            "hiddenTabs": preferences.hiddenTabs, "agentsEnabled": preferences.agentsEnabled,
            "shapeStyle": preferences.shapeStyle,
        ]
        preferences.panelWidth = 500
        preferences.panelHeight = 148
        preferences.hiddenTabs = Set(NotchTab.allCases.filter { $0 != .home && $0 != .agents }.map(\.rawValue))
        preferences.agentsEnabled = true
        preferences.shapeStyle = .notch
    }

    override func tearDown() async throws {
        let preferences = Preferences.shared
        preferences.panelWidth = saved["panelWidth"] as? Double ?? 500
        preferences.panelHeight = saved["panelHeight"] as? Double ?? 148
        preferences.hiddenTabs = saved["hiddenTabs"] as? Set<String> ?? []
        preferences.agentsEnabled = saved["agentsEnabled"] as? Bool ?? true
        preferences.shapeStyle = saved["shapeStyle"] as? Preferences.ShapeStyle ?? .auto
    }

    private func openModel(tab: NotchTab) -> NotchViewModel {
        let model = NotchViewModel(geometry: geometry, center: ActivityCenter())
        model.preview(phase: .open, tab: tab)
        return model
    }

    func testAgentsShrinksToTheRequestedContentHeight() {
        let model = openModel(tab: .agents)
        model.requestPanelContentHeight(82, for: .agents)
        XCTAssertEqual(model.effectivePanelContentHeight(for: .agents), 82)
        XCTAssertEqual(model.bodySize.height, model.headerHeight + 82)
    }

    func testAgentsNeverGrowsPastTheConfiguredHeight() {
        let model = openModel(tab: .agents)
        model.requestPanelContentHeight(260, for: .agents)
        XCTAssertEqual(model.effectivePanelContentHeight(for: .agents), 148)
        XCTAssertEqual(model.bodySize.height, model.headerHeight + 148)
    }

    func testOtherTabsKeepTheConfiguredHeight() {
        let model = openModel(tab: .agents)
        model.requestPanelContentHeight(82, for: .agents)
        model.select(.home)
        XCTAssertEqual(model.effectivePanelContentHeight(for: .home), 148)
        XCTAssertEqual(model.bodySize.height, model.headerHeight + 148)
    }

    func testSwitchingTabsReusesCachedFittedHeight() {
        let model = openModel(tab: .agents)
        model.requestPanelContentHeight(82, for: .agents)
        let fitted = model.bodySize
        for _ in 0..<3 {
            model.select(.home)
            XCTAssertEqual(model.bodySize.height, model.headerHeight + 148)
            model.select(.agents)
            XCTAssertEqual(model.bodySize, fitted)
        }
        XCTAssertEqual(Preferences.shared.panelHeight, 148, "The fitted height is not a preference")
    }

    func testLoweringTheConfiguredHeightRecapsAnOpenAgentsPanel() {
        let model = openModel(tab: .agents)
        model.requestPanelContentHeight(180, for: .agents)
        XCTAssertEqual(model.effectivePanelContentHeight(for: .agents), 148)
        Preferences.shared.panelHeight = 120
        XCTAssertEqual(model.effectivePanelContentHeight(for: .agents), 120)
        XCTAssertEqual(model.bodySize.height, model.headerHeight + 120)
    }

    func testHiddenAgentsSelectionUsesTheVisibleTabsHeight() {
        let model = openModel(tab: .agents)
        model.requestPanelContentHeight(82, for: .agents)
        Preferences.shared.hiddenTabs.insert(NotchTab.agents.rawValue)
        XCTAssertEqual(model.visibleTab, .home)
        XCTAssertEqual(model.bodySize.height, model.headerHeight + 148)
    }

    func testDisabledAgentsSelectionUsesTheVisibleTabsHeight() {
        let model = openModel(tab: .agents)
        model.requestPanelContentHeight(82, for: .agents)
        Preferences.shared.agentsEnabled = false
        XCTAssertEqual(model.visibleTab, .home)
        XCTAssertEqual(model.bodySize.height, model.headerHeight + 148)
    }

    func testFittedHeightOnlyAppliesToTheOpenPanel() {
        let model = openModel(tab: .agents)
        model.requestPanelContentHeight(82, for: .agents)
        for phase: NotchViewModel.Phase in [.closed, .drop, .activity(.needsYou)] {
            model.preview(phase: phase, tab: .agents)
            let agentsSize = model.bodySize
            model.preview(phase: phase, tab: .home)
            XCTAssertEqual(model.bodySize, agentsSize)
        }
    }

    func testIslandAgentsPanelAlsoFitsItsContent() {
        Preferences.shared.shapeStyle = .island
        let home = openModel(tab: .home)
        let agents = openModel(tab: .agents)
        agents.requestPanelContentHeight(82, for: .agents)
        XCTAssertEqual(home.bodySize.height, home.headerHeight + 148)
        XCTAssertEqual(agents.bodySize.height, agents.headerHeight + 82)
    }

    func testFittedAgentsHeightStillRespectsTheCanvasClamp() {
        let model = openModel(tab: .agents)
        Preferences.shared.panelHeight = Double(Theme.Size.canvas.height)
        model.requestPanelContentHeight(700, for: .agents)
        XCTAssertEqual(model.effectivePanelContentHeight(for: .agents), Theme.Size.canvas.height - model.bodyTop - 40 - model.headerHeight)
        XCTAssertEqual(model.bodySize.height, Theme.Size.canvas.height - model.bodyTop - 40)
    }

    func testMeasurementUpdatesIgnoreSubPointNoise() {
        let model = openModel(tab: .agents)
        model.requestPanelContentHeight(82, for: .agents)
        model.requestPanelContentHeight(83, for: .agents)
        XCTAssertEqual(model.requestedPanelHeights[.agents], 82, "A one-point change should not resize the panel")
        model.requestPanelContentHeight(84, for: .agents)
        XCTAssertEqual(model.requestedPanelHeights[.agents], 84)
    }

    func testPreviewCanSeedFittedHeightForSnapshots() {
        let model = NotchViewModel(geometry: geometry, center: ActivityCenter())
        model.preview(phase: .open, tab: .agents, fittedPanelHeights: [.agents: 92])
        XCTAssertEqual(model.requestedPanelHeights[.agents], 92)
        XCTAssertEqual(model.bodySize.height, model.headerHeight + 92)
    }
}
