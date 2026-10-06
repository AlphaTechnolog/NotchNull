import AppKit
import Combine
import CoreAudio
import CoreWLAN
import IOBluetooth
import SwiftUI

struct AudioOutputDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let symbol: String
}

/// Quick controls for the island's control center and the Controls tab. Every control changes
/// real system state; anything that needs a permission reports it instead of failing silently.
@MainActor
final class ControlCenterService: NSObject, ObservableObject, CWEventDelegate {
    @Published private(set) var wifiOn = false
    @Published private(set) var wifiName: String?
    @Published private(set) var wifiSignal: Int?
    @Published private(set) var bluetoothOn = false
    @Published private(set) var darkMode = false
    @Published private(set) var outputs: [AudioOutputDevice] = []
    @Published private(set) var currentOutput: AudioDeviceID?
    @Published private(set) var lastError: String?

    private let wifi = CWWiFiClient.shared()
    private var observers: [NSObjectProtocol] = []
    private var pollTimer: Timer?
    private var consumers = 0

    private typealias BTSetPower = @convention(c) (Int32) -> Void
    private static let bluetoothHandle = dlopen("/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth", RTLD_LAZY)
    private static let btSet: BTSetPower? = {
        guard let handle = bluetoothHandle, let symbol = dlsym(handle, "IOBluetoothPreferenceSetControllerPowerState") else { return nil }
        return unsafeBitCast(symbol, to: BTSetPower.self)
    }()

    func start() {
        wifi.delegate = self
        try? wifi.startMonitoringEvent(with: .powerDidChange)
        try? wifi.startMonitoringEvent(with: .ssidDidChange)
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } })
        refresh()
    }

    /// Polls signal strength and device lists only while a controls view is visible.
    func setVisible(_ visible: Bool) {
        consumers = max(0, consumers + (visible ? 1 : -1))
        if consumers > 0, pollTimer == nil {
            refresh()
            pollTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        } else if consumers == 0 {
            pollTimer?.invalidate()
            pollTimer = nil
        }
    }

    func refresh() {
        let interface = wifi.interface()
        let nextWifi = interface?.powerOn() ?? false
        let nextName = interface?.ssid()
        let rssi = interface?.rssiValue()
        // Bluetooth stays untouched until the user allows it, so opening Controls never prompts.
        if Preferences.shared.bluetoothAllowed {
            BluetoothAccess.readPower { [weak self] isOn in
                withAnimation(Motion.state) { self?.bluetoothOn = isOn }
            }
        }
        let nextDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        let devices = AudioVolume.outputDevices()
        let current = AudioVolume.defaultOutputDevice()
        withAnimation(Motion.state) {
            wifiOn = nextWifi
            wifiName = nextName
            wifiSignal = rssi.flatMap { $0 == 0 ? nil : Self.bars(forRSSI: $0) }
            darkMode = nextDark
            outputs = devices
            currentOutput = current
        }
    }

    // MARK: Actions

    func toggleWifi() {
        guard let interface = wifi.interface() else { return report("No Wi-Fi interface found") }
        do {
            try interface.setPower(!interface.powerOn())
            lastError = nil
        } catch {
            report("Wi-Fi could not be switched: \(error.localizedDescription)")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.refresh() }
    }

    func toggleBluetooth() {
        // Tapping the tile is the user asking for Bluetooth: allow it, which lets macOS ask, then read.
        guard Preferences.shared.bluetoothAllowed else {
            Preferences.shared.bluetoothAllowed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.refresh() }
            return
        }
        guard let set = Self.btSet else { return report("Bluetooth control is unavailable on this macOS version") }
        set(bluetoothOn ? 0 : 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.refresh() }
    }

    func toggleDarkMode() {
        let script = "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            let code = error?[NSAppleScript.errorNumber] as? Int
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if code == -1743 {
                        self.report("Allow NotchNull to control System Events to switch appearance")
                        Permissions.open(.automation)
                    }
                    self.refresh()
                }
            }
        }
    }

    func lockScreen() {
        typealias Lock = @convention(c) () -> Void
        if let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY),
           let symbol = dlsym(handle, "SACLockScreenImmediate") {
            unsafeBitCast(symbol, to: Lock.self)()
        } else {
            sleepDisplay()
        }
    }

    func sleepDisplay() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        try? process.run()
    }

    func selectOutput(_ device: AudioOutputDevice) {
        AudioVolume.setDefaultOutputDevice(device.id)
        refresh()
    }

    func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:\(pane)") { NSWorkspace.shared.open(url) }
    }

    private func report(_ message: String) {
        withAnimation(Motion.state) { lastError = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard self?.lastError == message else { return }
            withAnimation(Motion.state) { self?.lastError = nil }
        }
    }

    private static func bars(forRSSI rssi: Int) -> Int {
        switch rssi {
        case (-55)...: 3
        case (-67)...: 2
        default: 1
        }
    }

    // MARK: CWEventDelegate

    nonisolated func powerStateDidChangeForWiFiInterface(withName interfaceName: String) {
        DispatchQueue.main.async { MainActor.assumeIsolated { self.refresh() } }
    }

    nonisolated func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        DispatchQueue.main.async { MainActor.assumeIsolated { self.refresh() } }
    }

    /// Fixture entry point for snapshot rendering.
    func preview(wifi name: String?, bluetooth: Bool, dark: Bool, outputs: [AudioOutputDevice]) {
        wifiOn = true
        wifiName = name
        wifiSignal = 3
        bluetoothOn = bluetooth
        darkMode = dark
        self.outputs = outputs
        currentOutput = outputs.first?.id
    }
}
