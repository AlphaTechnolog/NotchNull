import SwiftUI

/// Home: the player on the left, the user's chosen quick rows on the right. Sized for the compact
/// default panel; extra room (a taller or wider panel) reveals the volume slider and larger art.
struct HomeTab: View {
    @EnvironmentObject private var preferences: Preferences

    var body: some View {
        let contentWidth = preferences.panelWidth - 2 * Theme.Radius.panelPadding
        HStack(spacing: 8) {
            if preferences.musicEnabled {
                NowPlayingCard()
                    .frame(width: min(300, max(190, contentWidth * 0.44)))
                    .condense(delay: Motion.stagger(1))
            }
            QuickRowsCard()
                .condense(delay: Motion.stagger(2))
        }
    }
}

struct NowPlayingCard: View {
    @EnvironmentObject private var nowPlaying: NowPlayingService
    @EnvironmentObject private var levels: LevelsService
    @EnvironmentObject private var preferences: Preferences

    /// Taller panels get bigger art and a roomier scrubber.
    private var roomy: Bool { preferences.panelHeight >= 176 }

    var body: some View {
        Card(padding: 8) {
            if let track = nowPlaying.nowPlaying {
                playing(track)
            } else {
                empty
            }
        }
    }

    private func playing(_ track: NowPlaying) -> some View {
        let art: CGFloat = roomy ? 72 : 60
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 9) {
                ArtworkView(image: nowPlaying.artwork, size: art, cornerRadius: roomy ? 10 : 8, tint: nowPlaying.tint)
                    .onTapGesture { nowPlaying.openPlayer() }
                    .help("Open \(track.sourceName)")
                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title)
                        .font(Theme.Typeface.bodyStrong)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                    Text(track.artist.isEmpty ? track.sourceName : track.artist)
                        .font(Theme.Typeface.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                    HStack(spacing: 0) {
                        IconButton(symbol: "backward.fill", size: 10, label: "Previous track") { nowPlaying.previous() }
                        IconButton(symbol: track.isPlaying ? "pause.fill" : "play.fill", size: 13, label: track.isPlaying ? "Pause" : "Play") {
                            nowPlaying.togglePlayPause()
                        }
                        IconButton(symbol: "forward.fill", size: 10, label: "Next track") { nowPlaying.next() }
                        Spacer(minLength: 2)
                        AudioBars(isPlaying: track.isPlaying, tint: nowPlaying.tint, barCount: 4, barWidth: 2.2, spacing: 1.8, height: 10)
                            .padding(.trailing, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            Scrubber(track: track, tint: nowPlaying.tint, compact: !roomy) { nowPlaying.seek(to: $0) }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                LevelSlider(value: Double(levels.outputVolume), tint: nowPlaying.tint, label: "Output volume") {
                    levels.setVolume(Float($0))
                }
                Text(track.sourceName)
                    .lineLimit(1)
                    .font(Theme.Typeface.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .padding(.horizontal, 7)
                    .frame(height: 18)
                    .background(Capsule().fill(Theme.Palette.surfaceHover))
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            Image(systemName: "music.note")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Palette.textTertiary)
            Text("Nothing playing")
                .font(Theme.Typeface.bodyStrong)
                .foregroundStyle(Theme.Palette.textSecondary)
            HStack(spacing: 6) {
                Chip(title: "Music") { launch("com.apple.Music") }
                Chip(title: "Spotify") { launch("com.spotify.client") }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func launch(_ bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}

/// Track progress; hover to enlarge, click or drag to seek.
struct Scrubber: View {
    let track: NowPlaying
    let tint: Color
    var compact = false
    let onSeek: (Double) -> Void
    @State private var hovering = false
    @State private var dragFraction: Double?

    var body: some View {
        if track.duration > 0 {
            scrubber
        } else {
            LiveBadge(tint: tint)
        }
    }

    private var scrubber: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let elapsed = track.elapsed(at: context.date)
            let fraction = dragFraction ?? (track.duration > 0 ? elapsed / track.duration : 0)
            HStack(spacing: 6) {
                Text(Formatting.clock(dragFraction.map { $0 * track.duration } ?? elapsed))
                    .font(Theme.Typeface.caption.monospacedDigit())
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .frame(width: compact ? 28 : 34, alignment: .leading)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Palette.track)
                        Capsule().fill(hovering ? tint : Color.white.opacity(0.85))
                            .frame(width: max(4, proxy.size.width * fraction))
                    }
                    .frame(height: hovering ? 6 : 4)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in dragFraction = max(0, min(1, value.location.x / proxy.size.width)) }
                            .onEnded { _ in
                                if let dragFraction { onSeek(dragFraction) }
                                dragFraction = nil
                            }
                    )
                }
                .frame(height: 12)
                Text("-" + Formatting.clock(max(0, track.duration - elapsed)))
                    .font(Theme.Typeface.caption.monospacedDigit())
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .frame(width: compact ? 32 : 38, alignment: .trailing)
            }
            .animation(Motion.feedback, value: hovering)
        }
        .onHover { hovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback position")
    }
}

