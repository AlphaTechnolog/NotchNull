import Combine
import Foundation
import SwiftUI

/// Today's Claude Code token totals from local transcripts (~/.claude/projects/**/*.jsonl),
/// read incrementally. Messages are de-duplicated by API message id.
@MainActor
final class ClaudeTokenStats: ObservableObject {
    @Published private(set) var tokens = TokenTally()

    private let queue = DispatchQueue(label: "dev.notchnull.claude-tokens", qos: .utility)
    private nonisolated(unsafe) let reader = JSONLTailReader()
    private var timer: Timer?
    private nonisolated(unsafe) var tally = TokenTally()
    private nonisolated(unsafe) var seen: Set<String> = []
    private nonisolated(unsafe) var day = Calendar.current.startOfDay(for: Date())

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: Constants.Agents.tokenStatsInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    /// Fixture entry point for snapshot rendering.
    func preview(_ tokens: TokenTally) { self.tokens = tokens }

    func refresh() {
        queue.async { [weak self] in
            guard let self else { return }
            let result = self.scan()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if result != self.tokens { withAnimation(Motion.state) { self.tokens = result } }
                }
            }
        }
    }

    private nonisolated func scan() -> TokenTally {
        let today = Calendar.current.startOfDay(for: Date())
        if today != day {
            day = today
            tally = TokenTally()
            seen.removeAll()
        }
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: Constants.Paths.claudeProjects,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return tally }
        let marker = ["\"usage\"".utf8Data]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for case let file as URL in enumerator where file.pathExtension == "jsonl" {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            guard modified >= today else { continue }
            reader.readNewLines(of: file, markers: marker) { line in
                guard let json = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                      let stamp = json["timestamp"] as? String,
                      let date = formatter.date(from: stamp), date >= today,
                      let message = json["message"] as? [String: Any],
                      let usage = message["usage"] as? [String: Any] else { return }
                let key = (message["id"] as? String) ?? (json["requestId"] as? String) ?? (json["uuid"] as? String) ?? UUID().uuidString
                guard seen.insert(key).inserted else { return }
                let value: (String) -> Int = { (usage[$0] as? NSNumber)?.intValue ?? 0 }
                let output = value("output_tokens")
                let total = value("input_tokens") + output + value("cache_creation_input_tokens") + value("cache_read_input_tokens")
                tally.today += total
                tally.output += output
                tally.messages += 1
                tally.hourly[Calendar.current.component(.hour, from: date)] += total
            }
        }
        return tally
    }
}
