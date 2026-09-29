import AppKit
import Combine
import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

struct TrayItem: Identifiable, Codable, Equatable {
    let id: UUID
    let url: URL
    /// True when the file lives in NotchNull's own storage (web images, screenshots copies).
    let owned: Bool
    let addedAt: Date

    var name: String { url.lastPathComponent }
    var exists: Bool { FileManager.default.fileExists(atPath: url.path) }
}

/// Files parked in the notch. Finder files are referenced in place; dropped data (web images,
/// text) is written into the app's Tray folder.
@MainActor
final class TrayStore: ObservableObject {
    @Published private(set) var items: [TrayItem] = []
    @Published private(set) var thumbnails: [UUID: NSImage] = [:]
    @Published private(set) var lastAdded: TrayItem?

    func start() {
        try? FileManager.default.createDirectory(at: Constants.Paths.tray, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: Constants.Paths.trayIndex),
           let saved = try? JSONDecoder().decode([TrayItem].self, from: data) {
            items = saved.filter(\.exists)
            items.forEach(loadThumbnail)
        }
    }

    func add(urls: [URL], announce: Bool = true) {
        let fresh = urls.filter { url in !items.contains { $0.url == url } }
        guard !fresh.isEmpty else { return }
        let added = fresh.map { TrayItem(id: UUID(), url: $0, owned: $0.path.hasPrefix(Constants.Paths.tray.path), addedAt: Date()) }
        withAnimation(Motion.state) {
            items.insert(contentsOf: added, at: 0)
            if items.count > Constants.Limits.trayItems {
                items.suffix(from: Constants.Limits.trayItems).forEach(discard)
                items = Array(items.prefix(Constants.Limits.trayItems))
            }
            lastAdded = added.first
        }
        added.forEach(loadThumbnail)
        persist()
        if announce { ActivityCenter.shared.post(.trayAdded, for: 2.2) }
    }

    /// Stores raw data (an image dragged from a browser, plain text) as a file in the Tray.
    func add(data: Data, suggestedName: String) -> URL? {
        let url = uniqueURL(named: suggestedName)
        do {
            try data.write(to: url)
            add(urls: [url])
            return url
        } catch {
            Log.files.error("Tray write failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func remove(_ item: TrayItem) {
        withAnimation(Motion.state) { items.removeAll { $0.id == item.id } }
        discard(item)
        thumbnails[item.id] = nil
        persist()
    }

    func clear() {
        items.forEach(discard)
        withAnimation(Motion.state) { items.removeAll() }
        thumbnails.removeAll()
        persist()
    }

    func open(_ item: TrayItem) { NSWorkspace.shared.open(item.url) }

    func reveal(_ item: TrayItem) { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }

    func copy(_ item: TrayItem) { Self.copyToPasteboard([item.url]) }

    func airDrop(_ items: [TrayItem]) { Self.airDrop(items.map(\.url)) }

    static func copyToPasteboard(_ urls: [URL]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
        if urls.count == 1, let type = UTType(filenameExtension: urls[0].pathExtension), type.conforms(to: .image),
           let image = NSImage(contentsOf: urls[0]) {
            pasteboard.writeObjects([image])
        }
    }

    static func airDrop(_ urls: [URL]) {
        guard let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: urls) else {
            NSSound.beep()
            return
        }
        NSApp.activate()
        service.perform(withItems: urls)
    }

    private func discard(_ item: TrayItem) {
        guard item.owned else { return }
        try? FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: Constants.Paths.trayIndex, options: .atomic)
    }

    private func uniqueURL(named name: String) -> URL {
        let base = Constants.Paths.tray
        let cleaned = name.replacingOccurrences(of: "/", with: "-")
        var url = base.appendingPathComponent(cleaned)
        var index = 2
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        while FileManager.default.fileExists(atPath: url.path) {
            url = base.appendingPathComponent(ext.isEmpty ? "\(stem) \(index)" : "\(stem) \(index).\(ext)")
            index += 1
        }
        return url
    }

    private func loadThumbnail(_ item: TrayItem) {
        let request = QLThumbnailGenerator.Request(
            fileAt: item.url,
            size: CGSize(width: 96, height: 96),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            let image = representation?.nsImage ?? NSWorkspace.shared.icon(forFile: item.url.path)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    withAnimation(.easeOut(duration: 0.2)) { self?.thumbnails[item.id] = image }
                }
            }
        }
    }
}
