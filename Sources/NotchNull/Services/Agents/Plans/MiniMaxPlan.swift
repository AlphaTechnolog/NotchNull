import Foundation
import SwiftUI

/// MiniMax Coding Plan: the 5-hour prompt window and, when the plan has one, the weekly one.
struct MiniMaxPlan: PlanProvider {
    let id = "minimax"
    let title = "MiniMax Coding Plan"
    let monogram = "M"
    var tint: Color { Theme.Accent.minimax }

    static let globalHost = "api.minimax.io"
    static let chinaHost = "api.minimaxi.com"

    func credential(in sources: PlanCredentialSources) -> PlanCredential? {
        if let found = sources.env(["MINIMAX_CODING_API_KEY", "MINIMAX_API_KEY"]) {
            return PlanCredential(key: found.value, source: found.name, host: Self.globalHost)
        }
        if let found = sources.openCodeKey(["minimax-coding-plan", "minimax"]) {
            return PlanCredential(key: found.key, source: "OpenCode", host: Self.globalHost)
        }
        if let found = sources.openCodeKey(["minimax-cn-coding-plan", "minimax-cn"]) {
            return PlanCredential(key: found.key, source: "OpenCode", host: Self.chinaHost)
        }
        if let found = sources.claudeKey(forHosts: [Self.globalHost, Self.chinaHost]) {
            return PlanCredential(key: found.key, source: "Claude Code settings", host: found.host)
        }
        return nil
    }

    func fetch(_ credential: PlanCredential) async throws -> PlanSnapshot {
        let host = credential.host ?? Self.globalHost
        let response = try await PlanHTTP.get(URL(string: "https://\(host)/v1/api/openplatform/coding_plan/remains")!, bearer: credential.key)
        if response.status == 401 || response.status == 403 { throw PlanError.signedOut("Key rejected by MiniMax") }
        guard response.status == 200 else { throw PlanError.unavailable("MiniMax returned \(response.status)") }
        return try Self.parse(response.data)
    }

    /// `model_remains[]` counts what is *left*: `current_interval_usage_count` is the remaining
    /// prompts out of `current_interval_total_count`, despite its name.
    static func parse(_ data: Data, now: Date = Date()) throws -> PlanSnapshot {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw PlanError.unavailable("Unreadable MiniMax response")
        }
        if let base = root["base_resp"] as? [String: Any], let status = PlanJSON.double(base["status_code"]), status != 0 {
            // 1004: missing or invalid credentials; 2049: invalid API key.
            if status == 1004 || status == 2049 { throw PlanError.signedOut("Key rejected by MiniMax") }
            throw PlanError.unavailable((base["status_msg"] as? String) ?? "MiniMax usage unavailable")
        }
        let remains = (root["model_remains"] ?? (root["data"] as? [String: Any])?["model_remains"]) as? [[String: Any]]
        guard let first = remains?.first else { throw PlanError.noSubscription }
        var windows: [UsageWindow] = []
        if let window = window(first, id: "minimax-interval", total: "current_interval_total_count", left: "current_interval_usage_count",
                               leftPercent: "current_interval_remaining_percent", start: "start_time", end: "end_time", remains: "remains_time",
                               fallbackMinutes: 300, now: now) {
            windows.append(window)
        }
        if let window = window(first, id: "minimax-week", total: "current_weekly_total_count", left: "current_weekly_usage_count",
                               leftPercent: "current_weekly_remaining_percent", start: "weekly_start_time", end: "weekly_end_time", remains: "weekly_remains_time",
                               fallbackMinutes: 10_080, now: now) {
            windows.append(window)
        }
        guard !windows.isEmpty else { throw PlanError.noSubscription }
        return PlanSnapshot(plan: nil, windows: windows)
    }

    private static func window(
        _ entry: [String: Any], id: String, total: String, left: String, leftPercent: String,
        start: String, end: String, remains: String, fallbackMinutes: Int, now: Date
    ) -> UsageWindow? {
        let percent: Double
        if let total = PlanJSON.double(entry[total]), total > 0, let left = PlanJSON.double(entry[left]) {
            percent = (total - left) / total * 100
        } else if let leftPercent = PlanJSON.double(entry[leftPercent]) {
            percent = 100 - leftPercent
        } else {
            return nil
        }
        let startDate = PlanJSON.date(entry[start])
        let endDate = PlanJSON.date(entry[end])
        let reset = endDate.flatMap { $0 > now ? $0 : nil } ?? PlanJSON.double(entry[remains]).flatMap { remaining in
            remaining > 0 ? now.addingTimeInterval(remaining > 1_000_000 ? remaining / 1000 : remaining) : nil
        }
        let minutes = startDate.flatMap { start in endDate.map { Int($0.timeIntervalSince(start) / 60) } }.flatMap { $0 > 0 ? $0 : nil } ?? fallbackMinutes
        return UsageWindow(id: id, label: PlanJSON.label(minutes: minutes), percent: percent, resetsAt: reset, duration: TimeInterval(minutes * 60))
    }
}
