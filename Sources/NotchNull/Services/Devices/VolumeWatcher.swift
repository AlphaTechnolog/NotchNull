import AppKit

/// Drives, SD cards, disk images and network shares mounting and ejecting.
@MainActor
final class VolumeWatcher {
    private var observers: [NSObjectProtocol] = []
    /// Mounted volumes by path, described while they can still be queried.
    private var mounted: [String: DeviceEvent] = [:]

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] note in
            MainActor.assumeIsolated { self?.didMount(note) }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { [weak self] note in
            MainActor.assumeIsolated { self?.didUnmount(note) }
        })
    }

    private func didMount(_ note: Notification) {
        guard let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
        let values = try? url.resourceValues(forKeys: [.volumeLocalizedNameKey, .volumeTotalCapacityKey, .volumeIsLocalKey, .volumeIsRemovableKey, .volumeIsInternalKey])
        if values?.volumeIsInternal == true { return }
        let name = values?.volumeLocalizedName ?? url.lastPathComponent
        let symbol: String
        if values?.volumeIsLocal == false {
            symbol = "server.rack"
        } else if values?.volumeIsRemovable == true {
            symbol = "sdcard.fill"
        } else {
            symbol = "externaldrive.fill"
        }
        let capacity = values?.volumeTotalCapacity.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) }
        let event = DeviceEvent(change: .connected, name: name, symbol: symbol, detail: capacity, action: .reveal(url))
        mounted[url.path] = event
        DeviceEvents.shared.announce(event)
    }

    private func didUnmount(_ note: Notification) {
        guard let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL,
              let event = mounted.removeValue(forKey: url.path) else { return }
        DeviceEvents.shared.announce(DeviceEvent(change: .disconnected, name: event.name, symbol: event.symbol, detail: "Ejected"))
    }
}
