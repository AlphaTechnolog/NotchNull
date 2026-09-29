import SwiftUI

/// Brand colors shared by the app icon, the About screen, onboarding and the website.
enum Brand {
    static let pink = Color(hex: 0xFF5E8A)
    static let violet = Color(hex: 0xA78BFA)
    static let cyan = Color(hex: 0x5AC8FA)
    static let graphiteTop = Color(hex: 0x2A2D34)
    static let graphiteBottom = Color(hex: 0x0E0F12)

    static var glow: LinearGradient {
        LinearGradient(colors: [pink, violet, cyan], startPoint: .leading, endPoint: .trailing)
    }
}

/// The NotchNull mark: a null sign (a ring crossed by a slash), drawn as strokes so it stays
/// crisp from a 16 pt menu bar glyph to the 1024 px icon.
struct NullMark: View {
    var size: CGFloat = 24
    var color: Color = .white
    /// Stroke weight relative to the mark's size.
    var weight: CGFloat = 0.1

    var body: some View {
        let line = size * weight
        ZStack {
            Circle()
                .stroke(color, lineWidth: line)
                .padding(size * 0.14)
            NullSlash()
                .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct NullSlash: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.maxY - rect.height * 0.1))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.minY + rect.height * 0.1))
        return path
    }
}
