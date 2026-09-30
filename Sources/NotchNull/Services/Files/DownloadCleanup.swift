import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

/// How long a download stays before it goes to the Trash.
enum KeepChoice: String, CaseIterable, Identifiable, Codable {
    case tenMinutes, hour, day, week, month, forever

    var id: String { rawValue }

    /// The stops on the timeline, shortest first; `forever` is the separate Keep button.
    static let timed: [KeepChoice] = [.tenMinutes, .hour, .day, .week, .month]

    var duration: TimeInterval? {
        switch self {
        case .tenMinutes: 10 * 60
        case .hour: 3600
        case .day: 86_400
        case .week: 7 * 86_400
        case .month: 30 * 86_400
        case .forever: nil
        }
    }

    var short: String {
        switch self {
        case .tenMinutes: "10m"
        case .hour: "1h"
        case .day: "1d"
        case .week: "1w"
        case .month: "30d"
        case .forever: "Keep"
        }
    }

    var title: String {
        switch self {
        case .tenMinutes: "10 minutes"
        case .hour: "1 hour"
        case .day: "1 day"
        case .week: "1 week"
        case .month: "30 days"
        case .forever: "Keep forever"
        }
    }
}

/// A download NotchNull is looking after. The bookmark follows the file through renames and
/// moves, so the right file is trashed even if its name changes.
struct TrackedDownload: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var bookmark: Data
    var addedAt: Date
    var size: Int64
    var source: String?
    /// Nil while the notch is still asking.
    var expiresAt: Date?

    var fileExtension: String { (name as NSString).pathExtension.lowercased() }
    var kind: DownloadKind { DownloadKind(fileExtension: fileExtension) }
}

/// A file trashed recently enough to put back.
struct TrashedDownload: Equatable {
    let name: String
    let original: URL
    let trashed: URL
    let at: Date
}

/// Families of files with their own glyph and tint, so a glance tells an installer from a photo.
enum DownloadKind: Equatable {
    case image, movie, audio, pdf, archive, installer, code, document, other

    init(fileExtension ext: String) {
        switch ext {
        case "dmg", "pkg", "mpkg", "iso", "app": self = .installer
        case "zip", "tar", "gz", "tgz", "bz2", "xz", "rar", "7z", "zst": self = .archive
        case "pdf": self = .pdf
        case "js", "ts", "tsx", "jsx", "py", "swift", "rs", "go", "c", "h", "cpp", "java", "kt", "rb", "sh", "json", "yml", "yaml", "toml", "html", "css", "ino", "bin", "hex":
            self = .code
        default:
            guard let type = UTType(filenameExtension: ext) else { self = .other; return }
            if type.conforms(to: .image) { self = .image }
            else if type.conforms(to: .movie) || type.conforms(to: .video) { self = .movie }
            else if type.conforms(to: .audio) { self = .audio }
            else if type.conforms(to: .text) || type.conforms(to: .spreadsheet) || type.conforms(to: .presentation) || type.conforms(to: .compositeContent) { self = .document }
            else { self = .other }
        }
    }

    var symbol: String {
        switch self {
        case .image: "photo.fill"
        case .movie: "film.fill"
        case .audio: "waveform"
        case .pdf: "doc.richtext.fill"
        case .archive: "archivebox.fill"
        case .installer: "shippingbox.fill"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .document: "doc.text.fill"
        case .other: "doc.fill"
        }
    }

    var tint: Color {
        switch self {
        case .image: Theme.Accent.mirror
        case .movie: Theme.Accent.tray
        case .audio: Theme.Accent.music
        case .pdf: Theme.Accent.danger
        case .archive: Theme.Accent.timer
        case .installer: Theme.Accent.warning
        case .code: Theme.Accent.copy
        case .document: Theme.Accent.airdrop
        case .other: Theme.Accent.system
        }
    }
}

/// Downloads that clean up after themselves: a new file in ~/Downloads makes the notch ask how
/// long to keep it; when the time is up the file goes to the Trash, and can be put back.
@MainActor
final class DownloadCleanup: ObservableObject {
    /// Files waiting for an answer, oldest first. The notch asks about the first one.
    @Published private(set) var pending: [TrackedDownload] = []
    /// Files with a deadline, soonest first.
    @Published private(set) var expiring: [TrackedDownload] = []
    @Published private(set) var lastTrashed: TrashedDownload?
    /// The stop highlighted on the timeline for the file being asked about.
    @Published var draft: KeepChoice = .day

    private var timer: Timer?
    private var restoredName: String?
    private var cancellables: Set<AnyCancellable> = []
    private let preferences = Preferences.shared

