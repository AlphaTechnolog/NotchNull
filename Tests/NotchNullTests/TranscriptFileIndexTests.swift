import XCTest
@testable import NotchNull

final class TranscriptFileIndexTests: XCTestCase {
    func testReusesMetadataButExpiresQuietFilesWithoutRescan() {
        let index = TranscriptFileIndex()
        let now = Date(timeIntervalSince1970: 1000)
        let file = URL(fileURLWithPath: "/fixture.jsonl")
        var loads = 0
        let load: () -> [TranscriptFileIndex.Entry] = { loads += 1; return [(file, now)] }
        XCTAssertEqual(index.files(since: now, now: now, load: load), [file])
        XCTAssertTrue(index.files(since: now.addingTimeInterval(1), now: now.addingTimeInterval(2), load: load).isEmpty)
        XCTAssertEqual(loads, 1)
        index.invalidate()
        _ = index.files(since: now, now: now.addingTimeInterval(3), load: load)
        XCTAssertEqual(loads, 2)
        _ = index.files(since: now, now: now.addingTimeInterval(64), load: load)
        XCTAssertEqual(loads, 3, "Missed events have a bounded fallback")
    }

    func testInvalidationDiscoversCreationAndRemoval() {
        let index = TranscriptFileIndex()
        let now = Date()
        let file = URL(fileURLWithPath: "/new.jsonl")
        XCTAssertTrue(index.files(since: .distantPast, now: now) { [] }.isEmpty)
        index.invalidate()
        XCTAssertEqual(index.files(since: .distantPast, now: now) { [(file, now)] }, [file])
        index.invalidate()
        XCTAssertTrue(index.files(since: .distantPast, now: now) { [] }.isEmpty)
    }
}
