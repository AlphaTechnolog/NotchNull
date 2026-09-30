import Foundation

enum Formatting {
    static func elapsed(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds))
        if value < 60 { return "\(value)s" }
        if value < 3600 { return "\(value / 60)m \(value % 60)s" }
        return "\(value / 3600)h \((value % 3600) / 60)m"
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds))
        return value >= 3600
            ? String(format: "%d:%02d:%02d", value / 3600, (value % 3600) / 60, value % 60)
            : String(format: "%d:%02d", value / 60, value % 60)
    }

    /// Compact reset label: a countdown when it is close, otherwise the weekday and hour.
    static func resetTime(_ date: Date, now: Date = Date()) -> String {
        let seconds = date.timeIntervalSince(now)
        if seconds <= 0 { return "now" }
        if seconds < 12 * 3600 {
            let minutes = Int(seconds / 60)
            return minutes < 60 ? "in \(minutes)m" : "in \(minutes / 60)h \(minutes % 60)m"
        }
        if seconds < 6 * 86_400 {
            return date.formatted(.dateTime.weekday(.abbreviated).hour(.defaultDigits(amPM: .abbreviated)))
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// A point in time with just enough context: "4:10 PM", "tomorrow 9:30 AM", "Thu 11:24 AM".
    static func moment(_ date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(date, inSameDayAs: now) { return time }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "tomorrow \(time)"
        }
        return date.formatted(.dateTime.weekday(.abbreviated)) + " " + time
    }

    /// The exact moment a download goes: "Today 12:05", "Tomorrow 9:30 AM", "Mon 12:05", "Oct 29".
    static func deadline(_ date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(date, inSameDayAs: now) { return "Today \(time)" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow \(time)"
        }
        if date.timeIntervalSince(now) < 6 * 86_400 {
            return date.formatted(.dateTime.weekday(.abbreviated)) + " " + time
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// Time left, compact: "0:42" in the last minute, then "12m", "3h 5m", "2d 4h", "12d".
    static func remaining(until date: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now).rounded(.up)))
        if seconds < 60 { return String(format: "0:%02d", seconds) }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return minutes % 60 == 0 ? "\(hours)h" : "\(hours)h \(minutes % 60)m" }
        let days = hours / 24
        return days < 3 && hours % 24 != 0 ? "\(days)d \(hours % 24)h" : "\(days)d"
    }

    static func countdown(to date: Date, now: Date = Date()) -> String {
        let seconds = max(0, date.timeIntervalSince(now))
        let minutes = Int(seconds / 60)
        if minutes < 1 { return "now" }
        if minutes < 60 { return "in \(minutes) min" }
        let hours = minutes / 60
        if hours < 24 { return "in \(hours)h \(minutes % 60)m" }
        return "in \(hours / 24)d \(hours % 24)h"
    }

    static func usageSummary(_ window: UsageWindow, now: Date = Date()) -> String {
        var parts: [String] = []
        if let hit = window.projectedExhaustion(at: now), let rates = window.rates(at: now) {
            let unit = rates.unit >= 86_400 ? "day" : "h"
            parts.append("\(percent(rates.used))/\(unit) runs out ~\(moment(hit, now: now)); \(percent(rates.budget))/\(unit) lasts")
        }
        if let reset = window.resetsAt {
            parts.append("resets \(moment(reset, now: now))")
        }
        return parts.isEmpty ? "\(Int(window.percent))% used" : parts.joined(separator: " · ")
    }

    static func percent(_ value: Double) -> String {
        value < 10 ? String(format: "%.1f%%", value) : "\(Int(value.rounded()))%"
    }

    static func tokens(_ value: Int) -> String {
        switch value {
        case ..<1_000: "\(value)"
        case ..<1_000_000: String(format: "%.1fK", Double(value) / 1_000)
        case ..<1_000_000_000: String(format: "%.1fM", Double(value) / 1_000_000)
        default: String(format: "%.2fB", Double(value) / 1_000_000_000)
        }
    }

    static func bytes(_ value: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
    }

    /// Short transfer rate that fits a narrow column: "0.5 KB/s", "17 KB/s", "1.2 MB/s".
    static func rate(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond >= 1 else { return "—" }
        let units = ["KB/s", "MB/s", "GB/s"]
        var value = bytesPerSecond / 1_000
        var unit = 0
        while value >= 1_000, unit < units.count - 1 {
            value /= 1_000
            unit += 1
        }
        let number = value < 10 ? String(format: "%.1f", value) : String(Int(value.rounded()))
        return "\(number) \(units[unit])"
    }

    static func relative(_ date: Date, now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 45 { return "just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h ago" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    static func minutes(_ value: Int) -> String {
        value >= 60 ? "\(value / 60)h \(value % 60)m" : "\(value)m"
    }
}
