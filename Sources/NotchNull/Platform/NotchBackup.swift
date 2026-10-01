import Foundation

/// Copies of the files you own in ~/.notchnull (settings.json, widgets, presets, themes, scripts),
/// kept in ~/.notchnull/backups. One is taken the first time a new version runs, before that
/// version rewrites settings.json, and before anything replaces your files in bulk (applying a
/// preset or a shared notch, restoring another backup). `notchnull restore` puts one back.
enum NotchBackup {
    struct Entry: Equatable {
        let id: String
        let url: URL
    }

    enum BackupError: LocalizedError {
        case notFound(String)
        case empty

        var errorDescription: String? {
            switch self {
            case .notFound(let id): "No backup named \(id). `notchnull backups` lists them."
            case .empty: "There are no backups yet. `notchnull backup` makes one."
            }
        }
    }

    static var root: URL { NotchHome.root.appendingPathComponent("backups", isDirectory: true) }

    /// What a backup holds: everything in ~/.notchnull the app does not generate.
    static let items = ["settings.json", "widgets", "presets", "themes", "scripts"]

    private static let lastRunVersionKey = "lastRunVersion"

    /// Newest first; the id starts with the time it was taken.
    static func list(in folder: URL = root) -> [Entry] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { !$0.hasPrefix(".") }.sorted(by: >).map { Entry(id: $0, url: folder.appendingPathComponent($0, isDirectory: true)) }
    }

    /// Copies your files into a new backup. Nil when there is nothing to copy yet.
    @discardableResult
    static func create(reason: String, from home: URL = NotchHome.root, in folder: URL = root, now: Date = Date()) throws -> Entry? {
        let fm = FileManager.default
        let present = items.filter { fm.fileExists(atPath: home.appendingPathComponent($0).path) }
        guard !present.isEmpty else { return nil }
        let id = identifier(reason: reason, now: now, taken: Set(list(in: folder).map(\.id)))
        let destination = folder.appendingPathComponent(id, isDirectory: true)
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        for item in present {
            try fm.copyItem(at: home.appendingPathComponent(item), to: destination.appendingPathComponent(item))
        }
        prune(in: folder)
        return Entry(id: id, url: destination)
    }

    /// Puts a backup's files back (the newest when `id` is nil). What you have now is backed up
    /// first, and files the backup does not hold are left where they are.
    @discardableResult
    static func restore(_ id: String?, to home: URL = NotchHome.root, in folder: URL = root, now: Date = Date()) throws -> Entry {
        let entries = list(in: folder)
        guard let entry = id.map({ wanted in entries.first { $0.id == wanted } }) ?? entries.first else {
            throw id.map(BackupError.notFound) ?? BackupError.empty
        }
        try create(reason: "before-restore", from: home, in: folder, now: now)
        let fm = FileManager.default
        for item in items {
            let source = entry.url.appendingPathComponent(item)
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: source.path, isDirectory: &isDirectory) else { continue }
            let target = home.appendingPathComponent(item)
            guard isDirectory.boolValue else {
                try Data(contentsOf: source).write(to: target, options: .atomic)
                continue
            }
            try fm.createDirectory(at: target, withIntermediateDirectories: true)
            for name in (try? fm.contentsOfDirectory(atPath: source.path)) ?? [] {
                let file = source.appendingPathComponent(name)
                guard (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
                try Data(contentsOf: file).write(to: target.appendingPathComponent(name), options: .atomic)
            }
        }
        return entry
    }

    /// Called at launch, before settings.json is read: the first run of a version keeps a copy
    /// of your files as the previous version left them.
    static func backupOnVersionChange(defaults: UserDefaults = .standard) {
        let current = AppVersion.current.description
        guard defaults.string(forKey: lastRunVersionKey) != current else { return }
        do {
            if let entry = try create(reason: "before-\(current)") {
                Log.app.info("Backed up ~/.notchnull as \(entry.id, privacy: .public)")
            }
            defaults.set(current, forKey: lastRunVersionKey)
        } catch {
            Log.app.error("Could not back up ~/.notchnull: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// `2026-10-01T09-10-22-before-1.4.0`: sorts by time and says why it was taken.
    static func identifier(reason: String, now: Date, taken: Set<String> = []) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
        let slug = String(reason.lowercased().map { $0.isLetter || $0.isNumber || $0 == "." ? $0 : "-" })
            .split(separator: "-").joined(separator: "-")
        let base = slug.isEmpty ? formatter.string(from: now) : "\(formatter.string(from: now))-\(slug)"
        var id = base
        var copy = 2
        while taken.contains(id) {
            id = "\(base)-\(copy)"
            copy += 1
        }
        return id
    }

    /// Taken because a new version ran, not because something was applied or asked for.
    static func isVersionBackup(_ id: String) -> Bool {
        id.range(of: #"-before-\d+(\.\d+)*$"#, options: .regularExpression) != nil
    }

    /// Older backups beyond the limit go to the Trash, never straight to deletion. Version
    /// backups are counted apart, so a run of applied presets cannot push them out.
    private static func prune(in folder: URL) {
        let entries = list(in: folder)
        let expired = entries.filter { isVersionBackup($0.id) }.dropFirst(Constants.Limits.backups)
            + entries.filter { !isVersionBackup($0.id) }.dropFirst(Constants.Limits.backups)
        for entry in expired {
            try? FileManager.default.trashItem(at: entry.url, resultingItemURL: nil)
        }
    }
}
