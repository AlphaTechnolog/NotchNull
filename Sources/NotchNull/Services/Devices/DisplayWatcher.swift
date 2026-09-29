import AppKit

/// External displays connecting and disconnecting.
@MainActor
final class DisplayWatcher {
    private var observer: NSObjectProtocol?
    private var screens: [CGDirectDisplayID: String] = [:]

    func start() {
        screens = Self.current()
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensChanged() }
        }
    }

    private func screensChanged() {
        let next = Self.current()
        for (id, name) in next where screens[id] == nil {
            DeviceEvents.shared.announce(DeviceEvent(change: .connected, name: name, symbol: "display", detail: Self.resolution(of: id)))
        }
        for (id, name) in screens where next[id] == nil {
            DeviceEvents.shared.announce(DeviceEvent(change: .disconnected, name: name, symbol: "display"))
        }
        screens = next
    }

    private static func current() -> [CGDirectDisplayID: String] {
        var result: [CGDirectDisplayID: String] = [:]
        for screen in NSScreen.screens {
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
                  CGDisplayIsBuiltin(id) == 0 else { continue }
            result[id] = screen.localizedName
        }
        return result
    }

    private static func resolution(of id: CGDirectDisplayID) -> String? {
        guard let mode = CGDisplayCopyDisplayMode(id) else { return nil }
        return "\(mode.width) × \(mode.height)"
    }
}
