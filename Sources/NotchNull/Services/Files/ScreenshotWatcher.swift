import AppKit
import Combine
import SwiftUI

/// New screenshots via Spotlight's `kMDItemIsScreenCapture`, which works for any save location
/// and any system language. Each one lands in the Tray and slides out of the notch.
@MainActor
final class ScreenshotWatcher: ObservableObject {
    @Published private(set) var latest: URL?
    @Published private(set) var latestImage: NSImage?

    private let tray: TrayStore
    private var query: NSMetadataQuery?
    private var startedAt = Date()
    private var seen: Set<String> = []
    private var observer: NSObjectProtocol?

    init(tray: TrayStore) {
        self.tray = tray
    }

    func start() {
        startedAt = Date()
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1 AND kMDItemContentCreationDate >= %@", startedAt as NSDate)
        query.searchScopes = [NSMetadataQueryLocalComputerScope]
        query.notificationBatchingInterval = 0.3
        observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.collect() }
        }
        query.start()
        self.query = query
    }

    /// Fixture entry point for snapshot rendering.
    func preview(url: URL, image: NSImage?) {
        latest = url
        latestImage = image
    }

    private func collect() {
        guard let query, Preferences.shared.screenshotsEnabled else { return }
        query.disableUpdates()
        defer { query.enableUpdates() }
        var fresh: [URL] = []
        for index in 0..<query.resultCount {
            guard let item = query.result(at: index) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  !seen.contains(path) else { continue }
            seen.insert(path)
            fresh.append(URL(fileURLWithPath: path))
        }
        guard let newest = fresh.last else { return }
        tray.add(urls: fresh, announce: false)
        withAnimation(Motion.state) {
            latest = newest
            latestImage = NSImage(contentsOf: newest)
        }
        ActivityCenter.shared.post(.screenshot, for: Constants.Durations.screenshot)
        ActivityLog.shared.add(symbol: "camera.viewfinder", tint: Theme.Accent.tray, title: "Screenshot saved to Tray", detail: newest.lastPathComponent, action: .open(newest))
    }
}