/// Stands in for the scrubber when the source has no duration (live streams, some web players).
private struct LiveBadge: View {
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Circle().fill(Theme.Accent.danger).frame(width: 5, height: 5).modifier(PulseDot())
                Text("LIVE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
            .padding(.horizontal, 6)
            .frame(height: 16)
            .background(Capsule().fill(Theme.Accent.danger.opacity(0.18)))
            Capsule()
                .fill(LinearGradient(colors: [tint.opacity(0.6), tint.opacity(0.15)], startPoint: .leading, endPoint: .trailing))
                .frame(height: 4)
        }
        .frame(height: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Live")
    }
}

/// The quick list: rows chosen in Settings → Tabs & Wings, in their order.
struct QuickRowsCard: View {
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var stats: SystemStatsService

    var body: some View {
        Card(padding: 7) {
            NotchScroll {
                // Rows share any extra height evenly, so a taller panel spaces them out instead of
                // leaving a gap at the bottom.
                VStack(spacing: 1) {
                    ForEach(Array(rows.enumerated()), id: \.element) { index, row in
                        view(for: row)
                            .frame(maxHeight: .infinity)
                            .condense(delay: Motion.stagger(index + 2))
                    }
                }
            }
        }
        .onAppear { stats.setActive(true) }
        .onDisappear { stats.setActive(false) }
    }

    private var rows: [Preferences.HomeRow] {
        preferences.visibleHomeRows.filter { row in
            switch row {
            case .upNext: preferences.calendarEnabled
            case .system, .network: preferences.statsEnabled
            default: true
            }
        }
    }

    @ViewBuilder
    private func view(for row: Preferences.HomeRow) -> some View {
        switch row {
        case .keepAwake: KeepAwakeRow()
        case .upNext: UpNextRow()
        case .timer: TimerRow()
        case .system: SystemRow()
        case .network: NetworkRow()
        }
    }
}

private struct KeepAwakeRow: View {
    @EnvironmentObject private var keepAwake: KeepAwakeService

    var body: some View {
        InfoRow(symbol: "cup.and.saucer.fill", tint: Theme.Accent.awake, title: "Keep Awake") {
            Button(keepAwake.isActive ? remainingLabel : keepAwake.duration.title) { keepAwake.cycleDuration() }
                .buttonStyle(PressableStyle(padding: EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)))
                .font(Theme.Typeface.caption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .lineLimit(1)
                .layoutPriority(-1)
            NotchToggle(
                isOn: Binding(get: { keepAwake.isActive }, set: { $0 ? keepAwake.start() : keepAwake.stop() }),
                tint: Theme.Accent.awake,
                label: "Keep Awake"
            )
        }
    }

    private var remainingLabel: String {
        guard let endsAt = keepAwake.endsAt else { return "On" }
        return Formatting.countdown(to: endsAt).replacingOccurrences(of: "in ", with: "")
    }
}

