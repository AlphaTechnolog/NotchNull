import SwiftUI

/// Geometry the wing layouts adapt to: beside the hardware notch, or inside a floating island.
struct WingContext: Equatable {
    /// Empty space kept between the two wings (the camera housing in notch mode).
    var centerGap: CGFloat
    /// Height of the wing row.
    var rowHeight: CGFloat
    var horizontalPadding: CGFloat = 12
}

private struct WingContextKey: EnvironmentKey {
    static let defaultValue = WingContext(centerGap: 185, rowHeight: 32)
}

extension EnvironmentValues {
    var wingContext: WingContext {
        get { self[WingContextKey.self] }
        set { self[WingContextKey.self] = newValue }
    }
}

/// Wings on either side of the hardware notch, plus an optional row underneath. Each side's
/// natural width is measured and reported, so the notch grows only as much as the content needs.
struct WingsLayout<Leading: View, Trailing: View, Bottom: View>: View {
    @Environment(\.wingContext) private var context
    @Environment(\.activityKind) private var kind
    @EnvironmentObject private var model: NotchViewModel
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var bottom: Bottom

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                leading
                    .lineLimit(1)
                    .fixedSize()
                    .background(WingMeasure())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, context.horizontalPadding)
                    .condense(delay: Motion.stagger(1))
                Color.clear.frame(width: context.centerGap)
                trailing
                    .lineLimit(1)
                    .fixedSize()
                    .background(WingMeasure())
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, context.horizontalPadding)
                    .condense(delay: Motion.stagger(2))
            }
            .frame(height: context.rowHeight)
            .onPreferenceChange(WingWidthKey.self) { width in
                guard let kind else { return }
                MainActor.assumeIsolated { model.reportWingContent(width, for: kind) }
            }
            bottom
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .condense(delay: Motion.stagger(3))
        }
    }
}

private struct WingMeasure: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: WingWidthKey.self, value: proxy.size.width)
        }
    }
}

/// The wider of the two wing contents.
private struct WingWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct ActivityKindKey: EnvironmentKey {
    static let defaultValue: ActivityKind? = nil
}

extension EnvironmentValues {
    /// The activity a wing layout belongs to, so its measured width is attributed correctly.
    var activityKind: ActivityKind? {
        get { self[ActivityKindKey.self] }
        set { self[ActivityKindKey.self] = newValue }
    }
}

extension WingsLayout where Bottom == EmptyView {
    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
        self.bottom = EmptyView()
    }
}

/// Routes an activity kind to its wing content.
struct ActivityContentView: View {
    let kind: ActivityKind

    var body: some View {
        content.environment(\.activityKind, kind)
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .hello: HelloActivity()
        case .needsYou: NeedsYouActivity()
        case .volume, .brightness: LevelActivity()
        case .timerFinished: TimerFinishedActivity()
        case .usageWarning: UsageWarningActivity()
        case .agentDone: AgentDoneActivity()
        case .downloadDone: DownloadDoneActivity()
        case .charging: ChargingActivity()
        case .lowBattery: LowBatteryActivity()
        case .accessory: AccessoryActivity()
        case .screenshot: ScreenshotActivity()
        case .trayAdded: TrayAddedActivity()
        case .meetingSoon: MeetingSoonActivity()
        case .download: DownloadActivity()
        case .timer: TimerActivity()
        case .agentRunning: AgentRunningActivity()
        case .music: MusicActivity()
        }
    }
}

/// Two-line text block used by banner activities.
struct BannerText: View {
    let title: String
    let subtitle: String
    var subtitleColor: Color = Theme.Palette.textSecondary
    /// Banners that carry a message (agent summaries) wrap onto a second line instead of truncating.
    var subtitleLines = 1

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(Theme.Typeface.title)
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(1)
            Text(subtitle)
                .font(Theme.Typeface.body)
                .foregroundStyle(subtitleColor)
                .lineLimit(subtitleLines)
                .truncationMode(subtitleLines > 1 ? .tail : .middle)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
    }
}

/// Small rounded action used inside banners.
struct BannerButton: View {
    let title: String
    var symbol: String?
    var tint: Color = Theme.Palette.textPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .bold)) }
                Text(title).font(Theme.Typeface.label)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Theme.Palette.surfaceHover))
        }
        .buttonStyle(PressableStyle(cornerRadius: 12, padding: EdgeInsets()))
    }
}
