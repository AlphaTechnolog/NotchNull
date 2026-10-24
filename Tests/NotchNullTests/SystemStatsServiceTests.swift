import XCTest
@testable import NotchNull

@MainActor
final class SystemStatsServiceTests: XCTestCase {
    func testConsumersAreIdempotentAndIndependent() {
        let stats = SystemStatsService(readDisk: { nil })
        let first = UUID(), second = UUID()
        stats.setActive(true, consumer: first)
        stats.setActive(true, consumer: first)
        stats.setActive(true, consumer: second)
        XCTAssertTrue(stats.isSampling)
        stats.setActive(false, consumer: first)
        stats.setActive(false, consumer: first)
        XCTAssertTrue(stats.isSampling)
        stats.setActive(false, consumer: second)
        XCTAssertFalse(stats.isSampling)
    }

    func testDiskQueryRunsOffMainAndDoesNotPublishAfterClosing() async {
        let started = expectation(description: "query started")
        let release = DispatchSemaphore(value: 0)
        let stats = SystemStatsService(readDisk: {
            XCTAssertFalse(Thread.isMainThread)
            started.fulfill()
            _ = release.wait(timeout: .now() + 5)
            return 1234
        })
        let consumer = UUID()
        stats.setActive(true, consumer: consumer)
        await fulfillment(of: [started], timeout: 2)
        stats.setActive(false, consumer: consumer)
        release.signal()
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(stats.snapshot.diskFree, 0)
        XCTAssertFalse(stats.isSampling)
    }
}
