import SwiftUI

/// Minimal SVG path-data parser (M L H V C S Q T A Z, absolute and relative) producing a
/// SwiftUI `Path` in the SVG's own coordinate space. Used for the provider brand marks.
enum SVGPath {
    static func parse(_ data: String) -> Path {
        var scanner = Scanner(data)
        var path = Path()
        var current = CGPoint.zero
        var start = CGPoint.zero
        var lastControl: CGPoint?
        var command: Character = "M"

        while let next = scanner.nextCommandOrNumber() {
            if case .command(let c) = next { command = c } else { scanner.rewindNumber() }
            let relative = command.isLowercase
            let base = relative ? current : .zero
            switch command.uppercased().first! {
            case "M":
                guard let p = scanner.point() else { return path }
                current = CGPoint(x: base.x + p.x, y: base.y + p.y)
                start = current
                path.move(to: current)
                command = relative ? "l" : "L"
                lastControl = nil
            case "L":
                guard let p = scanner.point() else { return path }
                current = CGPoint(x: base.x + p.x, y: base.y + p.y)
                path.addLine(to: current)
                lastControl = nil
            case "H":
                guard let x = scanner.number() else { return path }
                current = CGPoint(x: (relative ? current.x : 0) + x, y: current.y)
                path.addLine(to: current)
                lastControl = nil
            case "V":
                guard let y = scanner.number() else { return path }
                current = CGPoint(x: current.x, y: (relative ? current.y : 0) + y)
                path.addLine(to: current)
                lastControl = nil
            case "C":
                guard let c1 = scanner.point(), let c2 = scanner.point(), let p = scanner.point() else { return path }
                let control2 = CGPoint(x: base.x + c2.x, y: base.y + c2.y)
                current = CGPoint(x: base.x + p.x, y: base.y + p.y)
                path.addCurve(to: current, control1: CGPoint(x: base.x + c1.x, y: base.y + c1.y), control2: control2)
                lastControl = control2
            case "S":
                guard let c2 = scanner.point(), let p = scanner.point() else { return path }
                let control1 = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let control2 = CGPoint(x: base.x + c2.x, y: base.y + c2.y)
                current = CGPoint(x: base.x + p.x, y: base.y + p.y)
                path.addCurve(to: current, control1: control1, control2: control2)
                lastControl = control2
            case "Q":
                guard let c = scanner.point(), let p = scanner.point() else { return path }
                let control = CGPoint(x: base.x + c.x, y: base.y + c.y)
                current = CGPoint(x: base.x + p.x, y: base.y + p.y)
                path.addQuadCurve(to: current, control: control)
                lastControl = control
            case "T":
                guard let p = scanner.point() else { return path }
                let control = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                current = CGPoint(x: base.x + p.x, y: base.y + p.y)
                path.addQuadCurve(to: current, control: control)
                lastControl = control
            case "A":
                guard let rx = scanner.number(), let ry = scanner.number(), let rotation = scanner.number(),
                      let large = scanner.flag(), let sweep = scanner.flag(), let p = scanner.point() else { return path }
                let end = CGPoint(x: base.x + p.x, y: base.y + p.y)
                addArc(to: &path, from: current, to: end, rx: rx, ry: ry, rotation: rotation, largeArc: large, sweep: sweep)
                current = end
                lastControl = nil
            case "Z":
                path.closeSubpath()
                current = start
                lastControl = nil
            default:
                return path
            }
        }
        return path
    }

