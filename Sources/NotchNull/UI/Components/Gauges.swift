import AppKit
import SwiftUI

/// Circular progress with a rounded arc that draws in from zero on appear.
struct RingGauge: View {
    var progress: Double
    var tint: Color
    var lineWidth: CGFloat = 3
    var track: Color = Theme.Palette.track
    @State private var drawn = Motion.isSnapshot

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: drawn ? max(0.001, min(1, progress)) : 0)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Motion.value, value: progress)
        }
        .onAppear {
            withAnimation(Motion.reduceMotion ? nil : .timingCurve(0.16, 1, 0.3, 1, duration: 0.8)) { drawn = true }
        }
    }
}

/// Horizontal usage bar with an optional pace marker showing how much of the window has elapsed.
struct UsageBar: View {
    var percent: Double
    var tint: Color
    var paceFraction: Double?
    var height: CGFloat = 6
    @State private var drawn = Motion.isSnapshot

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fill = width * CGFloat(max(0, min(100, drawn ? percent : 0)) / 100)
            ZStack(alignment: .leading) {
                Theme.Palette.track
                // The fill is clipped by the track, so it ends in a straight edge instead of a second pill.
                LinearGradient(colors: [tint.opacity(0.75), tint], startPoint: .leading, endPoint: .trailing)
                    .frame(width: fill)
                if let paceFraction {
                    // A notch cut through the bar marks the even pace.
                    Rectangle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 1.5)
                        .offset(x: max(0, min(width - 1.5, width * CGFloat(paceFraction) - 0.75)))
                        .accessibilityHidden(true)
                }
            }
            .clipShape(Capsule())
            .frame(height: height)
            .frame(maxHeight: .infinity)
        }
        .frame(height: height + 2)
        .animation(Motion.value, value: percent)
        .onAppear {
            withAnimation(Motion.reduceMotion ? nil : .timingCurve(0.16, 1, 0.3, 1, duration: 0.7)) { drawn = true }
        }
    }
}

/// Minimal bar chart for hourly token use.
struct HourlyBars: View {
    var values: [Int]
    var tint: Color
    var highlight: Int?

    var body: some View {
        GeometryReader { proxy in
            let maxValue = max(1, values.max() ?? 1)
            let spacing: CGFloat = 2
            let width = max(1, (proxy.size.width - spacing * CGFloat(values.count - 1)) / CGFloat(max(1, values.count)))
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(values.indices, id: \.self) { index in
                    let fraction = CGFloat(values[index]) / CGFloat(maxValue)
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(index == highlight ? tint : tint.opacity(values[index] == 0 ? 0.18 : 0.55))
                        .frame(width: width, height: max(2, proxy.size.height * fraction))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .animation(Motion.value, value: values)
        }
    }
}

/// Filled sparkline for system history.
struct Sparkline: View {
    var values: [Double]
    var tint: Color
    var maxValue: Double? = nil

    var body: some View {
        GeometryReader { proxy in
            let top = maxValue ?? max(values.max() ?? 1, 0.0001)
            let points = values.enumerated().map { index, value in
                CGPoint(
                    x: values.count > 1 ? proxy.size.width * CGFloat(index) / CGFloat(values.count - 1) : 0,
                    y: proxy.size.height * (1 - CGFloat(min(1, value / top)))
                )
            }
            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: CGPoint(x: first.x, y: proxy.size.height))
                    points.forEach { path.addLine(to: $0) }
                    path.addLine(to: CGPoint(x: points.last?.x ?? 0, y: proxy.size.height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [tint.opacity(0.35), tint.opacity(0)], startPoint: .top, endPoint: .bottom))
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    points.dropFirst().forEach { path.addLine(to: $0) }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            }
        }
        .animation(Motion.value, value: values)
    }
}
