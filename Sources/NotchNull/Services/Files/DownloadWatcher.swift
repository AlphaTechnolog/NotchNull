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
        ActivityCenter.shared.setPersistent(.download, active: false)
    }

    private func scan() {
        let fm = FileManager.default
        let folder = Constants.Paths.downloads
        let entries = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])) ?? []
        let partials = entries.filter { Self.partialExtensions.contains($0.pathExtension.lowercased()) }
        let now = Date()
        var next: [ActiveDownload] = []
        for url in partials {
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

        // A partial that disappeared finished (or was cancelled): look for its final file.
        let vanished = active.filter { old in !next.contains { $0.id == old.id } }
        for download in vanished {
            let finalURL = folder.appendingPathComponent(download.name)
            if fm.fileExists(atPath: finalURL.path) {
                withAnimation(Motion.state) { finished = finalURL }
                ActivityCenter.shared.post(.downloadDone, for: Constants.Durations.downloadDone)
                ActivityLog.shared.add(symbol: "arrow.down.circle.fill", tint: Theme.Accent.download, title: "Downloaded", detail: download.name, action: .reveal(finalURL))
            }
        }

        if next != active { withAnimation(Motion.value) { active = next } }
        ActivityCenter.shared.setPersistent(.download, active: !next.isEmpty)
        if next.isEmpty {
            pollTimer?.invalidate()
            pollTimer = nil
        } else if pollTimer == nil {
            pollTimer = Timer.scheduledTimer(withTimeInterval: Constants.Intervals.downloadPoll, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.scan() }
            }
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
