import XCTest
@testable import NotchNull

@MainActor
final class FullscreenWatcherTests: XCTestCase {
    private let display0 = FullscreenScreen(id: 1, bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080))
    private let display1 = FullscreenScreen(id: 2, bounds: CGRect(x: 1920, y: 0, width: 1920, height: 1080))

    func testHiddenByDefault() {
        XCTAssertEqual(Preferences.factoryDefaults[Preferences.Keys.hideOnFullscreen] as? Bool, true)
    }

    func testFullscreenOnOneEqualSizedDisplayHidesOnlyThatDisplay() {
        let windows = [
            FullscreenWindow(owner: "Safari", pid: 100, layer: 0, bounds: display1.bounds),
        ]
        let result = FullscreenWatcher.fullscreenDisplayIDs(
            windows: windows, screens: [display0, display1], ownPID: 999
        )
        XCTAssertEqual(result, [display1.id])
    }

    func testNoFullscreenWindowMatchesNothing() {
        let windows = [
            FullscreenWindow(owner: "Safari", pid: 100, layer: 0, bounds: CGRect(x: 0, y: 0, width: 800, height: 600)),
        ]
        XCTAssertTrue(FullscreenWatcher.fullscreenDisplayIDs(
            windows: windows, screens: [display0, display1], ownPID: 999
        ).isEmpty)
    }

    func testSystemOverlaysAndOwnWindowsAreIgnored() {
        let covering = FullscreenWindow(owner: "Dock", pid: 101, layer: 0, bounds: display0.bounds)
        let own = FullscreenWindow(owner: "NotchNull", pid: 999, layer: 0, bounds: display0.bounds)
        let result = FullscreenWatcher.fullscreenDisplayIDs(
            windows: [covering, own], screens: [display0], ownPID: 999
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testNonzeroLayersAreIgnored() {
        let windows = [
            FullscreenWindow(owner: "Overlay", pid: 100, layer: 25, bounds: display0.bounds),
        ]
        XCTAssertTrue(FullscreenWatcher.fullscreenDisplayIDs(
            windows: windows, screens: [display0], ownPID: 999
        ).isEmpty)
    }

    func testOnePixelRoundingStillCounts() {
        let windows = [
            FullscreenWindow(owner: "Game", pid: 100, layer: 0, bounds: CGRect(x: 0, y: 0, width: 1920, height: 1079)),
        ]
        XCTAssertEqual(
            FullscreenWatcher.fullscreenDisplayIDs(windows: windows, screens: [display0], ownPID: 999),
            [display0.id]
        )
    }

    // A MacBook with a notch: fullscreen windows start below the camera housing.
    private let notched = FullscreenScreen(id: 3, bounds: CGRect(x: 0, y: 0, width: 1512, height: 982), topInset: 32)
    private var belowHousing: CGRect { CGRect(x: 0, y: 32, width: 1512, height: 950) }
    private var menuBar: FullscreenWindow {
        FullscreenWindow(owner: FullscreenWatcher.menuBarOwner, pid: 1, layer: FullscreenWatcher.menuBarLayer, bounds: CGRect(x: 0, y: 0, width: 1512, height: 32))
    }

    func testFullscreenBelowTheCameraHousingCounts() {
        let windows = [FullscreenWindow(owner: "Safari", pid: 100, layer: 0, bounds: belowHousing)]
        XCTAssertEqual(
            FullscreenWatcher.fullscreenDisplayIDs(windows: windows, screens: [notched], ownPID: 999),
            [notched.id]
        )
    }

    func testWindowZoomedUnderAVisibleMenuBarIsNotFullscreen() {
        let windows = [menuBar, FullscreenWindow(owner: "Safari", pid: 100, layer: 0, bounds: belowHousing)]
        XCTAssertTrue(FullscreenWatcher.fullscreenDisplayIDs(windows: windows, screens: [notched], ownPID: 999).isEmpty)
    }

    func testWindowBelowTheMenuBarOnADisplayWithoutNotchIsNotFullscreen() {
        let windows = [
            FullscreenWindow(owner: "Safari", pid: 100, layer: 0, bounds: CGRect(x: 0, y: 30, width: 1920, height: 1050)),
        ]
        XCTAssertTrue(FullscreenWatcher.fullscreenDisplayIDs(windows: windows, screens: [display0], ownPID: 999).isEmpty)
    }
}
