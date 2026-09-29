import Combine
import Foundation
import IOKit.pwr_mgt
import SwiftUI

/// Prevents idle display sleep through a power-management assertion, optionally for a fixed time.
@MainActor
final class KeepAwakeService: ObservableObject {
    enum Duration: CaseIterable, Identifiable {
        case untilStopped, oneHour, twoHours, fourHours

        var id: Self { self }
        var seconds: TimeInterval? {
            switch self {
            case .untilStopped: nil
            case .oneHour: 3600
            case .twoHours: 7200
            case .fourHours: 14_400
            }
        }
        var title: String {
            switch self {
            case .untilStopped: "Until stopped"
            case .oneHour: "1 hour"
            case .twoHours: "2 hours"
            case .fourHours: "4 hours"
            }
        }
    }

    @Published private(set) var isActive = false
    @Published private(set) var endsAt: Date?
    @Published var duration: Duration = .untilStopped

    private var assertion: IOPMAssertionID = 0
    private var expiry: Timer?

    func toggle() { isActive ? stop() : start() }

    func start() {
        guard !isActive else { return }
        let reason = "NotchNull Keep Awake" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertion
        )
        guard result == kIOReturnSuccess else {
            Log.system.error("Keep awake assertion failed: \(result)")
            return
        }
        withAnimation(Motion.state) {
            isActive = true
            endsAt = duration.seconds.map { Date().addingTimeInterval($0) }
        }
        if let seconds = duration.seconds {
            expiry = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.stop() }
            }
        }
    }

    func stop() {
        expiry?.invalidate()
        expiry = nil
        if assertion != 0 {
            IOPMAssertionRelease(assertion)
            assertion = 0
        }
        withAnimation(Motion.state) {
            isActive = false
            endsAt = nil
        }
    }

    func cycleDuration() {
        let all = Duration.allCases
        let next = all[((all.firstIndex(of: duration) ?? 0) + 1) % all.count]
        withAnimation(Motion.state) { duration = next }
        if isActive {
            stop()
            start()
        }
    }
}
