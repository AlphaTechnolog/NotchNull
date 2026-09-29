import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Resolves dropped item providers into file URLs, writing web images and text into the Tray folder.
@MainActor
enum DropSupport {
    static let acceptedTypes: [UTType] = [.fileURL, .image, .url, .utf8PlainText]

    static func resolve(_ providers: [NSItemProvider], tray: TrayStore, completion: @escaping ([URL]) -> Void) {
        let group = DispatchGroup()
        let collector = URLCollector()
        let collect: @Sendable (URL?) -> Void = { collector.append($0) }

        for provider in providers {
            group.enter()
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    collect(url)
                    group.leave()
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                let name = provider.suggestedName ?? "Image"
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data else { group.leave(); return }
                    let ext = NSImage(data: data).flatMap { _ in imageExtension(for: data) } ?? "png"
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated {
                            let filename = name.contains(".") ? name : "\(name).\(ext)"
                            collect(tray.add(data: data, suggestedName: filename))
                            group.leave()
                        }
                    }
                }
            } else if provider.canLoadObject(ofClass: String.self) {
                _ = provider.loadObject(ofClass: String.self) { text, _ in
                    guard let text else { group.leave(); return }
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated {
                            let title = String(text.prefix(24)).replacingOccurrences(of: "\n", with: " ")
                            collect(tray.add(data: Data(text.utf8), suggestedName: "\(title).txt"))
                            group.leave()
                        }
                    }
                }
            } else {
                group.leave()
            }
        }
        group.notify(queue: .main) { completion(collector.urls) }
    }

    /// Thread-safe accumulator for provider callbacks that arrive on arbitrary queues.
    private final class URLCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [URL] = []

        func append(_ url: URL?) {
            guard let url else { return }
            lock.lock()
            storage.append(url)
            lock.unlock()
        }

        var urls: [URL] {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
    }

    /// Names of files currently being dragged, read from the drag pasteboard.
    static func draggedNames() -> [String] {
        let pasteboard = NSPasteboard(name: .drag)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            return urls.map(\.lastPathComponent)
        }
        if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) { return ["Image"] }
        return []
    }

    private nonisolated static func imageExtension(for data: Data) -> String {
        let bytes = [UInt8](data.prefix(4))
        if bytes.starts(with: [0x89, 0x50]) { return "png" }
        if bytes.starts(with: [0xFF, 0xD8]) { return "jpg" }
        if bytes.starts(with: [0x47, 0x49]) { return "gif" }
        return "png"
    }
}
