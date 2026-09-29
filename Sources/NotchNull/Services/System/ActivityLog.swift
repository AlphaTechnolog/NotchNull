import Combine
import SwiftUI

/// Recent things the notch told you about (finished agent runs, downloads, screenshots, limits…).
/// macOS does not let other apps read Notification Center, so this is NotchNull's own feed.
@MainActor
final class ActivityLog: ObservableObject {
    static let shared = ActivityLog()

    struct Entry: Identifiable, Equatable {
        let id = UUID()
        let symbol: String
        let tint: Color
        let title: String
        let detail: String?
        let date: Date
        var action: Action?

        enum Action: Equatable {
            case reveal(URL)
            case open(URL)
        }

        static func == (lhs: Entry, rhs: Entry) -> Bool { lhs.id == rhs.id }
    }

    @Published private(set) var entries: [Entry] = []
    private let limit = 30

    func add(symbol: String, tint: Color, title: String, detail: String? = nil, action: Entry.Action? = nil) {
        let entry = Entry(symbol: symbol, tint: tint, title: title, detail: detail, date: Date(), action: action)
        withAnimation(Motion.state) {
            entries.insert(entry, at: 0)
            if entries.count > limit { entries.removeLast(entries.count - limit) }
        }
    }

    func clear() {
        withAnimation(Motion.state) { entries.removeAll() }
    }

    func perform(_ entry: Entry) {
        switch entry.action {
        case .reveal(let url): NSWorkspace.shared.activateFileViewerSelecting([url])
        case .open(let url): NSWorkspace.shared.open(url)
        case nil: break
        }
    }
}
