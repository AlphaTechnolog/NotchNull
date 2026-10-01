import AppKit
import Combine
import SwiftUI

struct ActiveDownload: Identifiable, Equatable {
    let id: String
    let name: String
    var bytes: Int64
    var total: Int64?
    var bytesPerSecond: Double
    var updatedAt: Date

    var fraction: Double? {
        guard let total, total > 0 else { return nil }
        return min(1, Double(bytes) / Double(total))
    }
}

/// In-progress browser downloads in ~/Downloads (Safari .download bundles, Chromium .crdownload,
/// Firefox .part). Safari exposes the expected size; others show transferred size and speed.
@MainActor
final class DownloadWatcher: ObservableObject {
    @Published private(set) var active: [ActiveDownload] = []
    @Published private(set) var finished: URL?

    private static let partialExtensions: Set<String> = ["download", "crdownload", "part", "opdownload"]
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: Int32 = -1
    private var pollTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    /// Finished entries already seen; nil until the first scan, which only takes stock.
    private var known: Set<String>?
    /// A finished file arrived. Returning true means the handler shows its own notch activity
    /// (download cleanup asking how long to keep it) instead of the "Downloaded" banner.
    var onFinished: ((URL) -> Bool)?

    func start() {
        Preferences.shared.$downloadsEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in enabled ? self?.watch() : self?.unwatch() }
            .store(in: &cancellables)
    }

    /// Fixture entry point for snapshot rendering.
    func preview(active: [ActiveDownload], finished: URL?) {
        self.active = active
        self.finished = finished
    }

    private func watch() {
        guard source == nil else { return }
        descriptor = open(Constants.Paths.downloads.path, O_EVTONLY)
        guard descriptor >= 0 else {
            Log.files.notice("Downloads folder not readable yet")
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.scan() } }
        source.setCancelHandler { [descriptor] in close(descriptor) }
        source.resume()
        self.source = source
        scan()
    }

    private func unwatch() {
        source?.cancel()
        source = nil
        pollTimer?.invalidate()
        pollTimer = nil
        active = []
        known = nil
        ActivityCenter.shared.setPersistent(.download, active: false)
    }

    private func scan() {
        let fm = FileManager.default
        let folder = Constants.Paths.downloads
        let entries = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])) ?? []
        let partials = entries.filter { Self.partialExtensions.contains($0.pathExtension.lowercased()) }
        let now = Date()
        var next: [ActiveDownload] = []
        // A cancelled download can leave its partial behind for good, and a paused one sits
        // there untouched; neither is downloading, so only partials still being written count.
        let live = partials.filter { !Self.isStalled(modified: Self.lastWrite(of: $0), now: now) }
        for url in live {
            let (bytes, total) = Self.measure(url)
            let id = url.lastPathComponent
            let finalName = url.deletingPathExtension().lastPathComponent
            var download = ActiveDownload(id: id, name: finalName, bytes: bytes, total: total, bytesPerSecond: 0, updatedAt: now)
            if let previous = active.first(where: { $0.id == id }) {
                let seconds = now.timeIntervalSince(previous.updatedAt)
                if seconds > 0.2 {
                    let instant = Double(max(0, bytes - previous.bytes)) / seconds
                    download.bytesPerSecond = previous.bytesPerSecond * 0.6 + instant * 0.4
                } else {
                    download.bytesPerSecond = previous.bytesPerSecond
                    download.updatedAt = previous.updatedAt
                    download.bytes = max(bytes, previous.bytes)
                }
            }
            next.append(download)
        }

        // Any new finished entry is a download: a partial renamed to its final name, or a file
        // saved straight into Downloads. Firefox keeps an empty placeholder beside its .part
        // file, so a name whose partial is still growing waits until the partial is gone.
        let growing = Set(partials.map { $0.deletingPathExtension().lastPathComponent })
        let finals = entries.filter { !partials.contains($0) && !$0.lastPathComponent.hasPrefix(".") }
        let names = Set(finals.map(\.lastPathComponent))
        if let known {
            for url in finals where !known.contains(url.lastPathComponent) && !growing.contains(url.lastPathComponent) {
                announce(url)
            }
        }
        known = names.subtracting(growing)

        if next != active { withAnimation(Motion.value) { active = next } }
        ActivityCenter.shared.setPersistent(.download, active: !next.isEmpty)
        // Writes inside a partial do not touch the folder, so a stalled one is still polled,
        // slowly, to notice when it resumes.
        let interval: TimeInterval? = !next.isEmpty ? Constants.Intervals.downloadPoll
            : partials.isEmpty ? nil : Constants.Intervals.downloadStalledPoll
        guard pollTimer?.timeInterval != interval else { return }
        pollTimer?.invalidate()
        pollTimer = interval.map {
            Timer.scheduledTimer(withTimeInterval: $0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.scan() }
            }
        }
    }

    nonisolated static func isStalled(modified: Date?, now: Date) -> Bool {
        guard let modified else { return false }
        return now.timeIntervalSince(modified) > Constants.Durations.downloadStalled
    }

    /// Latest write to a partial; a Safari bundle is as fresh as the newest file inside it.
    private static func lastWrite(of url: URL) -> Date? {
        let key: URLResourceKey = .contentModificationDateKey
        let inside = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [key])) ?? []
        return ([url] + inside).compactMap { try? $0.resourceValues(forKeys: [key]).contentModificationDate }.max()
    }

    private func announce(_ url: URL) {
        withAnimation(Motion.state) { finished = url }
        ActivityLog.shared.add(symbol: "arrow.down.circle.fill", tint: Theme.Accent.download, title: "Downloaded", detail: url.lastPathComponent, action: .reveal(url))
        if onFinished?(url) != true {
            ActivityCenter.shared.post(.downloadDone, for: Constants.Durations.downloadDone)
        }
    }

    private static func measure(_ url: URL) -> (Int64, Int64?) {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard isDirectory.boolValue else {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return (Int64(size), nil)
        }
        // Safari bundle: Info.plist carries progress, the payload sits beside it.
        let info = url.appendingPathComponent("Info.plist")
        if let data = try? Data(contentsOf: info),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            let total = (plist["DownloadEntryProgressTotalToLoad"] as? NSNumber)?.int64Value
            let soFar = (plist["DownloadEntryProgressBytesSoFar"] as? NSNumber)?.int64Value
            let payload = directorySize(url)
            return (max(soFar ?? 0, payload), (total ?? 0) > 0 ? total : nil)
        }
        return (directorySize(url), nil)
    }

    private static func directorySize(_ url: URL) -> Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.filter { $0.lastPathComponent != "Info.plist" }
            .reduce(Int64(0)) { $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    var primary: ActiveDownload? { active.max { $0.bytes < $1.bytes } }
}
