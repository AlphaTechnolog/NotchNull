import SwiftUI

/// A light that travels around the notch outline: the "needs you" signal.
struct ChasingOutline: View {
    var tint: Color
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    /// The island's top corners; the light then runs all the way around.
    var capRadius: CGFloat = 0
    var active: Bool

    private var outline: NotchShape {
        NotchShape(topRadius: topRadius, bottomRadius: bottomRadius, capRadius: capRadius, edgeOnly: capRadius == 0)
    }

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
                outline
                    .stroke(tint.opacity(Motion.reduceMotion ? 0.8 : 0.35 * breathing), lineWidth: 1.2)
                if !Motion.reduceMotion {
                    outline
                        .stroke(gradient, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    outline
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
    var capRadius: CGFloat = 0
    var intensity: Double

    private var edge: NotchShape {
        NotchShape(topRadius: topRadius, bottomRadius: bottomRadius, capRadius: capRadius, edgeOnly: true)
    }

    /// Room around the body so the glow can fade out instead of being clipped at the frame edge.
    private let bleed: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                edge
                    .stroke(
                        LinearGradient(
                            colors: [tint.opacity(0), tint.opacity(0.85), tint.opacity(0)],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
                edge
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

/// The provider's official logo. Still by default; while a session works it can spin, pulse or
/// shimmer, as chosen in Settings › Agents (`motion.agentMark`).
struct ProviderMark: View {
    let provider: AgentProvider
    var animating = false
    var size: CGFloat = 14
    @ObservedObject private var preferences = Preferences.shared

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !animating || !Self.moves)) { context in
            Self.glyph(provider, size: size, pose: Self.pose(of: provider, at: context.date, live: animating))
                .foregroundStyle(provider.markColor)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(provider.title)
    }

    struct Pose {
        var angle: Double = 0
        var scale: Double = 1
        /// Position of a light band sweeping across the logo, 0…1; nil for no sweep.
        var shimmer: Double?

        static let still = Pose()
    }

    /// Whether a live mark moves at all, so still marks never run a per-frame timeline.
    static var moves: Bool { Preferences.shared.agentMarkMotion != .still && !Motion.reduceMotion }

    /// The mark at `date` for the motion chosen in Settings (still by default): a slow turn at
    /// each provider's own speed, a gentle size pulse, or a light sweeping across it.
    static func pose(of provider: AgentProvider, at date: Date, live: Bool) -> Pose {
        guard live, moves else { return .still }
        let time = date.timeIntervalSinceReferenceDate
        switch Preferences.shared.agentMarkMotion {
        case .still:
            return .still
        case .spin:
            let turns = provider == .claude ? 0.33 : 0.42
            return Pose(angle: (time * turns * 360).truncatingRemainder(dividingBy: 360))
        case .pulse:
            return Pose(scale: 0.9 + 0.1 * sin(time * 4))
        case .shimmer:
            return Pose(shimmer: (time / 1.6).truncatingRemainder(dividingBy: 1))
        }
    }

    /// The logo filled with the foreground style; `outline` widens it so it can punch a gap.
    /// opencode's two-layer window mark cannot go through the single-fill path,
    /// so it branches here (the stack gap-punch falls back to its silhouette).
    static func glyph(_ provider: AgentProvider, size: CGFloat, pose: Pose, outline: CGFloat = 0) -> some View {
        ZStack {
            if provider == .opencode {
                OpencodeMark()
            } else {
                let shape = SVGShape(path: provider == .claude ? BrandMarks.claude : BrandMarks.openAI)
                shape.fill()
                if outline > 0 { shape.stroke(lineWidth: outline * 2) }
            }
        }
        .frame(width: size, height: size)
        .overlay {
            // The sweep only lights the logo itself; a gap-punching outline copy stays plain.
            if let phase = pose.shimmer, outline == 0 {
                ZStack {
                    LinearGradient(colors: [.clear, .white.opacity(0.85), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: size * 0.6)
                        .offset(x: size * (CGFloat(phase) * 2 - 1))
                }
                .frame(width: size, height: size)
                .mask(glyphMask(provider).frame(width: size, height: size))
                .blendMode(.plusLighter)
            }
        }
        .rotationEffect(.degrees(pose.angle))
        .scaleEffect(pose.scale)
    }

    private static func glyphMask(_ provider: AgentProvider) -> some View {
        Group {
            if provider == .opencode {
                OpencodeMark()
            } else {
                SVGShape(path: provider == .claude ? BrandMarks.claude : BrandMarks.openAI).fill()
            }
        }
    }
}

/// opencode's window mark: a solid block with a cutout window plus a
/// 45%-opacity lower half (see `BrandMarks.opencodeBase/opencodeShade`).
/// The cutout needs even-odd fill, and the color comes from the surrounding
/// foreground style like the single-fill marks above.
struct OpencodeMark: View {
    var body: some View {
        ZStack {
            SVGShape(path: BrandMarks.opencodeBase)
                .fill(style: FillStyle(eoFill: true))
            SVGShape(path: BrandMarks.opencodeShade)
                .fill()
                .opacity(0.45)
        }
    }
}

/// Marks of every provider that is running, overlapped like an avatar stack: each later mark
/// sits on top and cuts a gap the shape of its own silhouette out of the one behind, so both
/// logos stay readable on any body material.
struct ProviderStack: View {
    let providers: [AgentProvider]
    var animating = false
    var size: CGFloat = 16
    @ObservedObject private var preferences = Preferences.shared

    /// Horizontal step between marks as a fraction of their size (0.7 overlaps by under a third).
    private static let step: CGFloat = 0.7
    /// Clear gap around a front mark, in points.
    private static let gap: CGFloat = 1.5

    var body: some View {
        let offset = size * Self.step
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !animating || !ProviderMark.moves)) { context in
            ZStack(alignment: .leading) {
                ForEach(Array(providers.enumerated()), id: \.element) { index, provider in
                    ZStack {
                        ProviderMark.glyph(provider, size: size, pose: ProviderMark.pose(of: provider, at: context.date, live: animating))
                            .foregroundStyle(provider.markColor)
                        if index + 1 < providers.count {
                            let front = providers[index + 1]
                            ProviderMark.glyph(front, size: size, pose: ProviderMark.pose(of: front, at: context.date, live: animating), outline: Self.gap)
                                .offset(x: offset)
                                .blendMode(.destinationOut)
                        }
                    }
                    .frame(width: size, height: size)
                    .compositingGroup()
                    .offset(x: CGFloat(index) * offset)
                }
            }
        }
        .frame(width: size + CGFloat(max(providers.count - 1, 0)) * offset, height: size, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(providers.map(\.title).joined(separator: " and "))
    }
}

extension AgentProvider {
    var tint: Color {
        switch self {
        case .claude: Theme.Accent.claude
        case .codex: Theme.Accent.codex
        case .opencode: Theme.Accent.opencode
        }
    }
    /// Claude's mark is shown in its brand orange, OpenAI's in white, as each brand presents them.
    var markColor: Color {
        switch self {
        case .claude: Theme.Accent.claude
        case .codex: .white
        case .opencode: Theme.Accent.opencode
        }
    }
}
