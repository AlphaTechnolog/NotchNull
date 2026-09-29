import Foundation
import IOKit
import IOKit.usb

/// USB devices plugging in and out. Each device is classified from the drivers that attach under
/// it: a serial port (ESP32, Arduino and other dev boards, with their /dev/cu.* path), a HID
/// keyboard, mouse or game controller, or a generic USB device. Hubs are ignored.
@MainActor
final class USBDeviceWatcher {
    private var port: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    /// What each attached device was, by registry ID, so a removal can be named after the fact.
    private var attached: [UInt64: DeviceEvent] = [:]

    func start() {
        guard port == nil, let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        self.port = port
        IONotificationPortSetDispatchQueue(port, .main)
        let context = Unmanaged.passUnretained(self).toOpaque()

        IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, IOServiceMatching("IOUSBHostDevice"), { context, iterator in
            guard let context else { return }
            let watcher = Unmanaged<USBDeviceWatcher>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { watcher.devicesAdded(iterator) }
        }, context, &addedIterator)
        IOServiceAddMatchingNotification(port, kIOTerminatedNotification, IOServiceMatching("IOUSBHostDevice"), { context, iterator in
            guard let context else { return }
            let watcher = Unmanaged<USBDeviceWatcher>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { watcher.devicesRemoved(iterator) }
        }, context, &removedIterator)

        // Draining the iterators arms the notifications and records what is already plugged in.
        devicesAdded(addedIterator)
        devicesRemoved(removedIterator)
    }

    private func devicesAdded(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != IO_OBJECT_NULL {
            guard let id = Self.registryID(service), !Self.isHub(service) else {
                IOObjectRelease(service)
                continue
            }
            // Interface drivers (serial, HID) attach a moment after the device itself.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                defer { IOObjectRelease(service) }
                guard let self, let event = Self.describe(service) else { return }
                self.attached[id] = event
                DeviceEvents.shared.announce(event)
            }
        }
    }

    private func devicesRemoved(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != IO_OBJECT_NULL {
            defer { IOObjectRelease(service) }
            guard let id = Self.registryID(service), var event = attached.removeValue(forKey: id) else { continue }
            event = DeviceEvent(change: .disconnected, name: event.name, symbol: event.symbol, detail: event.detail)
            DeviceEvents.shared.announce(event)
        }
    }

    // MARK: Classification

    private static func describe(_ service: io_service_t) -> DeviceEvent? {
        let product = string(service, kUSBProductString) ?? string(service, "USB Product Name")
        let vendor = string(service, kUSBVendorString) ?? string(service, "USB Vendor Name")
        let vendorID = number(service, kUSBVendorID) ?? 0
        guard let product, !product.isEmpty else { return nil }

        if let callout = search(service, "IOCalloutDevice") as? String {
            return DeviceEvent(change: .connected, name: boardName(product: product, vendorID: vendorID), symbol: "cpu", detail: callout)
        }
        if let page = search(service, "PrimaryUsagePage") as? Int, page == 1,
           let usage = search(service, "PrimaryUsage") as? Int {
            switch usage {
            case 6: return DeviceEvent(change: .connected, name: product, symbol: "keyboard", detail: vendor)
            case 2: return DeviceEvent(change: .connected, name: product, symbol: "computermouse", detail: vendor)
            case 4, 5: return DeviceEvent(change: .connected, name: product, symbol: "gamecontroller", detail: vendor)
            default: break
            }
        }
        // Mass storage is announced by the volume watcher once it mounts, with its real name.
        if let bsd = search(service, "BSD Name") as? String, bsd.hasPrefix("disk") {
            return nil
        }
        return DeviceEvent(change: .connected, name: product, symbol: "cable.connector", detail: vendor)
    }

    /// Names dev boards after what they are, not the USB-to-serial chip's marketing string.
    nonisolated static func boardName(product: String, vendorID: Int) -> String {
        switch vendorID {
        case 0x303A: return product.lowercased().contains("jtag") ? "ESP32" : product
        case 0x2341, 0x2A03: return product.lowercased().hasPrefix("arduino") ? product : "Arduino \(product)"
        case 0x2E8A: return product.lowercased().contains("pico") ? product : "Raspberry Pi \(product)"
        case 0x10C4: return "ESP32 / CP210x board"
        case 0x1A86: return "CH340 serial board"
        case 0x0403: return "FTDI serial board"
        default: return product
        }
    }

    private static func isHub(_ service: io_service_t) -> Bool {
        number(service, kUSBDeviceClass) == 9
    }

    private static func registryID(_ service: io_service_t) -> UInt64? {
        var id: UInt64 = 0
        return IORegistryEntryGetRegistryEntryID(service, &id) == KERN_SUCCESS ? id : nil
    }

    private static func string(_ service: io_service_t, _ key: String) -> String? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
    }

    private static func number(_ service: io_service_t, _ key: String) -> Int? {
        (IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber)?.intValue
    }

    /// First value of `key` anywhere below the device (its interfaces and their drivers).
    private static func search(_ service: io_service_t, _ key: String) -> Any? {
        IORegistryEntrySearchCFProperty(service, kIOServicePlane, key as CFString, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively))
    }
}
