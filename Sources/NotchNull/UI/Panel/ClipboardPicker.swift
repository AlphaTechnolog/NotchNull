import Combine
import SwiftUI

/// Keyboard state of the Clipboard tab: the search text and the highlighted tile, shared by the
/// tab and the window controller that turns key presses into moves.
@MainActor
final class ClipboardPicker: ObservableObject {
    enum Direction { case left, right, up, down }

    static let columns = 2
    static let visibleLimit = 40

    @Published var query = "" {
        didSet { if query != oldValue { selection = 0 } }
    }
    @Published private(set) var selection = 0
    /// True while the keyboard drives the tab (opened with the shortcut or typing in search).
    @Published private(set) var isKeyboardActive = false
    /// Bumped to ask the search field to take focus.
    @Published private(set) var focusRequests = 0

    func visibleItems(from items: [ClipItem]) -> [ClipItem] {
        Array(items.filter { $0.matches(query) }.prefix(Self.visibleLimit))
    }

    func selectedItem(in items: [ClipItem]) -> ClipItem? {
        let visible = visibleItems(from: items)
        return visible.indices.contains(selection) ? visible[selection] : nil
    }

    func begin() {
        isKeyboardActive = true
        selection = 0
        focusRequests += 1
    }

    func end() {
        isKeyboardActive = false
        query = ""
        selection = 0
    }

    func move(_ direction: Direction, itemCount: Int) {
        isKeyboardActive = true
        selection = Self.index(after: selection, moving: direction, count: itemCount, columns: Self.columns)
    }

    /// Grid navigation in reading order: left and right step one tile, up and down one row; the
    /// highlight stops at the edges instead of wrapping.
    nonisolated static func index(after current: Int, moving direction: Direction, count: Int, columns: Int) -> Int {
        guard count > 0 else { return 0 }
        let current = min(max(current, 0), count - 1)
        let target: Int
        switch direction {
        case .left: target = current - 1
        case .right: target = current + 1
        case .up: target = current - columns
        case .down: target = current + columns
        }
        if direction == .down, target >= count {
            // From the row above a shorter last row, land on its last tile.
            return current / columns == (count - 1) / columns ? current : count - 1
        }
        return min(max(target, 0), count - 1) == target ? target : current
    }
}
