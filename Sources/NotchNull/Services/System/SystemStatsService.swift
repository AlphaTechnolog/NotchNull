import Combine
import Darwin
import Foundation
import SwiftUI

struct SystemSnapshot: Equatable {
    var cpu: Double = 0
    var memoryUsed: Double = 0
    var memoryTotal: Double = 1
    var downloadRate: Double = 0
    var uploadRate: Double = 0
    var diskFree: Double = 0
    var thermal: ProcessInfo.ThermalState = .nominal

    var memoryFraction: Double { memoryTotal > 0 ? memoryUsed / memoryTotal : 0 }
}

/// CPU, memory, network throughput and disk space. Samples only while the panel is visible.
@MainActor
final class SystemStatsService: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot()
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var memoryHistory: [Double] = []
    @Published private(set) var networkHistory: [Double] = []

    private var timer: Timer?
    private var previousTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?
    private var previousBytes: (rx: UInt64, tx: UInt64, date: Date)?
    private var consumers = 0

    /// Takes baseline counters so the first visible sample already has a real delta.
    func prime() {
        _ = cpuUsage()
        _ = networkRates()
    }

    /// Reference-counted so several visible views can share one sampler.
    func setActive(_ active: Bool) {
        consumers = max(0, consumers + (active ? 1 : -1))
        if consumers > 0, timer == nil {
            sample()
            timer = Timer.scheduledTimer(withTimeInterval: Constants.Intervals.statsSample, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.sample() }
            }
        } else if consumers == 0 {
            timer?.invalidate()
            timer = nil
        }
    }

    /// Fixture entry point for snapshot rendering.
    func preview(_ snapshot: SystemSnapshot) { self.snapshot = snapshot }

    private func sample() {
        var next = snapshot
        next.cpu = cpuUsage() ?? next.cpu
        let memory = memoryUsage()
        next.memoryUsed = memory.used
        next.memoryTotal = memory.total
        let network = networkRates()
        next.downloadRate = network.down
        next.uploadRate = network.up
        next.diskFree = diskFree()
        next.thermal = ProcessInfo.processInfo.thermalState
        withAnimation(Motion.value) {
            snapshot = next
            cpuHistory = Self.append(next.cpu, to: cpuHistory)
            memoryHistory = Self.append(next.memoryFraction, to: memoryHistory)
            networkHistory = Self.append(next.downloadRate + next.uploadRate, to: networkHistory)
        }
    }

    private static func append(_ value: Double, to history: [Double]) -> [Double] {
        Array((history + [value]).suffix(Constants.Limits.statsHistory))
    }

    private func cpuUsage() -> Double? {
        var load = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let ticks = (
            user: UInt64(load.cpu_ticks.0), system: UInt64(load.cpu_ticks.1),
            idle: UInt64(load.cpu_ticks.2), nice: UInt64(load.cpu_ticks.3)
        )
        defer { previousTicks = ticks }
        guard let previous = previousTicks else { return nil }
        let busy = Double((ticks.user - previous.user) + (ticks.system - previous.system) + (ticks.nice - previous.nice))
        let total = busy + Double(ticks.idle - previous.idle)
        return total > 0 ? busy / total : 0
    }

    private func memoryUsage() -> (used: Double, total: Double) {
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (0, total) }
        let page = Double(vm_kernel_page_size)
        let used = (Double(stats.active_count) + Double(stats.wire_count) + Double(stats.compressor_page_count)) * page
        return (used, total)
    }

    private func networkRates() -> (down: Double, up: Double) {
        var rx: UInt64 = 0, tx: UInt64 = 0
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return (0, 0) }
        defer { freeifaddrs(pointer) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            let name = String(cString: entry.pointee.ifa_name)
            if entry.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
               name.hasPrefix("en") || name.hasPrefix("pdp_ip"),
               let data = entry.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                rx += UInt64(data.pointee.ifi_ibytes)
                tx += UInt64(data.pointee.ifi_obytes)
            }
            cursor = entry.pointee.ifa_next
        }
        let now = Date()
        defer { previousBytes = (rx, tx, now) }
        guard let previous = previousBytes else { return (0, 0) }
        let seconds = now.timeIntervalSince(previous.date)
        guard seconds > 0, rx >= previous.rx, tx >= previous.tx else { return (0, 0) }
        return (Double(rx - previous.rx) / seconds, Double(tx - previous.tx) / seconds)
    }

    private func diskFree() -> Double {
        let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return Double(values?.volumeAvailableCapacityForImportantUsage ?? 0)
    }
}
