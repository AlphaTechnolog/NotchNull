import Foundation
import SwiftUI

/// GitHub Copilot: the monthly premium-request allowance, read with the GitHub sign-in the Copilot
/// editor plugins (or OpenCode) already saved.
struct CopilotPlan: PlanProvider {
    let id = "copilot"
    let title = "GitHub Copilot"
    let monogram = "Co"
    var tint: Color { Theme.Accent.copilot }

    func credential(in sources: PlanCredentialSources) -> PlanCredential? {
        if let token = sources.copilotTokens.first {
            return PlanCredential(key: token, source: "Copilot sign-in")
        }
        if let token = sources.openCode["github-copilot"]?["refresh"], !token.isEmpty {
            return PlanCredential(key: token, source: "OpenCode")
        }
        return nil
    }

    func fetch(_ credential: PlanCredential) async throws -> PlanSnapshot {
        var request = URLRequest(url: URL(string: "https://api.github.com/copilot_internal/user")!, timeoutInterval: 15)
        // This endpoint takes the GitHub OAuth token with the `token` scheme, as the editor plugins send it.
        request.setValue("token \(credential.key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("NotchNull/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("2025-04-01", forHTTPHeaderField: "X-GitHub-Api-Version")
        let status: Int
        let data: Data
        do {
            let (body, response) = try await URLSession.shared.data(for: request)
            status = (response as? HTTPURLResponse)?.statusCode ?? 0
            data = body
        } catch {
            throw PlanError.unavailable("Offline")
        }
        if status == 401 { throw PlanError.signedOut("Sign in to Copilot again in your editor") }
        if status == 403 || status == 404 { throw PlanError.noSubscription }
        guard status == 200 else { throw PlanError.unavailable("GitHub returned \(status)") }
        return try Self.parse(data)
    }

    /// `quota_snapshots.premium_interactions` (and `chat` on free plans) with `percent_remaining`;
    /// unlimited quotas are skipped. Everything resets on `quota_reset_date`, monthly.
    static func parse(_ data: Data) throws -> PlanSnapshot {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw PlanError.unavailable("Unreadable Copilot response")
        }
        let reset = PlanJSON.date(root["quota_reset_date"] ?? root["quota_reset_date_utc"])
        let duration = reset.flatMap { date in Calendar.current.date(byAdding: .month, value: -1, to: date).map { date.timeIntervalSince($0) } }
        let snapshots = root["quota_snapshots"] as? [String: Any] ?? [:]
        let known: [(key: String, label: String)] = [("premium_interactions", "Premium"), ("chat", "Chat"), ("completions", "Code")]
        let windows = known.compactMap { entry -> UsageWindow? in
            guard let quota = snapshots[entry.key] as? [String: Any], quota["unlimited"] as? Bool != true else { return nil }
            let left: Double
            if let percent = PlanJSON.double(quota["percent_remaining"]) {
                left = percent
            } else if let total = PlanJSON.double(quota["entitlement"]), total > 0, let remaining = PlanJSON.double(quota["remaining"]) {
                left = remaining / total * 100
            } else {
                return nil
            }
            return UsageWindow(id: "copilot-\(entry.key)", label: entry.label, percent: 100 - left, resetsAt: reset, duration: duration)
        }
        guard !windows.isEmpty else { throw PlanError.noSubscription }
        let plan = (root["copilot_plan"] as? String).map { $0.replacingOccurrences(of: "_", with: " ").capitalized }
        return PlanSnapshot(plan: plan, windows: windows)
    }
}
