import Foundation

/// Metadata only, confined to the monitor's serial queue. FSEvents invalidates it;
/// the periodic rebuild is a backstop for dropped events or a newly created root.
final class TranscriptFileIndex {
    typealias Entry = (url: URL, modified: Date)
    private var entries: [Entry] = []
    private var refreshedAt: Date?

    func invalidate() { refreshedAt = nil }

    func files(since cutoff: Date, now: Date = Date(), load: () -> [Entry]) -> [URL] {
        if refreshedAt.map({ now.timeIntervalSince($0) < Constants.Agents.fileIndexRefresh && now >= $0 }) != true {
            entries = load().sorted { $0.modified > $1.modified }
            refreshedAt = now
        }
        return entries.lazy.filter { $0.modified >= cutoff }.map(\.url)
    }
}
