import Combine
import IOBluetooth
import SwiftUI

struct AccessoryInfo: Equatable, Identifiable {
    let id: String
    let name: String
    let symbol: String
    var left: Int?
    var right: Int?
    var caseLevel: Int?
    var single: Int?

    var hasBattery: Bool { left != nil || right != nil || single != nil }
}

/// Bluetooth connections of any kind (headphones, speakers, keyboards, mice, controllers). AirPods
/// and Beats report per-bud and case battery through IOBluetooth properties that are read
/// defensively (they are undocumented). Every connect and disconnect goes to `DeviceEvents`.
@MainActor
final class AccessoryService: NSObject, ObservableObject {
    @Published private(set) var last: AccessoryInfo?
    @Published private(set) var connected: [AccessoryInfo] = []

    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]

    func start() {
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
    }

    /// Fixture entry point for snapshot rendering.
    func preview(_ info: AccessoryInfo) {
        last = info
        connected = [info]
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let address = device.addressString ?? UUID().uuidString
        disconnectNotifications[address] = device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
        // Battery values arrive a moment after the link comes up.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self else { return }
            let info = Self.describe(device)
            withAnimation(Motion.state) {
                self.connected.removeAll { $0.id == info.id }
                self.connected.append(info)
                self.last = info
            }
            let levels = [info.left.map { "L \($0)%" }, info.right.map { "R \($0)%" }, info.caseLevel.map { "Case \($0)%" }, info.single.map { "\($0)%" }]
                .compactMap { $0 }.joined(separator: " · ")
            DeviceEvents.shared.announce(DeviceEvent(
                change: .connected, name: info.name, symbol: info.symbol,
                detail: levels.isEmpty ? "Bluetooth" : levels, accessory: info.hasBattery ? info : nil
            ))
        }
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let address = device.addressString ?? ""
        disconnectNotifications[address]?.unregister()
        disconnectNotifications[address] = nil
        let info = connected.first { $0.id == address } ?? Self.describe(device)
        withAnimation(Motion.state) { connected.removeAll { $0.id == address } }
        DeviceEvents.shared.announce(DeviceEvent(change: .disconnected, name: info.name, symbol: info.symbol, detail: "Bluetooth"))
    }

    private static func describe(_ device: IOBluetoothDevice) -> AccessoryInfo {
        let name = device.name ?? "Accessory"
        var info = AccessoryInfo(id: device.addressString ?? name, name: name, symbol: symbol(for: name, device: device))
        info.left = battery(device, "batteryPercentLeft")
        info.right = battery(device, "batteryPercentRight")
        info.caseLevel = battery(device, "batteryPercentCase")
        info.single = battery(device, "batteryPercentSingle")
        return info
    }

    private static func battery(_ device: IOBluetoothDevice, _ key: String) -> Int? {
        guard device.responds(to: NSSelectorFromString(key)),
              let value = (device.value(forKey: key) as? NSNumber)?.intValue,
              value > 0, value <= 100 else { return nil }
        return value
    }

    private static func symbol(for name: String, device: IOBluetoothDevice) -> String {
        let lower = name.lowercased()
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpods pro") { return "airpodspro" }
        if lower.contains("airpods") { return "airpods" }
        if lower.contains("beats") { return "beats.headphones" }
        if lower.contains("keyboard") { return "keyboard" }
        if lower.contains("trackpad") { return "rectangle.and.hand.point.up.left" }
        if lower.contains("mouse") { return "magicmouse" }
        if lower.contains("controller") || lower.contains("dualsense") || lower.contains("xbox") { return "gamecontroller.fill" }
        switch device.deviceClassMajor {
        case UInt32(kBluetoothDeviceClassMajorAudio):
            let speakers = [UInt32(kBluetoothDeviceClassMinorAudioLoudspeaker), UInt32(kBluetoothDeviceClassMinorAudioPortable), UInt32(kBluetoothDeviceClassMinorAudioHiFi)]
            return speakers.contains(device.deviceClassMinor) ? "hifispeaker.fill" : "headphones"
        case UInt32(kBluetoothDeviceClassMajorPeripheral):
            let minor = device.deviceClassMinor
            if minor & 0x10 != 0 { return "keyboard" }
            if minor & 0x20 != 0 { return "computermouse" }
            return "gamecontroller.fill"
        case UInt32(kBluetoothDeviceClassMajorPhone):
            return "iphone"
        case UInt32(kBluetoothDeviceClassMajorComputer):
            return "laptopcomputer"
        default:
            return "dot.radiowaves.left.and.right"
        }
    }
}
