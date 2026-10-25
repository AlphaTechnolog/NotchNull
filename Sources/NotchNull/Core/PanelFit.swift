import Foundation

/// Fits the open panel's content height to the taller Agents column while keeping the configured
/// height as a maximum. The Agents tab measures intrinsic column heights; these helpers turn that
/// measurement into the body height without depending on SwiftUI layout.
enum PanelFit {
    /// `Card(padding: 8)` applies this on both sides.
    static let cardPadding: CGFloat = 8
    /// `ExpandedPanel` keeps the tab content off the header and bottom edge.
    static let panelTopPadding: CGFloat = 4
    static let panelBottomPadding: CGFloat = Theme.Radius.panelPadding
    /// Everything around the two Agents columns: card insets plus the panel's vertical padding.
    static let chromeHeight = cardPadding * 2 + panelTopPadding + panelBottomPadding

    /// Content height requested by columns measured at `tallestColumn`, rounded up so a fractional
    /// measurement cannot leave a half-point gap.
    static func contentHeight(tallestColumn: CGFloat) -> CGFloat {
        guard tallestColumn.isFinite, tallestColumn > 0 else { return 0 }
        return ceil(tallestColumn + chromeHeight)
    }

    /// The height the panel may actually use: never taller than the configured maximum or the
    /// space left inside the body canvas. A zero request means "not measured yet" and falls back
    /// to the configured height.
    static func fittedContentHeight(
        requested: CGFloat,
        configured: CGFloat,
        canvasMaximum: CGFloat = .infinity
    ) -> CGFloat {
        let limit = max(0, min(configured, canvasMaximum))
        guard requested.isFinite, requested > 0 else { return limit }
        return max(0, min(requested, limit))
    }
}
