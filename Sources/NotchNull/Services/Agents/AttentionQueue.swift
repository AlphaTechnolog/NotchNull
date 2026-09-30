import Combine
import CoreGraphics

/// How many agent sessions are waiting for the user. The needs-you banner grows with it, so the
/// notch geometry observes it the way it observes a custom activity.
@MainActor
final class AttentionQueue: ObservableObject {
    static let shared = AttentionQueue()

    @Published private(set) var count = 0

    func update(_ count: Int) {
        if count != self.count { self.count = count }
    }

    /// Banner rows shown at once; the rest are summed up in a "+N more" line.
    static let visibleRows = 3

    /// Room below the notch row: one session gets its question on two lines; several get a row each.
    static func extraHeight(for count: Int) -> CGFloat {
        guard count > 1 else { return 70 }
        let rows = CGFloat(min(count, visibleRows))
        return 10 + rows * 36 + (count > visibleRows ? 16 : 0)
    }
}
