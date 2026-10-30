import Combine
import SwiftUI
import XCTest
@testable import NotchNull

/// How `PlanUsageService.apply` turns provider results into shown state: a hidden provider without
/// a plan, the last good windows kept through a failed refresh, and sign-in guidance.
@MainActor
final class PlanUsageServiceTests: XCTestCase {
    private struct StubPlan: PlanProvider {
        var id = OpenCodeGoPlan.planID
        let title = "OpenCode Go"
        let monogram = "Go"
        var tint: Color { Theme.Accent.opencode }
        func credential(in sources: PlanCredentialSources) -> PlanCredential? { nil }
        func fetch(_ credential: PlanCredential) async throws -> PlanSnapshot { throw PlanError.unavailable("unused") }
    }

    private let credential = PlanCredential(key: "secret", source: "OpenCode · Default")
    private let windows = [UsageWindow(id: "opencode-rolling", label: "5 hours", percent: 5, resetsAt: nil, duration: 5 * 3600)]

    private func apply(_ service: PlanUsageService, _ outcome: Result<PlanSnapshot, PlanError>) {
        service.apply([(StubPlan(), credential, outcome)])
    }

    func testAReadyReadingStoresTheWindowsAndSource() {
        let service = PlanUsageService()
        apply(service, .success(PlanSnapshot(plan: nil, windows: windows)))
        XCTAssertEqual(service.usages.count, 1)
        XCTAssertEqual(service.usages.first?.state, .ready)
        XCTAssertEqual(service.usages.first?.windows, windows)
        XCTAssertEqual(service.usages.first?.source, "OpenCode · Default")
    }

    func testNoSubscriptionHidesTheProvider() {
        let service = PlanUsageService()
        apply(service, .failure(.noSubscription))
        XCTAssertTrue(service.usages.isEmpty)
    }

    func testSignedOutBeforeAnyReadingStaysHidden() {
        let service = PlanUsageService()
        apply(service, .failure(.signedOut("Key rejected by OpenCode")))
        XCTAssertTrue(service.usages.isEmpty)
    }

    func testTransientFailureKeepsTheLastGoodWindowsAndMarksThemUnavailable() {
        let service = PlanUsageService()
        apply(service, .success(PlanSnapshot(plan: "Go", windows: windows)))
        apply(service, .failure(.unavailable("Offline")))
        XCTAssertEqual(service.usages.count, 1)
        XCTAssertEqual(service.usages.first?.windows, windows)
        XCTAssertEqual(service.usages.first?.plan, "Go")
        XCTAssertEqual(service.usages.first?.state, .unavailable("Offline"))
    }

    func testSignedOutAfterAReadingShowsGuidanceWithoutBars() {
        let service = PlanUsageService()
        apply(service, .success(PlanSnapshot(plan: nil, windows: windows)))
        apply(service, .failure(.signedOut("Key rejected by OpenCode")))
        XCTAssertTrue(service.usages.first?.windows.isEmpty == true)
        XCTAssertEqual(service.usages.first?.state, .signedOut("Key rejected by OpenCode"))
    }

    /// Blocks the first account read until the test has changed the consent, and records each read.
    private final class GatedSources: @unchecked Sendable {
        private let lock = NSLock()
        private let firstReadMayFinish = DispatchSemaphore(value: 0)
        private var consents: [Bool] = []
        let firstReadStarted = XCTestExpectation(description: "first read started")
        let secondReadStarted = XCTestExpectation(description: "second read started")

        var reads: [Bool] { lock.withLock { consents } }

        func load(accountUsageAllowed: Bool) -> PlanCredentialSources {
            let count = lock.withLock { consents.append(accountUsageAllowed); return consents.count }
            if count == 1 {
                firstReadStarted.fulfill()
                firstReadMayFinish.wait()
            } else if count == 2 {
                secondReadStarted.fulfill()
            }
            return PlanCredentialSources(openCodeAccount: accountUsageAllowed ? .noAccount : nil)
        }

        func finishFirstRead() { firstReadMayFinish.signal() }
    }

    /// Waits until the refresh and any refresh queued behind it have finished; the deadline only
    /// bounds a hang, the assertions never depend on how long a step took.
    private func settle(_ service: PlanUsageService) async {
        let deadline = Date().addingTimeInterval(5)
        while service.isRefreshing, Date() < deadline { try? await Task.sleep(nanoseconds: 1_000_000) }
        XCTAssertFalse(service.isRefreshing, "refresh did not finish")
    }

    func testRevokingConsentDuringARefreshNeverPublishesTheAccountAndReadsAgainWithoutIt() async {
        let sources = GatedSources()
        var allowed = true
        let service = PlanUsageService(loadSources: { sources.load(accountUsageAllowed: $0) }, accountUsageAllowed: { allowed }, planUsageEnabled: { true })
        var published: [OpenCodeAuthExport.Selection?] = []
        let watch = service.$openCodeAccount.dropFirst().sink { published.append($0) }
        defer { watch.cancel() }

        service.refresh()
        await fulfillment(of: [sources.firstReadStarted], timeout: 5)
        allowed = false
        service.accountConsentChanged(allowed: false)
        sources.finishFirstRead()
        await fulfillment(of: [sources.secondReadStarted], timeout: 5)
        await settle(service)

        XCTAssertEqual(sources.reads, [true, false])
        XCTAssertNil(service.openCodeAccount)
        XCTAssertTrue(published.allSatisfy { $0 == nil }, "a read made before the revoke was published: \(published)")
    }

    func testGrantingConsentDuringARefreshReadsTheAccountRightAfter() async {
        let sources = GatedSources()
        var allowed = false
        let service = PlanUsageService(loadSources: { sources.load(accountUsageAllowed: $0) }, accountUsageAllowed: { allowed }, planUsageEnabled: { true })

        service.refresh()
        await fulfillment(of: [sources.firstReadStarted], timeout: 5)
        allowed = true
        service.accountConsentChanged(allowed: true)
        sources.finishFirstRead()
        await fulfillment(of: [sources.secondReadStarted], timeout: 5)
        await settle(service)

        XCTAssertEqual(sources.reads, [false, true])
        XCTAssertEqual(service.openCodeAccount, .noAccount)
    }

    func testTurningPlanUsageOffDuringARefreshPublishesNothingAndRunsNoQueuedRead() async {
        let sources = GatedSources()
        var allowed = false
        var enabled = true
        let service = PlanUsageService(loadSources: { sources.load(accountUsageAllowed: $0) }, accountUsageAllowed: { allowed }, planUsageEnabled: { enabled })

        service.refresh()
        await fulfillment(of: [sources.firstReadStarted], timeout: 5)
        enabled = false
        allowed = true
        service.refresh()
        sources.finishFirstRead()
        await settle(service)

        XCTAssertEqual(sources.reads, [false])
        XCTAssertNil(service.openCodeAccount)
        XCTAssertTrue(service.usages.isEmpty)
    }
}
