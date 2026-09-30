import AppKit

/// Horizontal swipe state for switching panel tabs. Pure logic lives here so it can be
/// unit tested without synthesizing NSEvents; `NotchWindowController` owns the accumulator.
enum TabSwipe {
    /// Finger travel needed before switching one tab.
    static let threshold: CGFloat = 28
    /// Minimum gap between two switches from one continuous gesture.
    static let cooldown: TimeInterval = 0.35

    /// Finger direction in points, positive when the fingers move left.
    /// Left moves to the next tab, right to the previous one.
    static func fingerDeltaX(scrollingDeltaX: CGFloat, inverted: Bool) -> CGFloat {
        inverted ? -scrollingDeltaX : scrollingDeltaX
    }

    /// True when the gesture is clearly horizontal, so diagonal scrolls do not switch tabs.
    static func isHorizontal(_ dx: CGFloat, _ dy: CGFloat) -> Bool {
        abs(dx) > abs(dy) * 1.5 && abs(dx) > 0.5
    }

    /// +1 (next), -1 (prev) or nil when the accumulated travel is below threshold.
    static func step(for accumulated: CGFloat) -> Int? {
        if accumulated >= threshold { return 1 }
        if accumulated <= -threshold { return -1 }
        return nil
    }
}
