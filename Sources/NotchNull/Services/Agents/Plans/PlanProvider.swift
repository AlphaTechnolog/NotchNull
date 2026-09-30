import Foundation
import SwiftUI

/// A coding subscription besides Claude and Codex (GLM Coding Plan, Kimi Code, OpenCode Go…).
/// Each provider finds a key the user already configured for their tools and reads the limits
/// from the provider's own usage endpoint. Adding a provider is one file plus its entry in
/// `PlanProviders.all`.
protocol PlanProvider: Sendable {
    var id: String { get }
    var title: String { get }
    /// One or two letters on the provider's tile; no brand logos are bundled for these.
    var monogram: String { get }
    var tint: Color { get }
    /// The first key found for this provider, or nil when none is configured on this Mac.
    func credential(in sources: PlanCredentialSources) -> PlanCredential?
    func fetch(_ credential: PlanCredential) async throws -> PlanSnapshot
}

struct PlanCredential: Equatable, Sendable {
    let key: String
    /// Where the key was found, shown in Settings (e.g. "OpenCode", "Claude Code settings").
    let source: String
    /// The provider's regional host, when the key's origin says which one.
    var host: String?
}

struct PlanSnapshot: Equatable, Sendable {
    var plan: String?
    var windows: [UsageWindow]
}

enum PlanError: Error, Equatable {
    /// The key was rejected.
    case signedOut(String)
    /// The key works, but the account has no subscription with limits; the provider stays hidden.
    case noSubscription
    case unavailable(String)
}

/// Registry of every subscription NotchNull can read.
enum PlanProviders {
    static let all: [any PlanProvider] = [ZaiPlan(), KimiPlan(), MiniMaxPlan(), OpenCodeGoPlan(), CopilotPlan()]
}

/// A subscription's latest limits, as the Agents tab shows them.
struct PlanUsage: Identifiable, Equatable {
    let id: String
    let title: String
    let monogram: String
    let tint: Color
    let source: String
    var plan: String?
    var windows: [UsageWindow] = []
    var updatedAt: Date?
    var state: ProviderUsage.State = .loading
}

/// Small JSON-over-HTTPS helper shared by the plan providers.
enum PlanHTTP {
    struct Response {
        let status: Int
        let data: Data
        var json: [String: Any]? { (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] }
    }

    static func get(_ url: URL, bearer: String, headers: [String: String] = [:]) async throws -> Response {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("NotchNull/1.0", forHTTPHeaderField: "User-Agent")
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return Response(status: (response as? HTTPURLResponse)?.statusCode ?? 0, data: data)
        } catch {
            throw PlanError.unavailable("Offline")
        }
    }
}

/// Lenient readers for the providers' JSON, which mixes numbers and numeric strings.
enum PlanJSON {
    static func double(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber: number.doubleValue
        case let string as String: Double(string.trimmingCharacters(in: .whitespaces))
        default: nil
        }
    }

    /// Epoch seconds or milliseconds, or an ISO 8601 string.
    static func date(_ value: Any?) -> Date? {
        if let string = value as? String, Double(string) == nil {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) { return date }
            formatter.formatOptions = [.withFullDate]
            return formatter.date(from: string)
        }
        guard let raw = double(value) else { return nil }
        if raw > 1_000_000_000_000 { return Date(timeIntervalSince1970: raw / 1000) }
        if raw > 1_000_000_000 { return Date(timeIntervalSince1970: raw) }
        return nil
    }

    /// "5 hours", "Week", "Month" or "3 days" for a window length.
    static func label(minutes: Int) -> String {
        switch minutes {
        case 300: "5 hours"
        case 10_080: "Week"
        case 43_200...44_640: "Month"
        case let value where value % 1440 == 0: "\(value / 1440) days"
        case let value where value % 60 == 0: "\(value / 60) hours"
        default: "\(minutes) min"
        }
    }
}
