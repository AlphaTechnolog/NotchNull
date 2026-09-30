import SwiftUI

/// What the idle island shows: clock, date or battery, per preferences.
struct PillFace: View {
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var battery: BatteryService
    @EnvironmentObject private var model: NotchViewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 10)) { context in
            HStack(spacing: 6) {
                switch preferences.pillContent {
                case .clock:
                    clock(context.date)
                case .dateClock:
                    dateLabel(context.date)
                    clock(context.date)
                case .battery:
                    batteryFace
                case .clockBattery:
                    clock(context.date)
                    batteryFace
                case .nothing:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .scaleEffect(min(1.4, max(0.6, model.rowHeight / 28)))
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    private func dateLabel(_ date: Date) -> some View {
        Text(date.formatted(.dateTime.weekday(.abbreviated).day()))
            .font(Theme.Typeface.label)
            .foregroundStyle(Theme.Palette.textSecondary)
    }

    private func clock(_ date: Date) -> some View {
        let text = IslandClock.string(date, use24Hour: preferences.use24Hour)
        return Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(Theme.Palette.textPrimary)
            .contentTransition(.numericText(countsDown: false))
            .animation(Motion.value, value: text)
    }

    private var batteryFace: some View {
        HStack(spacing: 4) {
            if battery.state.isPluggedIn {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.Accent.battery)
            }
            Text("\(battery.state.percent)%")
                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.Palette.textPrimary)
                .contentTransition(.numericText(value: Double(battery.state.percent)))
        }
    }
}

enum IslandClock {
    static func string(_ date: Date, use24Hour: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = use24Hour ? "HH:mm" : "h:mm"
        return formatter.string(from: date)
    }
}

/// A small circle beside the island that grows into its own card while hovered (or clicked):
/// the leading one into what is playing, the trailing one into the control center. One body
/// whose frame and corner radius spring between the two, like the island itself.
struct IslandSatellite: View {
    let side: NotchViewModel.SatelliteSide
    let frame: CGRect
    @EnvironmentObject private var model: NotchViewModel
    @EnvironmentObject private var preferences: Preferences

    private var expanded: Bool { model.expandedSatellite == side }

    var body: some View {
        let radius = model.satelliteRadius(for: frame)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack(alignment: .top) {
            BodyFill(shape: AnyShape(shape), expanded: expanded)
            shape.stroke(Color.white.opacity(0.08), lineWidth: 1)
            ZStack {
                if expanded {
                    card.transition(.notchContent)
                } else {
                    SatelliteFace(side: side, size: frame.height)
                        .transition(.notchContent)
                }
            }
            .frame(width: frame.width, height: frame.height)
            .clipShape(shape)
        }
        .frame(width: frame.width, height: frame.height)
        .contentShape(shape)
        .onTapGesture { if !expanded { model.toggleSatellite(side) } }
        .offset(x: frame.minX, y: frame.minY)
        // Always settle on the current frame, whichever transaction moved it.
        .animation(Motion.open, value: frame)
        .transition(.scale(scale: 0.4).combined(with: .opacity))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(side == .leading ? "Media" : "Controls")
        .accessibilityAddTraits(expanded ? [] : .isButton)
    }

    @ViewBuilder
    private var card: some View {
        switch side {
        case .leading: MediaCard()
        case .trailing:
            IslandControlsCard()
                .padding(10)
        }
    }
}

/// The collapsed satellite: always music on the left (artwork, or a note), Wi-Fi on the right.
private struct SatelliteFace: View {
    let side: NotchViewModel.SatelliteSide
    let size: CGFloat
    @EnvironmentObject private var model: NotchViewModel
    @EnvironmentObject private var nowPlaying: NowPlayingService
    @EnvironmentObject private var controls: ControlCenterService

    var body: some View {
        let inner = size - 6
        Group {
            switch side {
            case .leading:
                if nowPlaying.nowPlaying != nil {
                    ArtworkView(image: nowPlaying.artwork, size: inner, cornerRadius: inner / 2, tint: nowPlaying.tint)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: inner * 0.45, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            case .trailing:
                Image(systemName: controls.wifiOn ? "wifi" : "switch.2")
                    .font(.system(size: inner * 0.42, weight: .bold))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Media card grown from the left satellite: blurred artwork behind, big controls in front.
struct MediaCard: View {
    @EnvironmentObject private var nowPlaying: NowPlayingService

    var body: some View {
        ZStack {
            // In an overlay so the oversized, blurred artwork never sizes the card.
            Color.clear
                .overlay {
                    if let image = nowPlaying.artwork {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 28)
                            .scaleEffect(1.4)
                            .opacity(0.55)
                    }
                }
                .clipped()
            LinearGradient(colors: [nowPlaying.tint.opacity(0.18), .black.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let track = nowPlaying.nowPlaying {
                HStack(alignment: .top, spacing: 14) {
                    ArtworkView(image: nowPlaying.artwork, size: 118, cornerRadius: 14, tint: nowPlaying.tint)
                        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                        .onTapGesture { nowPlaying.openPlayer() }
                        .condense(delay: Motion.stagger(1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(Theme.Typeface.body)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .lineLimit(1)
                        Text([track.album, track.sourceName].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(Theme.Typeface.caption)
                            .foregroundStyle(Theme.Palette.textTertiary)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Scrubber(track: track, tint: nowPlaying.tint) { nowPlaying.seek(to: $0) }
                        HStack(spacing: 14) {
                            Spacer()
                            IconButton(symbol: "backward.end.fill", size: 11, label: "Previous track") { nowPlaying.previous() }
                            Button { nowPlaying.togglePlayPause() } label: {
                                Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                                    .contentTransition(.symbolEffect(.replace.downUp))
                                    .frame(width: 38, height: 38)
                                    .background(Circle().fill(Color.white.opacity(0.14)))
                            }
                            .buttonStyle(PressableStyle(hoverFill: .clear, cornerRadius: 19, padding: EdgeInsets()))
                            .accessibilityLabel(track.isPlaying ? "Pause" : "Play")
                            IconButton(symbol: "forward.end.fill", size: 11, label: "Next track") { nowPlaying.next() }
                            Spacer()
                        }
                    }
                    .frame(height: 118)
                    .condense(delay: Motion.stagger(2))
                }
                .padding(14)
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textTertiary)
                    Text(nowPlaying.automationDenied ? "Allow NotchNull to control Music and Spotify" : "Nothing playing")
                        .font(Theme.Typeface.bodyStrong)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    if nowPlaying.automationDenied {
                        Chip(title: "Open Settings", tint: Theme.Accent.warning) { Permissions.open(.automation) }
                    }
                }
                .condense(delay: Motion.stagger(1))
            }
        }
        .clipped()
    }
}
