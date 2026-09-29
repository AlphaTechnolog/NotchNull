import SwiftUI

/// Beat-like bars beside the notch while music plays. Driven by layered sines so the rhythm
/// never visibly loops; settles to a flat line when paused.
struct AudioBars: View {
    var isPlaying: Bool
    var tint: Color
    var barCount = 4
    var barWidth: CGFloat = 2.6
    var spacing: CGFloat = 2.2
    var height: CGFloat = 14

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isPlaying || Motion.reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(tint)
                        .frame(width: barWidth, height: max(barWidth, height * level(index, time)))
                }
            }
            .frame(height: height)
            .animation(.easeOut(duration: 0.12), value: isPlaying)
        }
        .accessibilityHidden(true)
    }

    private func level(_ index: Int, _ time: TimeInterval) -> CGFloat {
        guard isPlaying, !Motion.reduceMotion else { return isPlaying ? 0.55 : 0.18 }
        let i = Double(index)
        let a = sin(time * (5.1 + i * 1.3) + i * 1.7)
        let b = sin(time * (8.3 - i * 0.9) + i * 0.6)
        let c = sin(time * 2.2 + i)
        let value = 0.5 + 0.28 * a + 0.16 * b + 0.08 * c
        return CGFloat(max(0.2, min(1, value)))
    }
}
