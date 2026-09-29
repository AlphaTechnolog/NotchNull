import SwiftUI

/// Something that plugged in, paired, mounted or arrived: headphones, keyboards, dev boards on a
/// serial port, drives, displays, the power adapter, an AirDrop.
struct DeviceEvent: Identifiable, Equatable {
    enum Change: Equatable {
        case connected, disconnected, received

        var label: String {
            switch self {
            case .connected: "Connected"
            case .disconnected: "Disconnected"
            case .received: "Received"
            }
        }
    }

    let id = UUID()
    var change: Change
    var name: String
    var symbol: String
    /// Secondary line: a serial port, a capacity, battery levels, a file name.
    var detail: String?
    /// Per-bud and case battery for headphones that report it.
    var accessory: AccessoryInfo?
    var action: ActivityLog.Entry.Action?

    static func == (lhs: DeviceEvent, rhs: DeviceEvent) -> Bool { lhs.id == rhs.id }

    var tint: Color {
        switch change {
        case .connected: Theme.Accent.success
        case .disconnected: Theme.Palette.textTertiary
        case .received: Theme.Accent.airdrop
        }
    }
}

/// Collects device events from every watcher, shows the latest in the notch and logs it.
@MainActor
final class DeviceEvents: ObservableObject {
    static let shared = DeviceEvents()

    @Published private(set) var last: DeviceEvent?

    private let launchedAt = Date()
    private var recent: [String: Date] = [:]

    private init() {}

    func announce(_ event: DeviceEvent) {
        guard Preferences.shared.accessoriesEnabled else { return }
        // Watchers enumerate what is already attached at launch; that is not news.
        guard Date().timeIntervalSince(launchedAt) > Constants.Durations.deviceLaunchQuiet else { return }
        // The same device can surface through two paths (e.g. a USB serial port and its volume).
        let key = "\(event.change)|\(event.name)"
        if let previous = recent[key], Date().timeIntervalSince(previous) < 2 { return }
        recent[key] = Date()

        withAnimation(Motion.state) { last = event }
        ActivityCenter.shared.post(.accessory, for: Constants.Durations.accessory)
        let verb = event.change == .received ? "received" : event.change.label.lowercased()
        ActivityLog.shared.add(
            symbol: event.symbol,
            tint: event.tint,
            title: "\(event.name) \(verb)",
            detail: event.detail,
            action: event.action
        )
        Log.system.info("Device \(verb, privacy: .public): \(event.name, privacy: .public)")
    }

    /// Fixture entry point for snapshot rendering.
    func preview(_ event: DeviceEvent) { last = event }
}
