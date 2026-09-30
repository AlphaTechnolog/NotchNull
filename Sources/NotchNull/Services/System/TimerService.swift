import AppKit
import Combine
import SwiftUI

/// A countdown timer that lives in the notch wings while running.
@MainActor
final class TimerService: ObservableObject {
    enum State: Equatable {
        case idle
        case running(endsAt: Date)
        case paused(remaining: TimeInterval)
    }

    static let presets: [TimeInterval] = [60, 5 * 60, 15 * 60, 25 * 60, 45 * 60]

    /// Bounds for the Clock-style custom editor (hr 0-99, min/sec 0-59, total 1s…99:59:59).
    nonisolated static let customMaxSeconds: TimeInterval = 99 * 3_600 + 59 * 60 + 59

    /// Validates a Clock-style hr/min/sec triple. Returns nil when out of range or zero.
    nonisolated static func total(hours: Int, minutes: Int, seconds: Int) -> TimeInterval? {
        guard (0 ... 99).contains(hours), (0 ... 59).contains(minutes), (0 ... 59).contains(seconds) else { return nil }
        let total = TimeInterval(hours * 3_600 + minutes * 60 + seconds)
        guard total >= 1, total <= customMaxSeconds else { return nil }
        return total
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var total: TimeInterval = 25 * 60
    @Published private(set) var label = "Timer"

    private var ticker: Timer?

    func start(_ seconds: TimeInterval, label: String = "Timer") {
        total = seconds
        self.label = label
        withAnimation(Motion.state) { state = .running(endsAt: Date().addingTimeInterval(seconds)) }
        schedule()
        ActivityCenter.shared.setPersistent(.timer, active: true)
    }

    func pause() {
        guard case .running(let endsAt) = state else { return }
        ticker?.invalidate()
        withAnimation(Motion.state) { state = .paused(remaining: max(0, endsAt.timeIntervalSinceNow)) }
    }

    func resume() {
        guard case .paused(let remaining) = state else { return }
        withAnimation(Motion.state) { state = .running(endsAt: Date().addingTimeInterval(remaining)) }
        schedule()
    }

    func togglePause() {
        if case .running = state { pause() } else { resume() }
    }

    func add(_ seconds: TimeInterval) {
        switch state {
        case .running(let endsAt):
            total += seconds
            state = .running(endsAt: endsAt.addingTimeInterval(seconds))
            schedule()
        case .paused(let remaining):
            total += seconds
            state = .paused(remaining: remaining + seconds)
        case .idle:
            start(seconds)
        }
    }

    func cancel() {
        ticker?.invalidate()
        withAnimation(Motion.state) { state = .idle }
        ActivityCenter.shared.setPersistent(.timer, active: false)
    }

    func remaining(at date: Date = Date()) -> TimeInterval {
        switch state {
        case .idle: 0
        case .running(let endsAt): max(0, endsAt.timeIntervalSince(date))
        case .paused(let remaining): remaining
        }
    }

    func progress(at date: Date = Date()) -> Double {
        guard total > 0 else { return 0 }
        return 1 - remaining(at: date) / total
    }

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    private func schedule() {
        ticker?.invalidate()
        guard case .running(let endsAt) = state else { return }
        ticker = Timer.scheduledTimer(withTimeInterval: max(0.05, endsAt.timeIntervalSinceNow), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish() }
        }
    }

    private func finish() {
        withAnimation(Motion.state) { state = .idle }
        ActivityCenter.shared.setPersistent(.timer, active: false)
        ActivityCenter.shared.post(.timerFinished, for: 6)
        ActivityLog.shared.add(symbol: "timer", tint: Theme.Accent.timer, title: "\(label) finished", detail: TimerService.format(total))
        if Preferences.shared.sounds { NSSound(named: "Glass")?.play() }
    }

    static func format(_ seconds: TimeInterval) -> String {
        let value = Int(seconds.rounded(.up))
        let hours = value / 3600, minutes = (value % 3600) / 60, secs = value % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs) : String(format: "%d:%02d", minutes, secs)
    }
}
