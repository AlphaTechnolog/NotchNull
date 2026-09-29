import SwiftUI

/// The notch body: concave flares at the top corners (so it melts into the menu bar like the
/// hardware notch) and rounded bottom corners. Both radii animate, which is what lets one body
/// morph between closed, wing and open states.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    /// When true only the lower outline (sides and bottom) is produced, for the emission edge.
    var edgeOnly = false

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let top = min(topRadius, rect.width / 4)
        let bottom = min(bottomRadius, (rect.height - top) / 1.2, (rect.width - top * 2) / 2)
        let minX = rect.minX, maxX = rect.maxX, minY = rect.minY, maxY = rect.maxY
        let k: CGFloat = 0.45

        var path = Path()
        if edgeOnly {
            path.move(to: CGPoint(x: minX + top, y: minY + top))
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
        path.addLine(to: CGPoint(x: maxX - top, y: minY + top))
        if !edgeOnly {
            path.addQuadCurve(to: CGPoint(x: maxX, y: minY), control: CGPoint(x: maxX - top, y: minY))
            path.closeSubpath()
        }
        return path
    }
}
