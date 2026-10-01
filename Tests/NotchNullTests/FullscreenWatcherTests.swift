import XCTest
@testable import NotchNull

@MainActor
final class FullscreenWatcherTests: XCTestCase {
    private let display0 = FullscreenScreen(id: 1, width: 1512, height: 982)
    private let display1 = FullscreenScreen(id: 2, width: 1920, height: 1080)

    func testHiddenByDefault() {
        XCTAssertEqual(Preferences.factoryDefaults[Preferences.Keys.hideOnFullscreen] as? Bool, true)
    }

    func testFullscreenOnOneDisplayHidesOnlyThatDisplay() {
        let windows = [
            FullscreenWindow(owner: "Safari", pid: 100, layer: 0, width: 1920, height: 1080),
        ]
        let result = FullscreenWatcher.fullscreenDisplayIDs(
            windows: windows, screens: [display0, display1], ownPID: 999
        )
        XCTAssertEqual(result, [display1.id])
    }

    func testNoFullscreenWindowMatchesNothing() {
        let windows = [
            FullscreenWindow(owner: "Safari", pid: 100, layer: 0, width: 800, height: 600),
        ]
        XCTAssertTrue(FullscreenWatcher.fullscreenDisplayIDs(
            windows: windows, screens: [display0, display1], ownPID: 999
        ).isEmpty)
    }

    func testSystemOverlaysAndOwnWindowsAreIgnored() {
        let covering = FullscreenWindow(owner: "Dock", pid: 101, layer: 0, width: 1512, height: 982)
        let own = FullscreenWindow(owner: "NotchNull", pid: 999, layer: 0, width: 1512, height: 982)
        let result = FullscreenWatcher.fullscreenDisplayIDs(
            windows: [covering, own], screens: [display0], ownPID: 999
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testNonzeroLayersAreIgnored() {
        let windows = [
            FullscreenWindow(owner: "Overlay", pid: 100, layer: 25, width: 1512, height: 982),
        ]
        XCTAssertTrue(FullscreenWatcher.fullscreenDisplayIDs(
            windows: windows, screens: [display0], ownPID: 999
        ).isEmpty)
    }

    func testOnePixelRoundingStillCounts() {
        let windows = [
            FullscreenWindow(owner: "Game", pid: 100, layer: 0, width: 1512, height: 981),
        ]
        XCTAssertEqual(
            FullscreenWatcher.fullscreenDisplayIDs(windows: windows, screens: [display0], ownPID: 999),
            [display0.id]
        )
    }
}
