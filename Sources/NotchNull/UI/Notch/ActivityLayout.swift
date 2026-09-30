import CoreGraphics

/// How much room an activity takes when it slides out of the closed notch.
struct ActivityLayout {
    /// Width of each wing beside the hardware notch.
    var wing: CGFloat
    /// Extra height below the notch for a second row.
    var extraHeight: CGFloat = 0
    /// Minimum overall body width (banners are wider than notch + wings).
    var minWidth: CGFloat = 0
    /// Interactive activities have their own buttons, so hovering them must not open the panel.
    var interactive = false
    /// Fixed body width in island mode, for activities whose content spans the whole row instead
    /// of sitting in two wings.
    var islandWidth: CGFloat?
}

extension ActivityKind {
    var layout: ActivityLayout {
        switch self {
        case .hello: ActivityLayout(wing: 40, extraHeight: 74, minWidth: 330)
        case .needsYou: ActivityLayout(wing: 40, extraHeight: MainActor.assumeIsolated { AttentionQueue.extraHeight(for: AttentionQueue.shared.count) }, minWidth: 480, interactive: true)
        case .volume, .brightness: ActivityLayout(wing: 116, islandWidth: 196)
        case .timerFinished: ActivityLayout(wing: 96)
        case .usageWarning: ActivityLayout(wing: 40, extraHeight: 50, minWidth: 440, interactive: true)
        case .custom: MainActor.assumeIsolated { CustomActivityStore.shared.layout }
        case .agentDone: ActivityLayout(wing: 40, extraHeight: 66, minWidth: 480, interactive: true)
        case .downloadKeep: ActivityLayout(wing: 40, extraHeight: 112, minWidth: 500, interactive: true)
        case .downloadDone: ActivityLayout(wing: 40, extraHeight: 46, minWidth: 400, interactive: true)
        case .downloadTrashed: ActivityLayout(wing: 40, extraHeight: 46, minWidth: 420, interactive: true)
        case .downloadExpiring: ActivityLayout(wing: 70)
        case .charging, .lowBattery: ActivityLayout(wing: 76)
        case .accessory: ActivityLayout(wing: Theme.Size.wideWingWidth)
        case .screenshot: ActivityLayout(wing: 40, extraHeight: 66, minWidth: 400, interactive: true)
        case .trayAdded: ActivityLayout(wing: 52)
        case .meetingSoon: ActivityLayout(wing: 40, extraHeight: 46, minWidth: 430, interactive: true)
        case .download: ActivityLayout(wing: 76, extraHeight: 10)
        case .timer: ActivityLayout(wing: 70)
        case .agentRunning: ActivityLayout(wing: 66)
        case .music: ActivityLayout(wing: 42)
        }
    }
}
