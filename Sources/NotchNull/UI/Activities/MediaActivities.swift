import SwiftUI

struct MusicActivity: View {
    @EnvironmentObject private var nowPlaying: NowPlayingService
    @Environment(\.wingContext) private var context

    var body: some View {
        WingsLayout {
            ArtworkView(image: nowPlaying.artwork, size: context.rowHeight - 12, cornerRadius: 6, tint: nowPlaying.tint)
        } trailing: {
            AudioBars(isPlaying: nowPlaying.nowPlaying?.isPlaying ?? false, tint: nowPlaying.tint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Now playing \(nowPlaying.nowPlaying?.title ?? "")")
    }
}

struct LevelActivity: View {
    @EnvironmentObject private var levels: LevelsService

    var body: some View {
        let level = levels.level
        let isVolume = level.kind == .volume
        let tint = isVolume ? Color.white : Theme.Accent.brightness
        // Compact HUD: icon and a short bar on the left wing, the value on the right. The body keeps
        // the closed height and a fixed width, so each key press only moves the fill, never the notch.
        WingsLayout {
            HStack(spacing: 6) {
                Image(systemName: symbol(for: level), variableValue: Double(level.value))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 20)
                LevelBar(value: level.muted ? 0 : Double(level.value), tint: tint)
                    .frame(width: 70, height: 5)
            }
        } trailing: {
            Text(level.muted ? "Mute" : "\(Int((level.value * 100).rounded()))%")
                .font(Theme.Typeface.wing.monospacedDigit())
                .foregroundStyle(Theme.Palette.textPrimary)
                .contentTransition(.numericText(value: Double(level.value)))
                .frame(width: 42, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isVolume ? "Volume" : "Brightness")
        .accessibilityValue(level.muted ? "Muted" : "\(Int(level.value * 100)) percent")
    }

    private func symbol(for level: LevelsService.Level) -> String {
        switch level.kind {
        case .volume: level.muted || level.value == 0 ? "speaker.slash.fill" : "speaker.wave.3.fill"
        case .brightness: "sun.max.fill"
        }
    }
}

/// Thin level bar; one shape animates, so rapid key repeats stay smooth.
private struct LevelBar: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Theme.Palette.track
                tint.frame(width: proxy.size.width * CGFloat(max(0, min(1, value))))
            }
            .clipShape(Capsule())
        }
        .animation(.interpolatingSpring(stiffness: 420, damping: 36), value: value)
    }
}

struct HelloActivity: View {
    var body: some View {
        WingsLayout {
            EmptyView()
        } trailing: {
            EmptyView()
        } bottom: {
            HelloLettering()
                .frame(height: 58)
                .padding(.bottom, 12)
        }
    }
}
