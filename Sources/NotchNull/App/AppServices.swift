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
    let downloads = DownloadWatcher()
    let mirror = MirrorService()
    let hello = HelloService()
    let controls = ControlCenterService()
    let log = ActivityLog.shared
    let devices = DeviceEvents.shared
    let usbDevices = USBDeviceWatcher()
    let volumes = VolumeWatcher()
    let displays = DisplayWatcher()
    let airDrop = AirDropWatcher()
    lazy var screenshots = ScreenshotWatcher(tray: tray)

    func start() {
        tray.start()
        nowPlaying.start()
        levels.start()
        agents.start()
        battery.start()
        accessories.start()
        usbDevices.start()
        volumes.start()
        displays.start()
        airDrop.start()
        calendar.start()
        clipboard.start()
        downloads.start()
        screenshots.start()
        hello.start()
        controls.start()
        stats.prime()
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
            .environmentObject(services.battery)
            .environmentObject(services.stats)
            .environmentObject(services.keepAwake)
            .environmentObject(services.timer)
            .environmentObject(services.accessories)
            .environmentObject(services.calendar)
            .environmentObject(services.tray)
            .environmentObject(services.clipboard)
            .environmentObject(services.downloads)
            .environmentObject(services.mirror)
            .environmentObject(services.screenshots)
            .environmentObject(services.controls)
            .environmentObject(services.log)
            .environmentObject(services.devices)
    }
}
