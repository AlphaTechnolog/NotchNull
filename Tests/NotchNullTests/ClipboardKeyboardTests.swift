import AppKit
import XCTest
@testable import NotchNull

final class ClipboardKeyboardTests: XCTestCase {
    private func move(_ from: Int, _ direction: ClipboardPicker.Direction, count: Int) -> Int {
        ClipboardPicker.index(after: from, moving: direction, count: count, columns: 2)
    }

    func testArrowsWalkTheTwoColumnGridInReadingOrder() {
        XCTAssertEqual(move(0, .right, count: 6), 1)
        XCTAssertEqual(move(1, .left, count: 6), 0)
        XCTAssertEqual(move(0, .down, count: 6), 2)
        XCTAssertEqual(move(3, .up, count: 6), 1)
    }

    func testHighlightStopsAtTheEdgesInsteadOfWrapping() {
        XCTAssertEqual(move(0, .left, count: 6), 0)
        XCTAssertEqual(move(1, .up, count: 6), 1)
        XCTAssertEqual(move(5, .right, count: 6), 5)
        XCTAssertEqual(move(4, .down, count: 6), 4)
    }

    func testDownFromAboveAShortLastRowLandsOnItsOnlyTile() {
        // Five tiles: the last row holds only index 4, so down from index 3 goes to 4.
        XCTAssertEqual(move(3, .down, count: 5), 4)
        XCTAssertEqual(move(4, .down, count: 5), 4)
    }

    func testEmptyListAndOutOfRangeSelectionAreClamped() {
        XCTAssertEqual(move(3, .down, count: 0), 0)
        XCTAssertEqual(move(9, .left, count: 3), 1)
    }

    func testShortcutDisplaysModifiersInMenuOrder() {
        let shortcut = KeyShortcut(keyCode: 9, modifiers: [.command, .shift, .option, .control], key: "V")
        XCTAssertEqual(shortcut.display, "⌃⌥⇧⌘V")
        XCTAssertEqual(KeyShortcut.clipboardDefault.display, "⌃⌘V")
    }

    func testShortcutSurvivesThePreferencesRoundTripAndDropsIrrelevantFlags() {
        let shortcut = KeyShortcut(keyCode: 9, modifiers: [.control, .command, .capsLock, .function], key: "V")
        XCTAssertEqual(shortcut.modifiers, [.control, .command])
        XCTAssertEqual(KeyShortcut(dictionary: shortcut.dictionary), shortcut)
        XCTAssertNil(KeyShortcut(dictionary: [:]), "An empty dictionary means the shortcut is off")
    }

    func testCarbonModifiersMatchTheRecordedFlags() {
        XCTAssertEqual(KeyShortcut.clipboardDefault.carbonModifiers, 0x1000 | 0x0100) // controlKey | cmdKey
    }
}
