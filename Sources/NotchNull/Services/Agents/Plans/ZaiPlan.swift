import Foundation
import SwiftUI

/// Z.ai / Zhipu GLM Coding Plan: 5-hour and weekly prompt limits plus the monthly MCP allowance,
/// from the same quota endpoint the Z.ai usage dashboard reads.
struct ZaiPlan: PlanProvider {
    let id = "zai"
    let title = "GLM Coding Plan"
    let monogram = "Z"
    var tint: Color { Theme.Accent.glm }

    static let globalHost = "api.z.ai"
    static let chinaHost = "open.bigmodel.cn"

    func credential(in sources: PlanCredentialSources) -> PlanCredential? {
        if let found = sources.env(["Z_AI_API_KEY", "ZAI_API_KEY"]) {
            return PlanCredential(key: found.value, source: found.name, host: Self.globalHost)
        }
        if let found = sources.env(["BIGMODEL_API_KEY", "ZHIPU_API_KEY", "ZHIPUAI_API_KEY", "GLM_API_KEY"]) {
            return PlanCredential(key: found.value, source: found.name, host: Self.chinaHost)
        }
        if let found = sources.openCodeKey(["zai-coding-plan", "zai"]) {
            return PlanCredential(key: found.key, source: "OpenCode", host: Self.globalHost)
        }
        if let found = sources.openCodeKey(["zhipuai-coding-plan", "zhipuai"]) {
            return PlanCredential(key: found.key, source: "OpenCode", host: Self.chinaHost)
        }
        if let found = sources.claudeKey(forHosts: [Self.globalHost, Self.chinaHost, "bigmodel.cn"]) {
            return PlanCredential(key: found.key, source: "Claude Code settings", host: found.host == Self.globalHost ? Self.globalHost : Self.chinaHost)
        }
        return nil
    }

    func fetch(_ credential: PlanCredential) async throws -> PlanSnapshot {
        let host = credential.host ?? Self.globalHost
        let response = try await PlanHTTP.get(URL(string: "https://\(host)/api/monitor/usage/quota/limit")!, bearer: credential.key)
        if response.status == 401 || response.status == 403 { throw PlanError.signedOut("Key rejected by Z.ai") }
        guard response.status == 200 else { throw PlanError.unavailable("Z.ai returned \(response.status)") }
        return try Self.parse(response.data)
    }

    /// Limits arrive as `data.limits[]`: `TOKENS_LIMIT` entries for prompt windows (`unit` 3 = hours,
    /// 1 = days, 6 = weeks, times `number`) and a `TIME_LIMIT` entry for the MCP allowance.
    static func parse(_ data: Data, now: Date = Date()) throws -> PlanSnapshot {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw PlanError.unavailable("Unreadable Z.ai response")
        }
        let code = PlanJSON.double(root["code"]).map(Int.init)
        guard root["success"] as? Bool == true, code == nil || code == 200 else {
            if code == 401 || code == 403 { throw PlanError.signedOut("Key rejected by Z.ai") }
            throw PlanError.unavailable((root["msg"] as? String) ?? "Z.ai usage unavailable")
        }
        guard let body = root["data"] as? [String: Any], let limits = body["limits"] as? [[String: Any]], !limits.isEmpty else {
            throw PlanError.noSubscription
        }
        let unitMinutes: [Int: Int] = [1: 1440, 3: 60, 5: 1, 6: 10_080]
        var prompts: [(minutes: Int?, window: UsageWindow)] = []
        var mcp: UsageWindow?
        for limit in limits {
            guard let type = limit["type"] as? String, let reported = PlanJSON.double(limit["percentage"]) else { continue }
            let unit = PlanJSON.double(limit["unit"]).map(Int.init)
            let number = PlanJSON.double(limit["number"]).map(Int.init) ?? 0
            let minutes = unit.flatMap { unitMinutes[$0] }.map { $0 * number }.flatMap { $0 > 0 ? $0 : nil }
            var percent = reported
            if let total = PlanJSON.double(limit["usage"]), total > 0 {
                if let remaining = PlanJSON.double(limit["remaining"]) {
                    percent = (total - remaining) / total * 100
                } else if let current = PlanJSON.double(limit["currentValue"]) {
                    percent = current / total * 100
                }
            }
            var reset = PlanJSON.date(limit["nextResetTime"])
            // A five-hour window cannot reset more than five hours out; don't guess a timezone fix.
            if minutes == 300, let date = reset, date > now.addingTimeInterval(5 * 3600 + 60) { reset = nil }
            switch type {
            case "TOKENS_LIMIT", "CREDIT_LIMIT":
                let label = minutes.map(PlanJSON.label(minutes:)) ?? "Prompts"
                prompts.append((minutes, UsageWindow(id: "zai-\(minutes ?? prompts.count)", label: label, percent: percent, resetsAt: reset, duration: minutes.map { TimeInterval($0 * 60) })))
            case "TIME_LIMIT":
                mcp = UsageWindow(id: "zai-mcp", label: "MCP", percent: percent, resetsAt: reset, duration: 30 * 86_400)
            default:
                continue
            }
        }
        let windows = prompts.sorted { ($0.minutes ?? .max) < ($1.minutes ?? .max) }.map(\.window) + (mcp.map { [$0] } ?? [])
        guard !windows.isEmpty else { throw PlanError.noSubscription }
        let plan = [body["planName"], body["plan"], body["packageName"], body["level"]].lazy.compactMap { $0 as? String }.first { !$0.isEmpty }
        return PlanSnapshot(plan: plan?.capitalized, windows: windows)
    }
}
