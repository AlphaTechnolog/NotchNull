import Foundation
import SwiftUI

/// Kimi Code (Kimi For Coding) subscription: 5-hour, weekly and monthly pools from the Kimi Code
/// usage endpoint. A Kimi Code API key is required; Moonshot Open Platform keys have no plan limits.
struct KimiPlan: PlanProvider {
    let id = "kimi"
    let title = "Kimi Code"
    let monogram = "K"
    var tint: Color { Theme.Accent.kimi }

    func credential(in sources: PlanCredentialSources) -> PlanCredential? {
        if let found = sources.env(["KIMI_CODE_API_KEY"]) {
            return PlanCredential(key: found.value, source: found.name)
        }
        if let found = sources.openCodeKey(["kimi-for-coding"]) {
            return PlanCredential(key: found.key, source: "OpenCode")
        }
        if let found = sources.claudeKey(forHosts: ["api.kimi.com"]),
           sources.claudeEnvironment["ANTHROPIC_BASE_URL"]?.contains("/coding") == true {
            return PlanCredential(key: found.key, source: "Claude Code settings")
        }
        return nil
    }

    func fetch(_ credential: PlanCredential) async throws -> PlanSnapshot {
        let response = try await PlanHTTP.get(URL(string: "https://api.kimi.com/coding/v1/usages")!, bearer: credential.key)
        if response.status == 401 || response.status == 403 { throw PlanError.signedOut("Key rejected by Kimi Code") }
        guard response.status == 200 else { throw PlanError.unavailable("Kimi returned \(response.status)") }
        return try Self.parse(response.data)
    }

    /// Newer responses carry ratio pools (`usages.limit_5h`, `limit_7d`, `limit_month_total`);
    /// older ones a weekly `usage` count plus `limits[]` with their window length.
    static func parse(_ data: Data) throws -> PlanSnapshot {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw PlanError.unavailable("Unreadable Kimi response")
        }
        var windows: [UsageWindow] = []
        if let pools = root["usages"] as? [String: Any] {
            let known: [(key: String, label: String, duration: TimeInterval)] = [
                ("limit_5h", "5 hours", 5 * 3600), ("limit_7d", "Week", 7 * 86_400), ("limit_month_total", "Month", 30 * 86_400),
            ]
            for pool in known {
                guard let entry = pools[pool.key] as? [String: Any],
                      let ratio = PlanJSON.double(entry["used_ratio"]), ratio.isFinite, ratio >= 0 else { continue }
                windows.append(UsageWindow(id: "kimi-\(pool.key)", label: pool.label, percent: min(1, ratio) * 100, resetsAt: PlanJSON.date(entry["reset_time"]), duration: pool.duration))
            }
        }
        if windows.isEmpty {
            for limit in root["limits"] as? [[String: Any]] ?? [] {
                guard let window = limit["window"] as? [String: Any], let detail = limit["detail"] as? [String: Any],
                      let minutes = minutes(window), let percent = percent(detail) else { continue }
                windows.append(UsageWindow(id: "kimi-\(minutes)", label: PlanJSON.label(minutes: minutes), percent: percent, resetsAt: resetDate(detail), duration: TimeInterval(minutes * 60)))
            }
            if let weekly = root["usage"] as? [String: Any], let percent = percent(weekly) {
                windows.append(UsageWindow(id: "kimi-week", label: "Week", percent: percent, resetsAt: resetDate(weekly), duration: 7 * 86_400))
            }
        }
        guard !windows.isEmpty else { throw PlanError.noSubscription }
        return PlanSnapshot(plan: planName(root), windows: windows)
    }

    private static func minutes(_ window: [String: Any]) -> Int? {
        guard let duration = PlanJSON.double(window["duration"]).map(Int.init), duration > 0 else { return nil }
        switch window["timeUnit"] as? String {
        case "TIME_UNIT_MINUTE": return duration
        case "TIME_UNIT_HOUR": return duration * 60
        case "TIME_UNIT_DAY": return duration * 1440
        default: return nil
        }
    }

    private static func percent(_ detail: [String: Any]) -> Double? {
        guard let limit = PlanJSON.double(detail["limit"]), limit > 0 else { return nil }
        if let used = PlanJSON.double(detail["used"]) { return used / limit * 100 }
        if let remaining = PlanJSON.double(detail["remaining"]) { return (limit - remaining) / limit * 100 }
        return nil
    }

    private static func resetDate(_ detail: [String: Any]) -> Date? {
        ["resetTime", "resetAt", "reset_time", "reset_at"].lazy.compactMap { PlanJSON.date(detail[$0]) }.first
    }

    /// Membership levels, named as in Kimi's own catalog.
    private static func planName(_ root: [String: Any]) -> String? {
        guard let level = ((root["user"] as? [String: Any])?["membership"] as? [String: Any])?["level"] as? String,
              !level.isEmpty, level != "LEVEL_UNSPECIFIED" else { return nil }
        switch level {
        case "LEVEL_FREE": return "Adagio"
        case "LEVEL_TRIAL": return "Andante"
        case "LEVEL_BASIC": return "Moderato"
        case "LEVEL_INTERMEDIATE": return "Allegretto"
        case "LEVEL_ADVANCED": return "Allegro"
        default: return level.replacingOccurrences(of: "LEVEL_", with: "").capitalized
        }
    }
}
