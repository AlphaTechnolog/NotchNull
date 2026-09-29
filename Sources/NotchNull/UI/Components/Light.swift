import SwiftUI

/// A light that travels around the notch outline: the "needs you" signal.
struct ChasingOutline: View {
    var tint: Color
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    var active: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !active || Motion.reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let angle = Angle.degrees((time * 140).truncatingRemainder(dividingBy: 360))
            let gradient = AngularGradient(
                stops: [
                    .init(color: tint.opacity(0), location: 0),
                    .init(color: tint.opacity(0), location: 0.55),
                    .init(color: tint.opacity(0.9), location: 0.8),
                    .init(color: .white, location: 0.86),
                    .init(color: tint.opacity(0.9), location: 0.9),
                    .init(color: tint.opacity(0), location: 1),
                ],
                center: .center,
                angle: angle
            )
            let breathing = 0.55 + 0.45 * (0.5 + 0.5 * sin(time * 3))
            ZStack {
                NotchShape(topRadius: topRadius, bottomRadius: bottomRadius, edgeOnly: true)
                    .stroke(tint.opacity(Motion.reduceMotion ? 0.8 : 0.35 * breathing), lineWidth: 1.2)
                if !Motion.reduceMotion {
                    NotchShape(topRadius: topRadius, bottomRadius: bottomRadius, edgeOnly: true)
                        .stroke(gradient, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    NotchShape(topRadius: topRadius, bottomRadius: bottomRadius, edgeOnly: true)
                        .stroke(gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .blur(radius: 6)
                        .opacity(0.8)
                }
            }
        }
        .opacity(active ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: active)
        .allowsHitTesting(false)
    }
}

/// Soft light along the lower edge of the body, tinted by whatever owns the notch.
struct EmissionEdge: View {
    var tint: Color
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    var intensity: Double

    /// Room around the body so the glow can fade out instead of being clipped at the frame edge.
    private let bleed: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                NotchShape(topRadius: topRadius, bottomRadius: bottomRadius, edgeOnly: true)
                    .stroke(
                        LinearGradient(
                            colors: [tint.opacity(0), tint.opacity(0.85), tint.opacity(0)],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
                NotchShape(topRadius: topRadius, bottomRadius: bottomRadius, edgeOnly: true)
                    .stroke(
                        LinearGradient(
                            colors: [tint.opacity(0), tint.opacity(0.45), tint.opacity(0)],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        lineWidth: 6
                    )
                    .blur(radius: 9)
            }
            .frame(width: size.width, height: size.height)
            .padding(bleed)
            // Fade the sides in from the top so the light gathers along the bottom curve.
            .mask(
                LinearGradient(
                    stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.55), .init(color: .black, location: 1)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .padding(-bleed)
        }
        .opacity(intensity * Double(UserDefaults.standard.object(forKey: Preferences.Keys.emissionIntensity) as? Double ?? 0.7))
        .allowsHitTesting(false)
    }
}

/// Claude's working mark: a sunburst whose rays breathe in sequence.
struct SunburstMark: View {
    var tint: Color = Theme.Accent.claude
    var animating: Bool
    var size: CGFloat = 14

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !animating || Motion.reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let rays = 10
                for index in 0..<rays {
                    let path = ray(index: index, of: rays, time: time, center: center)
                    canvas.stroke(path, with: .color(tint), style: StrokeStyle(lineWidth: size * 0.11, lineCap: .round))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func ray(index: Int, of count: Int, time: TimeInterval, center: CGPoint) -> Path {
        let spin: Double = animating ? time * 0.6 : 0
        let angle: Double = Double(index) / Double(count) * 2 * Double.pi + spin
        let breathing: Double = animating && !Motion.reduceMotion ? 0.5 + 0.5 * sin(time * 5 - Double(index) * 0.7) : 1
        let inner: CGFloat = size * 0.12
        let outer: CGFloat = size * CGFloat(0.32 + 0.18 * breathing)
        let dx = CGFloat(cos(angle)), dy = CGFloat(sin(angle))
        var path = Path()
        path.move(to: CGPoint(x: center.x + dx * inner, y: center.y + dy * inner))
        path.addLine(to: CGPoint(x: center.x + dx * outer, y: center.y + dy * outer))
        return path
    }
}

/// Codex's working mark: an orbit of dots.
struct OrbitMark: View {
    var tint: Color = Theme.Accent.codex
    var animating: Bool
    var size: CGFloat = 14

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !animating || Motion.reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let dots = 6
                for index in 0..<dots {
                    let fade: Double = animating ? 0.35 + 0.65 * Double(index) / Double(dots - 1) : 0.9
                    canvas.fill(Path(ellipseIn: dotRect(index: index, of: dots, time: time, center: center)), with: .color(tint.opacity(fade)))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func dotRect(index: Int, of count: Int, time: TimeInterval, center: CGPoint) -> CGRect {
        let spin: Double = animating ? time * 2.4 : 0
        let angle: Double = Double(index) / Double(count) * 2 * Double.pi + spin
        let radius: CGFloat = size * 0.34
        let dot: CGFloat = size * 0.16
        return CGRect(
            x: center.x + CGFloat(cos(angle)) * radius - dot / 2,
            y: center.y + CGFloat(sin(angle)) * radius - dot / 2,
            width: dot, height: dot
        )
    }
}

/// The provider's official logo. While a session works it turns and breathes; idle it is still.
struct ProviderMark: View {
    let provider: AgentProvider
    var animating = false
    var size: CGFloat = 14

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !animating || Motion.reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let live = animating && !Motion.reduceMotion
            let turns = provider == .claude ? 0.33 : 0.42
            let angle = live ? (time * turns * 360).truncatingRemainder(dividingBy: 360) : 0
            let breath = live ? 0.9 + 0.1 * sin(time * 4) : 1
            SVGShape(path: provider == .claude ? BrandMarks.claude : BrandMarks.openAI)
                .fill(provider.markColor)
                .frame(width: size, height: size)
                .rotationEffect(.degrees(angle))
                .scaleEffect(breath)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(provider.title)
    }
}

extension AgentProvider {
    var tint: Color { self == .claude ? Theme.Accent.claude : Theme.Accent.codex }
    /// Claude's mark is shown in its brand orange, OpenAI's in white, as each brand presents them.
    var markColor: Color { self == .claude ? Theme.Accent.claude : .white }
}
