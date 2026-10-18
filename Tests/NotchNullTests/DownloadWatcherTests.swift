import XCTest
@testable import NotchNull

final class DownloadWatcherTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testPartialStillBeingWrittenIsActive() {
        XCTAssertFalse(DownloadWatcher.isStalled(modified: now.addingTimeInterval(-2), now: now))
    }

    func testPartialLeftBehindByACancelledDownloadIsStalled() {
        XCTAssertTrue(DownloadWatcher.isStalled(modified: now.addingTimeInterval(-18 * 60), now: now))
    }

    func testPartialAtTheStallLimitIsStillActive() {
        XCTAssertFalse(DownloadWatcher.isStalled(modified: now.addingTimeInterval(-Constants.Durations.downloadStalled), now: now))
    }

    func testPartialWithoutAReadableDateStaysActive() {
        XCTAssertFalse(DownloadWatcher.isStalled(modified: nil, now: now))
    }

    @MainActor
    func testProgressUsesOnlyTrackedPartialsAndFreshMetadata() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { _ = try? FileManager.default.trashItem(at: folder, resultingItemURL: nil) }
        let partial = folder.appendingPathComponent("file.zip.crdownload")
        try Data([1]).write(to: partial)
        var scans = 0
        let watcher = DownloadWatcher(folder: folder, listDirectory: {
            scans += 1
            return try FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: [.fileSizeKey])
        }, completion: { _ in })
        watcher.scan()
        XCTAssertEqual(watcher.active.first?.bytes, 1)
        try FileManager.default.setAttributes([.modificationDate: Date.distantPast], ofItemAtPath: partial.path)
        watcher.pollProgress()
        XCTAssertTrue(watcher.active.isEmpty)
        try Data(repeating: 2, count: 1024).write(to: partial)
        watcher.pollProgress()
        XCTAssertEqual(watcher.active.first?.bytes, 1024)
        XCTAssertEqual(scans, 1)
        watcher.preview(active: [], finished: nil)
    }

    @MainActor
    func testFirefoxPlaceholderRenameDirectSaveAndReadFailure() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { _ = try? FileManager.default.trashItem(at: folder, resultingItemURL: nil) }
        var fail = false
        var finished: [String] = []
        let watcher = DownloadWatcher(folder: folder, listDirectory: {
            if fail { throw CocoaError(.fileReadNoPermission) }
            return try FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)
        }, completion: { finished.append($0.lastPathComponent) })
        watcher.scan()
        let placeholder = folder.appendingPathComponent("firefox.zip")
        let partial = folder.appendingPathComponent("firefox.zip.part")
        try Data().write(to: placeholder)
        try Data([1]).write(to: partial)
        watcher.scan()
        XCTAssertTrue(finished.isEmpty)
        // Move the fixture partial outside the watched folder, without deleting it.
        let holding = folder.appendingPathComponent(".holding")
        try FileManager.default.createDirectory(at: holding, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: partial, to: holding.appendingPathComponent("partial"))
        watcher.scan()
        XCTAssertEqual(finished, ["firefox.zip"])
        fail = true; watcher.scan(); fail = false
        watcher.scan()
        XCTAssertEqual(finished, ["firefox.zip"])
        let chrome = folder.appendingPathComponent("chrome.zip.crdownload")
        try Data([1]).write(to: chrome)
        watcher.scan()
        try FileManager.default.moveItem(at: chrome, to: folder.appendingPathComponent("chrome.zip"))
        watcher.scan()
        try Data([1]).write(to: folder.appendingPathComponent("direct.zip"))
        watcher.scan()
        XCTAssertEqual(finished, ["firefox.zip", "chrome.zip", "direct.zip"])
        XCTAssertTrue(watcher.active.isEmpty)
    }
}
