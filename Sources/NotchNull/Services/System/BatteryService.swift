import AppKit
import Combine
import IOKit.ps
import SwiftUI

struct BatteryState: Equatable {
    var percent: Int = 100
    var isCharging = false
    var isPluggedIn = false
    var isCharged = false
    var minutesToEmpty: Int?
    var minutesToFull: Int?
    var hasBattery = false
    var powerMode: PowerMode = .automatic

    var lowPowerMode: Bool { powerMode == .low }
}

struct EnergyConsumer: Identifiable, Equatable {
    let id: pid_t
    let name: String
    let icon: NSImage?
    /// Average power over the last sample window, in watts.
    let watts: Double

    static func == (lhs: EnergyConsumer, rhs: EnergyConsumer) -> Bool {
        lhs.id == rhs.id && lhs.watts == rhs.watts
    }
}

/// Battery level and power adapter events from IOKit power sources, plus per-app energy use
/// (billed energy aggregated by responsible app) sampled only while someone is looking.
@MainActor
final class BatteryService: ObservableObject {
    @Published private(set) var state = BatteryState()
    @Published private(set) var consumers: [EnergyConsumer] = []
    /// Called when the power adapter is plugged in or out.
    var onPowerSourceChange: (() -> Void)?

    private var runLoopSource: CFRunLoopSource?
    private var lastLowAlert: Int?
    private var energyTimer: Timer?
    private var energyBaseline: [pid_t: UInt64] = [:]
    private var baselineDate: Date?
    private var observers: [NSObjectProtocol] = []
    private var powerMode: PowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled ? .low : .automatic
    private var powerModeTimer: Timer?

    func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let service = Unmanaged<BatteryService>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated {
                service.refresh(announce: true)
                service.refreshPowerMode()
            }
        }, context)?.takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        observers.append(NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPowerMode() }
        })
        powerModeTimer = Timer.scheduledTimer(withTimeInterval: Constants.Intervals.powerModePoll, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPowerMode() }
        }
        refresh(announce: false)
        refreshPowerMode()
    }

    /// Re-reads the energy mode in the background; the battery tint follows it.
    func refreshPowerMode() {
        DispatchQueue.global(qos: .utility).async {
            let mode = PowerModeReader.read()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard mode != self.powerMode else { return }
                    self.powerMode = mode
                    self.refresh(announce: false)
                }
            }
        }
    }

    /// Fixture entry point for snapshot rendering.
    func preview(_ state: BatteryState) { self.state = state }

    func refresh(announce: Bool) {
        let previous = state
        var next = Self.read()
        next.powerMode = powerMode
        guard next != previous else { return }
        withAnimation(Motion.value) { state = next }
        if announce, next.isPluggedIn != previous.isPluggedIn { onPowerSourceChange?() }
        guard announce, Preferences.shared.batteryEnabled, next.hasBattery else { return }
        if next.isPluggedIn && !previous.isPluggedIn {
            ActivityCenter.shared.post(.charging, for: Constants.Durations.charging)
            lastLowAlert = nil
        } else if !next.isPluggedIn && previous.isPluggedIn {
            ActivityCenter.shared.dismiss(.charging)
            let remaining = next.minutesToEmpty.map { " · \(Formatting.minutes($0)) left" } ?? ""
            DeviceEvents.shared.announce(DeviceEvent(change: .disconnected, name: "Power adapter", symbol: "powerplug.fill", detail: "\(next.percent)% on battery\(remaining)"))
        }
        if !next.isPluggedIn {
            for threshold in [20, 10, 5] where next.percent <= threshold && previous.percent > threshold {
                if lastLowAlert != threshold {
                    lastLowAlert = threshold
                    ActivityCenter.shared.post(.lowBattery, for: Constants.Durations.charging + 1)
                }
            }
        }
    }

    private static func read() -> BatteryState {
        var state = BatteryState()
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else { return state }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  (description[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
            state.hasBattery = true
            let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = description[kIOPSMaxCapacityKey] as? Int ?? 100
            state.percent = max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : current
            state.isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
            state.isPluggedIn = (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            state.isCharged = description[kIOPSIsChargedKey] as? Bool ?? false
            if let empty = description[kIOPSTimeToEmptyKey] as? Int, empty > 0 { state.minutesToEmpty = empty }
            if let full = description[kIOPSTimeToFullChargeKey] as? Int, full > 0 { state.minutesToFull = full }
        }
        return state
    }

    // MARK: Energy

    /// Starts sampling per-app energy while a view that shows it is visible.
    func setEnergySampling(_ active: Bool) {
        energyTimer?.invalidate()
        energyTimer = nil
        guard active else { return }
        sampleEnergy()
        energyTimer = Timer.scheduledTimer(withTimeInterval: Constants.Intervals.batteryEnergySample, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sampleEnergy() }
        }
    }

    private func sampleEnergy() {
        let previous = energyBaseline
        let previousDate = baselineDate
        DispatchQueue.global(qos: .utility).async {
            let totals = EnergySampler.energyByResponsibleApp()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.energyBaseline = totals
                    self.baselineDate = Date()
                    guard let previousDate, !previous.isEmpty else { return }
                    let seconds = Date().timeIntervalSince(previousDate)
                    guard seconds > 0.5 else { return }
                    var result: [EnergyConsumer] = []
                    for (pid, energy) in totals {
                        guard let before = previous[pid], energy > before,
                              let app = NSRunningApplication(processIdentifier: pid),
                              app.activationPolicy != .prohibited else { continue }
                        let watts = Double(energy - before) / 1e9 / seconds
                        guard watts > 0.01 else { continue }
                        result.append(EnergyConsumer(id: pid, name: app.localizedName ?? "pid \(pid)", icon: app.icon, watts: watts))
                    }
                    withAnimation(Motion.state) {
                        self.consumers = Array(result.sorted { $0.watts > $1.watts }.prefix(4))
                    }
                }
            }
        }
    }
}

/// Reads billed energy (nanojoules) for every process and folds it into the app responsible for it,
/// so browser helpers and renderers count toward the browser.
enum EnergySampler {
    private typealias ResponsiblePID = @convention(c) (pid_t) -> pid_t

    private static let responsible: ResponsiblePID? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid") else { return nil }
        return unsafeBitCast(symbol, to: ResponsiblePID.self)
    }()

    static func energyByResponsibleApp() -> [pid_t: UInt64] {
        let capacity = proc_listallpids(nil, 0)
        guard capacity > 0 else { return [:] }
        var pids = [pid_t](repeating: 0, count: Int(capacity) + 64)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        var totals: [pid_t: UInt64] = [:]
        for pid in pids.prefix(Int(max(0, count))) where pid > 0 {
            var info = rusage_info_v4()
            let result = withUnsafeMutablePointer(to: &info) { pointer in
                pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
                }
            }
            guard result == 0 else { continue }
            let owner = responsible?(pid) ?? pid
            totals[owner > 0 ? owner : pid, default: 0] += info.ri_billed_energy
        }
        return totals
    }
}
