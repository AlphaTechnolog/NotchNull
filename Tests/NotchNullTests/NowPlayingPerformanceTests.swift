import Combine
import XCTest
@testable import NotchNull

@MainActor
final class NowPlayingPerformanceTests: XCTestCase {
    private func track(playing: Bool = false) -> NowPlaying {
        NowPlaying(title: "Title", artist: "Artist", album: "Album", duration: 300,
                   position: 12, sampledAt: Date(timeIntervalSince1970: 1000), isPlaying: playing,
                   trackID: "track", bundleID: "test.player", sourceName: "Player")
    }

    func testPausedResyncDoesNotPublishButSeekDoes() {
        let service = NowPlayingService()
        var publications = 0
        let subscription = service.$nowPlaying.dropFirst().sink { _ in publications += 1 }
        var state = track()
        service.setState(state)
        state.sampledAt += 3
        service.setState(state)
        XCTAssertEqual(publications, 1)
        state.position += 0.1
        service.setState(state)
        XCTAssertEqual(publications, 2)
        withExtendedLifetime(subscription) {}
    }

    func testPlayingProjectionDeduplicatesWithoutFreezingElapsed() {
        let service = NowPlayingService()
        let first = track(playing: true)
        service.setState(first)
        var next = first
        next.sampledAt += 3
        next.position += 3
        service.setState(next)
        XCTAssertEqual(service.nowPlaying?.sampledAt, first.sampledAt)
        XCTAssertEqual(service.nowPlaying?.elapsed(at: next.sampledAt), 15)
        next.isPlaying = false
        service.setState(next)
        XCTAssertEqual(service.nowPlaying?.isPlaying, false)
        XCTAssertEqual(service.nowPlaying?.position, 15)
    }

    func testAllMetadataChangesRemainObservable() {
        let first = track()
        var next = first
        next.album = "Other album"
        XCTAssertFalse(first.hasSamePresentation(as: next))
        next = first; next.bundleID = "other.player"
        XCTAssertFalse(first.hasSamePresentation(as: next))
        next = first; next.trackID = "other track"
        XCTAssertFalse(first.hasSamePresentation(as: next))
        next = first; next.duration = 301
        XCTAssertFalse(first.hasSamePresentation(as: next))
        next = first; next.hasMetadata = false
        XCTAssertFalse(first.hasSamePresentation(as: next))
    }
}
