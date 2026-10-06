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
}
