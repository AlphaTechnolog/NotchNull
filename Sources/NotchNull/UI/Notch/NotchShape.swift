import SwiftUI

/// The notch body: concave flares at the top corners (so it melts into the menu bar like the
/// hardware notch) and rounded bottom corners. With `capRadius` the top corners round outward
/// instead and the same body floats as an island. Every radius animates, which is what lets one
/// body morph between closed, wing and open states, and between notch and island.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    /// Convex top corners, for the island. Use with `topRadius` 0.
    var capRadius: CGFloat = 0
    /// When true only the lower outline (sides and bottom) is produced, for the emission edge.
    var edgeOnly = false

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(topRadius, AnimatablePair(bottomRadius, capRadius)) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second.first
            capRadius = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let top = min(topRadius, rect.width / 4)
        let cap = max(0, min(capRadius, rect.height / 2, rect.width / 2))
        let bottom = max(0, min(bottomRadius, (rect.height - top) / (cap > 0 ? 2 : 1.2), (rect.width - top * 2) / 2))
        let minX = rect.minX, maxX = rect.maxX, minY = rect.minY, maxY = rect.maxY
        let k: CGFloat = 0.45

        var path = Path()
        if edgeOnly {
            path.move(to: CGPoint(x: minX + top, y: minY + top + cap))
        } else if cap > 0 {
            path.move(to: CGPoint(x: minX, y: minY + cap))
        } else {
            path.move(to: CGPoint(x: minX, y: minY))
            path.addQuadCurve(to: CGPoint(x: minX + top, y: minY + top), control: CGPoint(x: minX + top, y: minY))
        }
        path.addLine(to: CGPoint(x: minX + top, y: maxY - bottom))
        path.addCurve(
            to: CGPoint(x: minX + top + bottom, y: maxY),
            control1: CGPoint(x: minX + top, y: maxY - bottom * k),
            control2: CGPoint(x: minX + top + bottom * k, y: maxY)
        )
        path.addLine(to: CGPoint(x: maxX - top - bottom, y: maxY))
        path.addCurve(
            to: CGPoint(x: maxX - top, y: maxY - bottom),
            control1: CGPoint(x: maxX - top - bottom * k, y: maxY),
            control2: CGPoint(x: maxX - top, y: maxY - bottom * k)
        )
        path.addLine(to: CGPoint(x: maxX - top, y: minY + top + cap))
        guard !edgeOnly else { return path }
        if cap > 0 {
            path.addCurve(
                to: CGPoint(x: maxX - cap, y: minY),
                control1: CGPoint(x: maxX, y: minY + cap * k),
                control2: CGPoint(x: maxX - cap * k, y: minY)
            )
            path.addLine(to: CGPoint(x: minX + cap, y: minY))
            path.addCurve(
                to: CGPoint(x: minX, y: minY + cap),
                control1: CGPoint(x: minX + cap * k, y: minY),
                control2: CGPoint(x: minX, y: minY + cap * k)
            )
        } else {
            path.addQuadCurve(to: CGPoint(x: maxX, y: minY), control: CGPoint(x: maxX - top, y: minY))
        }
        path.closeSubpath()
        return path
    }
}