private struct UpNextRow: View {
    @EnvironmentObject private var calendar: CalendarService

    var body: some View {
        InfoRow(symbol: "video.fill", tint: Theme.Accent.calendar, title: "Up next") {
            switch calendar.access {
            case .fullAccess:
                if let event = calendar.next {
                    Text(event.title)
                        .font(Theme.Typeface.caption)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                        .layoutPriority(-1)
                    Text(event.isOngoing ? "now" : Formatting.countdown(to: event.start).replacingOccurrences(of: "in ", with: ""))
                        .font(Theme.Typeface.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .fixedSize()
                    if event.meetingURL != nil {
                        Chip(title: "Join", tint: Theme.Accent.success) { calendar.join(event) }
                    }
                } else {
                    Text("Free")
                        .font(Theme.Typeface.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            case .notDetermined:
                Chip(title: "Connect", tint: Theme.Accent.calendar) { calendar.requestAccess() }
            default:
                Chip(title: "Allow", tint: Theme.Accent.warning) { Permissions.open(.calendars) }
            }
        }
    }
}

private struct TimerRow: View {
    @EnvironmentObject private var timer: TimerService

    var body: some View {
        InfoRow(symbol: "timer", tint: Theme.Accent.timer, title: "Timer") {
            if timer.state == .idle {
                ForEach([5, 15, 25], id: \.self) { minutes in
                    Chip(title: "\(minutes)m", tint: Theme.Accent.timer) { timer.start(TimeInterval(minutes * 60)) }
                }
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(TimerService.format(timer.remaining(at: context.date)))
                        .font(Theme.Typeface.metric)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(Motion.value, value: Int(timer.remaining(at: context.date)))
                }
                IconButton(symbol: timer.isRunning ? "pause.fill" : "play.fill", size: 9, label: timer.isRunning ? "Pause timer" : "Resume timer") {
                    timer.togglePause()
                }
                IconButton(symbol: "xmark", size: 9, tint: Theme.Palette.textSecondary, label: "Stop timer") { timer.cancel() }
            }
        }
    }
}

/// CPU and memory side by side in one row.
private struct SystemRow: View {
    @EnvironmentObject private var stats: SystemStatsService

    var body: some View {
        InfoRow(symbol: "cpu", tint: Theme.Accent.codex, title: "Mac") {
            MiniMeter(label: "CPU", value: stats.snapshot.cpu, tint: Theme.Accent.codex)
            MiniMeter(label: "MEM", value: stats.snapshot.memoryFraction, tint: Theme.Accent.clipboard)
        }
    }
}

private struct NetworkRow: View {
    @EnvironmentObject private var stats: SystemStatsService

    var body: some View {
        InfoRow(symbol: "arrow.up.arrow.down", tint: Theme.Accent.airdrop, title: "Network") {
            Label(Formatting.rate(stats.snapshot.downloadRate), systemImage: "arrow.down")
                .labelStyle(CompactLabel())
            Label(Formatting.rate(stats.snapshot.uploadRate), systemImage: "arrow.up")
                .labelStyle(CompactLabel())
        }
    }
}

/// Label, tiny bar and percentage for the system row.
private struct MiniMeter: View {
    let label: String
    let value: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(Theme.Palette.textTertiary)
                .fixedSize()
            UsageBar(percent: value * 100, tint: tint, height: 4)
                .frame(minWidth: 12, maxWidth: 34)
            Text("\(Int((value * 100).rounded()))%")
                .font(Theme.Typeface.caption.monospacedDigit())
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: 26, alignment: .trailing)
                .contentTransition(.numericText(value: value))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(Int(value * 100)) percent")
    }
}

private struct CompactLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 2) {
            configuration.icon.font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.Palette.textTertiary)
            configuration.title.font(Theme.Typeface.caption.monospacedDigit()).foregroundStyle(Theme.Palette.textPrimary)
        }
        .lineLimit(1)
    }
}
