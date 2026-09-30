import XCTest
@testable import NotchNull

@MainActor
final class TabSwipeTests: XCTestCase {
    private let geometry = NotchGeometry(
        screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        notchSize: CGSize(width: 185, height: 32),
        hasHardwareNotch: true
    )

    private var saved: [String: Any] = [:]

    override func setUp() async throws {
        let preferences = Preferences.shared
        saved = [
            "tabOrder": preferences.tabOrder,
            "hiddenTabs": preferences.hiddenTabs,
            "tray": preferences.trayEnabled,
            "clipboard": preferences.clipboardEnabled,
            "swipe": preferences.tabSwipeEnabled,
        ]
        preferences.tabOrder = ["home", "controls", "tray", "clipboard"]
        preferences.hiddenTabs = Set(NotchTab.allCases.map(\.rawValue)).subtracting(["home", "controls", "tray", "clipboard"])
        preferences.trayEnabled = true
        preferences.clipboardEnabled = true
        preferences.tabSwipeEnabled = true
    }

    override func tearDown() async throws {
        let preferences = Preferences.shared
        preferences.tabOrder = saved["tabOrder"] as? [String] ?? NotchTab.allCases.map(\.rawValue)
        preferences.hiddenTabs = saved["hiddenTabs"] as? Set<String> ?? []
        preferences.trayEnabled = saved["tray"] as? Bool ?? true
        preferences.clipboardEnabled = saved["clipboard"] as? Bool ?? true
        preferences.tabSwipeEnabled = saved["swipe"] as? Bool ?? true
    }

    func testSwipeIsOnByDefault() {
        XCTAssertEqual(Preferences.factoryDefaults[Preferences.Keys.tabSwipe] as? Bool, true)
    }

    func testFingerDirectionMapsLeftToPositive() {
        // Natural scrolling inverts device direction: fingers-left reports negative.
        XCTAssertEqual(TabSwipe.fingerDeltaX(scrollingDeltaX: -5, inverted: true), 5)
        // Traditional scrolling follows the device: fingers-left reports positive.
        XCTAssertEqual(TabSwipe.fingerDeltaX(scrollingDeltaX: 5, inverted: false), 5)
    }

    func testOnlyHorizontalGesturesSwitch() {
        XCTAssertTrue(TabSwipe.isHorizontal(10, 2))
        XCTAssertFalse(TabSwipe.isHorizontal(2, 10))
        XCTAssertFalse(TabSwipe.isHorizontal(0.2, 0))
    }

    func testThresholdGivesSingleSteps() {
        XCTAssertEqual(TabSwipe.step(for: TabSwipe.threshold), 1)
        XCTAssertEqual(TabSwipe.step(for: -TabSwipe.threshold), -1)
        XCTAssertNil(TabSwipe.step(for: TabSwipe.threshold - 1))
        XCTAssertNil(TabSwipe.step(for: -(TabSwipe.threshold - 1)))
    }

    func testStepTabMovesThroughOrderAndClamps() {
        let model = NotchViewModel(geometry: geometry, center: ActivityCenter())
        model.preview(phase: .open, tab: .home)
        model.stepTab(by: 1)
        XCTAssertEqual(model.selectedTab, .controls)
        XCTAssertEqual(model.tabDirection, .trailing)
        model.stepTab(by: -1)
        XCTAssertEqual(model.selectedTab, .home)
        XCTAssertEqual(model.tabDirection, .leading)
        // Clamps at the ends instead of wrapping.
        model.stepTab(by: -1)
        XCTAssertEqual(model.selectedTab, .home)
        model.preview(phase: .open, tab: .clipboard)
        model.stepTab(by: 1)
        XCTAssertEqual(model.selectedTab, .clipboard)
    }
}
