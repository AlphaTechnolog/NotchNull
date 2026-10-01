import SwiftUI

/// Every long-lived service, created once and shared by all notch windows and Settings.
@MainActor
final class AppServices {
    let preferences = Preferences.shared
    let activities = ActivityCenter.shared
    let nowPlaying = NowPlayingService()
    let levels = LevelsService()
    let agents = AgentHub()
    let battery = BatteryService()
    let stats = SystemStatsService()
    let keepAwake = KeepAwakeService()
    let timer = TimerService()
    let accessories = AccessoryService()
    let calendar = CalendarService()
    let tray = TrayStore()
    let clipboard = ClipboardService()
    let clipboardPicker = ClipboardPicker()
    let widgets = WidgetStore.shared
    let customActivities = CustomActivityStore.shared
    let settingsFile = SettingsFile.shared
    let downloads = DownloadWatcher()
    let cleanup = DownloadCleanup()
    let mirror = MirrorService()
    let hello = HelloService()
    let controls = ControlCenterService()
    let log = ActivityLog.shared
    let devices = DeviceEvents.shared
    let usbDevices = USBDeviceWatcher()
    let volumes = VolumeWatcher()
    let displays = DisplayWatcher()
    let fullscreen = FullscreenWatcher()
    let airDrop = AirDropWatcher()
    let updates = UpdateService.shared
    lazy var screenshots = ScreenshotWatcher(tray: tray)

    func start() {
        // ~/.notchnull first: settings.json may change how every other service starts.
        NotchHome.bootstrap()
        // Before settings.json is read and rewritten by a version that has never run here.
        NotchBackup.backupOnVersionChange()
        settingsFile.start()
        widgets.start()
        tray.start()
        nowPlaying.start()
        levels.start()
        agents.start()
        battery.onPowerSourceChange = { [levels] in levels.powerSourceChanged() }
        battery.start()
        accessories.start()
        usbDevices.start()
        volumes.start()
        displays.start()
        fullscreen.start()
        airDrop.start()
        calendar.start()
        clipboard.start()
        cleanup.start()
        downloads.onFinished = { [cleanup] url in cleanup.offer(url) }
        downloads.start()
        screenshots.start()
        hello.start()
        controls.start()
        stats.prime()
        updates.start()
        Log.app.info("Services started")
    }
}

extension View {
    func withServices(_ services: AppServices) -> some View {
        environmentObject(services.preferences)
            .environmentObject(services.activities)
            .environmentObject(services.nowPlaying)
            .environmentObject(services.levels)
            .environmentObject(services.agents)
            .environmentObject(services.agents.sessions)
            .environmentObject(services.agents.claudeUsage)
            .environmentObject(services.agents.claudeTokens)
            .environmentObject(services.agents.codex)
            .environmentObject(services.agents.plans)
            .environmentObject(services.battery)
            .environmentObject(services.stats)
            .environmentObject(services.keepAwake)
            .environmentObject(services.timer)
            .environmentObject(services.accessories)
            .environmentObject(services.calendar)
            .environmentObject(services.tray)
            .environmentObject(services.clipboard)
            .environmentObject(services.clipboardPicker)
            .environmentObject(services.widgets)
            .environmentObject(services.customActivities)
            .environmentObject(services.settingsFile)
            .environmentObject(services.downloads)
            .environmentObject(services.cleanup)
            .environmentObject(services.mirror)
            .environmentObject(services.screenshots)
            .environmentObject(services.controls)
            .environmentObject(services.log)
            .environmentObject(services.devices)
            .environmentObject(services.updates)
    }
}
