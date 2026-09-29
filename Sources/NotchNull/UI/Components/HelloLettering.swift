import SwiftUI

/// Monoline cursive "hello", authored as one continuous stroke so it can be written on screen.
struct HelloPath: Shape {
    func path(in rect: CGRect) -> Path {
        // Authored in a 140 × 70 box.
        let sx = rect.width / 140, sy = rect.height / 70
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var path = Path()
        path.move(to: p(2, 60))
        // h: rising loop, stem, hump
        path.addCurve(to: p(25, 6), control1: p(12, 54), control2: p(21, 20))
        path.addCurve(to: p(17, 63), control1: p(29, -4), control2: p(17, 18))
        path.addCurve(to: p(33, 40), control1: p(19, 48), control2: p(25, 38))
        path.addCurve(to: p(39, 61), control1: p(41, 42), control2: p(37, 55))
        // e
        path.addCurve(to: p(58, 48), control1: p(42, 66), control2: p(52, 57))
        path.addCurve(to: p(52, 39), control1: p(63, 42), control2: p(58, 36))
        path.addCurve(to: p(56, 63), control1: p(43, 44), control2: p(46, 63))
        // first l
        path.addCurve(to: p(78, 6), control1: p(66, 62), control2: p(78, 28))
        path.addCurve(to: p(72, 63), control1: p(80, -3), control2: p(69, 26))
        // second l
        path.addCurve(to: p(96, 6), control1: p(78, 64), control2: p(95, 30))
        path.addCurve(to: p(90, 63), control1: p(98, -3), control2: p(87, 26))
        // o
        path.addCurve(to: p(110, 42), control1: p(94, 65), control2: p(102, 45))
        path.addCurve(to: p(106, 62), control1: p(101, 41), control2: p(98, 58))
        path.addCurve(to: p(120, 45), control1: p(114, 66), control2: p(122, 55))
        path.addCurve(to: p(110, 42), control1: p(119, 39), control2: p(113, 39))
        // exit flourish
        path.addCurve(to: p(137, 43), control1: p(117, 47), control2: p(128, 48))
        return path
    }
}

/// The hello written on screen with a travelling spectral glow.
struct HelloLettering: View {
    @State private var progress: CGFloat = Motion.isSnapshot ? 1 : 0
    @State private var glow: Double = Motion.isSnapshot ? 0.6 : 0

    var body: some View {
        let stroke = StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
        ZStack {
            HelloPath()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [Color(hex: 0x7DD3FC), Color(hex: 0xA78BFA), Color(hex: 0xF472B6), Color(hex: 0xFBBF24), Color(hex: 0x7DD3FC)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 7)
                .opacity(glow)
            HelloPath()
                .trim(from: 0, to: progress)
                .stroke(Color.white, style: stroke)
                .shadow(color: .white.opacity(0.6), radius: 3)
        }
        .aspectRatio(2, contentMode: .fit)
        .onAppear {
            if Motion.reduceMotion {
                progress = 1
                glow = 0.5
                return
            }
            withAnimation(.timingCurve(0.45, 0.05, 0.25, 1, duration: 1.7)) { progress = 1 }
            withAnimation(.easeOut(duration: 0.6)) { glow = 0.9 }
            withAnimation(.easeInOut(duration: 1.2).delay(1.6)) { glow = 0.35 }
        }
        .accessibilityLabel("hello")
    }
}