    /// SVG endpoint arc → cubic Béziers (SVG 1.1 implementation notes, F.6).
    private static func addArc(to path: inout Path, from p0: CGPoint, to p1: CGPoint, rx: CGFloat, ry: CGFloat, rotation: CGFloat, largeArc: Bool, sweep: Bool) {
        var rx = abs(rx), ry = abs(ry)
        guard rx > 0, ry > 0, p0 != p1 else {
            path.addLine(to: p1)
            return
        }
        let phi = rotation * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1 = cosPhi * dx + sinPhi * dy
        let y1 = -sinPhi * dx + cosPhi * dy
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 {
            rx *= sqrt(lambda)
            ry *= sqrt(lambda)
        }
        let numerator = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
        var coefficient = sqrt(max(0, numerator / denominator))
        if largeArc == sweep { coefficient = -coefficient }
        let cx1 = coefficient * rx * y1 / ry
        let cy1 = -coefficient * ry * x1 / rx
        let cx = cosPhi * cx1 - sinPhi * cy1 + (p0.x + p1.x) / 2
        let cy = sinPhi * cx1 + cosPhi * cy1 + (p0.y + p1.y) / 2

        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let sign: CGFloat = ux * vy - uy * vx < 0 ? -1 : 1
            let dot = (ux * vx + uy * vy) / (sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy))
            return sign * acos(max(-1, min(1, dot)))
        }
        let theta1 = angle(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
        var delta = angle((x1 - cx1) / rx, (y1 - cy1) / ry, (-x1 - cx1) / rx, (-y1 - cy1) / ry)
        if !sweep && delta > 0 { delta -= 2 * .pi }
        if sweep && delta < 0 { delta += 2 * .pi }

        let segments = max(1, Int(ceil(abs(delta) / (.pi / 2))))
        let step = delta / CGFloat(segments)
        let t = 4 / 3 * tan(step / 4)
        var theta = theta1
        func point(_ angle: CGFloat) -> CGPoint {
            CGPoint(
                x: cx + rx * cos(angle) * cosPhi - ry * sin(angle) * sinPhi,
                y: cy + rx * cos(angle) * sinPhi + ry * sin(angle) * cosPhi
            )
        }
        func derivative(_ angle: CGFloat) -> CGPoint {
            CGPoint(
                x: -rx * sin(angle) * cosPhi - ry * cos(angle) * sinPhi,
                y: -rx * sin(angle) * sinPhi + ry * cos(angle) * cosPhi
            )
        }
        for _ in 0..<segments {
            let next = theta + step
            let start = point(theta), end = point(next)
            let d1 = derivative(theta), d2 = derivative(next)
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x + t * d1.x, y: start.y + t * d1.y),
                control2: CGPoint(x: end.x - t * d2.x, y: end.y - t * d2.y)
            )
            theta = next
        }
    }

    private struct Scanner {
        enum Token { case command(Character), number }
        private let chars: [Character]
        private var index = 0
        private var lastNumberStart = 0

        init(_ string: String) { chars = Array(string) }

        private mutating func skipSeparators() {
            while index < chars.count, chars[index] == " " || chars[index] == "," || chars[index].isNewline { index += 1 }
        }

        mutating func nextCommandOrNumber() -> Token? {
            skipSeparators()
            guard index < chars.count else { return nil }
            let c = chars[index]
            if c.isLetter {
                index += 1
                return .command(c)
            }
            lastNumberStart = index
            return .number
        }

        mutating func rewindNumber() { index = lastNumberStart }

        mutating func number() -> CGFloat? {
            skipSeparators()
            guard index < chars.count else { return nil }
            var text = ""
            var seenDot = false, seenExponent = false
            if chars[index] == "-" || chars[index] == "+" {
                text.append(chars[index])
                index += 1
            }
            while index < chars.count {
                let c = chars[index]
                if c.isNumber {
                    text.append(c)
                } else if c == ".", !seenDot, !seenExponent {
                    seenDot = true
                    text.append(c)
                } else if (c == "e" || c == "E"), !seenExponent {
                    seenExponent = true
                    text.append(c)
                    if index + 1 < chars.count, chars[index + 1] == "-" || chars[index + 1] == "+" {
                        index += 1
                        text.append(chars[index])
                    }
                } else {
                    break
                }
                index += 1
            }
            return Double(text).map { CGFloat($0) }
        }

        /// Arc flags are single digits that may be written without separators ("0 0 1" or "001").
        mutating func flag() -> Bool? {
            skipSeparators()
            guard index < chars.count, chars[index] == "0" || chars[index] == "1" else { return nil }
            defer { index += 1 }
            return chars[index] == "1"
        }

        mutating func point() -> CGPoint? {
            guard let x = number(), let y = number() else { return nil }
            return CGPoint(x: x, y: y)
        }
    }
}

/// A shape from SVG path data authored in a square view box, scaled to fit its frame.
struct SVGShape: Shape {
    let path: Path
    var viewBox: CGFloat = 24

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / viewBox
        let offset = CGPoint(x: rect.midX - viewBox * scale / 2, y: rect.midY - viewBox * scale / 2)
        return path.applying(CGAffineTransform(translationX: offset.x, y: offset.y).scaledBy(x: scale, y: scale))
    }
}