    func start() {
        load()
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.sweep() }
            .store(in: &cancellables)
        // Overdue files go right after launch, even if the Mac slept or the app was quit.
        sweep()
    }

    /// Fixture entry point for snapshot rendering.
    func preview(pending: [TrackedDownload], expiring: [TrackedDownload], trashed: TrashedDownload? = nil, draft: KeepChoice = .day) {
        self.pending = pending
        self.expiring = expiring
        self.lastTrashed = trashed
        self.draft = draft
    }

    // MARK: New files

    /// Called when a file finishes arriving in ~/Downloads. Returns false when the regular
    /// "Downloaded" banner should show instead: cleanup is off, or a rule already decided (the
    /// banner then says when the file goes).
    @discardableResult
    func offer(_ url: URL) -> Bool {
        // A file put back from the Trash reappears in Downloads; it is not a new download.
        if url.lastPathComponent == restoredName {
            restoredName = nil
            return true
        }
        guard preferences.downloadCleanupEnabled else { return false }
        guard !pending.contains(where: { $0.name == url.lastPathComponent }),
              let tracked = Self.track(url) else { return false }
        if let rule = preferences.downloadRules[tracked.fileExtension].flatMap(KeepChoice.init(rawValue:)) {
            apply(rule, to: tracked)
            return false
        }
        pending.append(tracked)
        if pending.count == 1 { ask() }
        return true
    }

    /// The notch shows the question; nothing else is decided until the user answers or it times out.
    private func ask() {
        guard let first = pending.first else {
            ActivityCenter.shared.dismiss(.downloadKeep)
            return
        }
        draft = preferences.downloadRules[first.fileExtension].flatMap(KeepChoice.init(rawValue:)) ?? preferences.downloadDefaultChoice
        ActivityCenter.shared.post(.downloadKeep, for: Constants.Durations.downloadKeep)
        scheduleUnansweredFallback(for: first.id)
    }

    /// Keeps the question up while the pointer is on it.
    func hold() {
        guard let first = pending.first else { return }
        ActivityCenter.shared.post(.downloadKeep, for: Constants.Durations.downloadKeep)
        scheduleUnansweredFallback(for: first.id)
    }

    private var fallbackWork: DispatchWorkItem?

    private func scheduleUnansweredFallback(for id: UUID) {
        fallbackWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.pending.first?.id == id else { return }
                // No answer: keep the file unless the user opted into the highlighted stop.
                self.answer(self.preferences.downloadUnansweredUsesDefault ? self.draft : .forever)
            }
        }
        fallbackWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Durations.downloadKeep - 0.2, execute: work)
    }

    /// Answers the question about the first pending file; `remember` makes it the rule for its type.
    func answer(_ choice: KeepChoice, remember: Bool = false) {
        guard !pending.isEmpty else { return }
        let file = pending.removeFirst()
        if remember, !file.fileExtension.isEmpty {
            preferences.downloadRules[file.fileExtension] = choice.rawValue
        }
        apply(choice, to: file)
        fallbackWork?.cancel()
        ask()
    }

    // MARK: Deadlines

    private func apply(_ choice: KeepChoice, to file: TrackedDownload) {
        guard let duration = choice.duration else {
            setTemporaryTag(false, on: file)
            expiring.removeAll { $0.id == file.id }
            save()
            return
        }
        var file = file
        file.expiresAt = Date().addingTimeInterval(duration)
        expiring.removeAll { $0.id == file.id }
        expiring.append(file)
        expiring.sort { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
        setTemporaryTag(true, on: file)
        save()
        schedule()
    }

    /// Changes the deadline of a file already counting down.
    func change(_ file: TrackedDownload, to choice: KeepChoice) {
        withAnimation(Motion.state) { apply(choice, to: file) }
    }

    func trashNow(_ file: TrackedDownload) {
        trash(file)
        expiring.removeAll { $0.id == file.id }
        save()
        schedule()
    }

    private func schedule() {
        timer?.invalidate()
        let soonest = expiring.compactMap(\.expiresAt).min()
        updateCountdownActivity(soonest)
        guard let soonest else { return }
        // Wake at the deadline, or when the last-seconds countdown should appear in the notch.
        let countdownStart = soonest.addingTimeInterval(-Constants.Durations.downloadCountdown)
        let next = countdownStart > Date() ? countdownStart : soonest
        timer = Timer.scheduledTimer(withTimeInterval: max(0.2, next.timeIntervalSinceNow), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.sweep() }
        }
    }

    private func updateCountdownActivity(_ soonest: Date?) {
        let showing = soonest.map { $0.timeIntervalSinceNow <= Constants.Durations.downloadCountdown } ?? false
        ActivityCenter.shared.setPersistent(.downloadExpiring, active: showing)
    }

    /// Trashes everything past its deadline.
    func sweep() {
        let now = Date()
        let due = expiring.filter { ($0.expiresAt ?? .distantFuture) <= now }
        for file in due { trash(file) }
        if !due.isEmpty {
            expiring.removeAll { file in due.contains { $0.id == file.id } }
            save()
        }
        schedule()
    }

    private func trash(_ file: TrackedDownload) {
        guard let url = Self.resolve(file) else {
            Log.files.info("Expired download is gone already: \(file.name, privacy: .private)")
            return
        }
        // Files the user moved out of Downloads are theirs now.
        guard url.standardizedFileURL.path.hasPrefix(Constants.Paths.downloads.standardizedFileURL.path + "/") else {
            Log.files.info("Expired download left ~/Downloads; leaving it alone")
            return
        }
        do {
            setTemporaryTag(false, on: file)
            var trashedURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
            let record = TrashedDownload(name: url.lastPathComponent, original: url, trashed: (trashedURL as URL?) ?? url, at: Date())
            withAnimation(Motion.state) { lastTrashed = record }
            ActivityCenter.shared.post(.downloadTrashed, for: Constants.Durations.downloadTrashed)
            ActivityLog.shared.add(symbol: "trash.fill", tint: Theme.Accent.system, title: "Moved to Trash", detail: record.name, action: .reveal(record.trashed))
            Log.files.info("Expired download moved to Trash")
        } catch {
            Log.files.error("Could not trash expired download: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Puts the most recently trashed file back where it was.
    func undoTrash() {
        guard let record = lastTrashed else { return }
        let fm = FileManager.default
        var destination = record.original
        if fm.fileExists(atPath: destination.path) {
            let base = destination.deletingPathExtension().lastPathComponent
            let ext = destination.pathExtension
            destination = destination.deletingLastPathComponent().appendingPathComponent("\(base) (restored)" + (ext.isEmpty ? "" : ".\(ext)"))
        }
        do {
            restoredName = destination.lastPathComponent
            try fm.moveItem(at: record.trashed, to: destination)
            withAnimation(Motion.state) { lastTrashed = nil }
            ActivityCenter.shared.dismiss(.downloadTrashed)
        } catch {
            Log.files.error("Could not put the download back: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Files

    private static func track(_ url: URL) -> TrackedDownload? {
        guard let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else { return nil }
        let size = (try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])).flatMap { $0.fileSize ?? $0.totalFileAllocatedSize } ?? 0
        return TrackedDownload(id: UUID(), name: url.lastPathComponent, bookmark: bookmark, addedAt: Date(), size: Int64(size), source: whereFrom(url))
    }

    static func resolve(_ file: TrackedDownload) -> URL? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: file.bookmark, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// The site a browser recorded for the file (the same "Where from" Finder shows).
    private static func whereFrom(_ url: URL) -> String? {
        let name = "com.apple.metadata:kMDItemWhereFroms"
        let length = getxattr(url.path, name, nil, 0, 0, 0)
        guard length > 0 else { return nil }
        var data = Data(count: length)
        let read = data.withUnsafeMutableBytes { getxattr(url.path, name, $0.baseAddress, length, 0, 0) }
        guard read > 0,
              let list = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String] else { return nil }
        let host = list.lazy.compactMap { URL(string: $0)?.host }.first { !$0.isEmpty }
        return host.map { $0.hasPrefix("www.") ? String($0.dropFirst(4)) : $0 }
    }

    /// Optional Finder "Temporary" tag so the countdown is visible outside the notch too.
    private func setTemporaryTag(_ on: Bool, on file: TrackedDownload) {
        guard preferences.downloadTagTemporary, let url = Self.resolve(file) else { return }
        let tag = "Temporary"
        var tags = (try? url.resourceValues(forKeys: [.tagNamesKey]))?.tagNames ?? []
        guard on != tags.contains(tag) else { return }
        if on { tags.append(tag) } else { tags.removeAll { $0 == tag } }
        try? (url as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
    }

    // MARK: Persistence

    private struct Store: Codable {
        var expiring: [TrackedDownload]
    }

    private static var storeURL: URL { Constants.Paths.support.appendingPathComponent("download-cleanup.json") }

    private func load() {
        guard let data = try? Data(contentsOf: Self.storeURL),
              let store = try? JSONDecoder().decode(Store.self, from: data) else { return }
        expiring = store.expiring.sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(Store(expiring: expiring)) else { return }
        try? data.write(to: Self.storeURL, options: .atomic)
    }
}
