import SQLite3
import XCTest
@testable import NotchNull

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class OpencodeReadTests: XCTestCase {
    private var directory: URL!
    private var databaseURL: URL!
    private var path: String!
    private var calendar: Calendar!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("OpencodeReadTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        databaseURL = directory.appendingPathComponent("opencode.db")
        path = databaseURL.path
        calendar = Calendar.current
        try makeDatabase()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Fixture

    private func makeDatabase() throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path, &db), SQLITE_OK)
        guard let db else { return XCTFail("Could not open fixture database") }
        defer { sqlite3_close(db) }
        let sessionCols = "(id TEXT PRIMARY KEY, project_id TEXT NOT NULL, directory TEXT NOT NULL, title TEXT, agent TEXT, model TEXT, cost REAL DEFAULT 0 NOT NULL, tokens_input INTEGER DEFAULT 0 NOT NULL, tokens_output INTEGER DEFAULT 0 NOT NULL, tokens_reasoning INTEGER DEFAULT 0 NOT NULL, tokens_cache_read INTEGER DEFAULT 0 NOT NULL, tokens_cache_write INTEGER DEFAULT 0 NOT NULL, parent_id TEXT, time_updated INTEGER NOT NULL, time_archived INTEGER, time_idle INTEGER, idle_outcome TEXT)"
        try exec(db, "CREATE TABLE session \(sessionCols)")
        try exec(db, "CREATE TABLE session_v2 \(sessionCols)")
        try exec(db, "CREATE TABLE session_message (id TEXT PRIMARY KEY, session_id TEXT NOT NULL, type TEXT NOT NULL, time_created INTEGER NOT NULL, data TEXT NOT NULL)")
        try exec(db, "CREATE INDEX session_message_time_created ON session_message(time_created)")
    }

    private func exec(_ db: OpaquePointer, _ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "sqlite error"
            sqlite3_free(error)
            throw NSError(domain: "OpencodeReadTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private func write(_ body: (OpaquePointer) throws -> Void) throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path, &db), SQLITE_OK)
        guard let db else { return XCTFail("Could not open writer") }
        defer { sqlite3_close(db) }
        try body(db)
    }

    private func insertSession(_ db: OpaquePointer, id: String = "ses_1", updatedAt: Int64, idleOutcome: String? = nil) throws {
        let sql = "INSERT OR REPLACE INTO session_v2 (id,project_id,directory,title,agent,model,time_updated,idle_outcome) VALUES (?, 'p', '/tmp/project', 'Fixture', 'build', '{\"id\":\"fixture\"}', ?, ?)"
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, sql, -1, &stmt, nil), SQLITE_OK)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id, -1, sqliteTransient)
        sqlite3_bind_int64(stmt, 2, updatedAt)
        if let idleOutcome {
            sqlite3_bind_text(stmt, 3, idleOutcome, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(stmt, 3)
        }
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_DONE)
    }

    private func insertMessage(_ db: OpaquePointer, id: String, at milliseconds: Int64, tokens: [String: Any]? = nil, rawData: String? = nil) throws {
        let data: String
        if let rawData {
            data = rawData
        } else {
            var payload: [String: Any] = ["content": []]
            if let tokens { payload["tokens"] = tokens }
            data = String(decoding: try JSONSerialization.data(withJSONObject: payload), as: UTF8.self)
        }
        let sql = "INSERT OR REPLACE INTO session_message (id,session_id,type,time_created,data) VALUES (?, 'ses_1', 'assistant', ?, ?)"
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, sql, -1, &stmt, nil), SQLITE_OK)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id, -1, sqliteTransient)
        sqlite3_bind_int64(stmt, 2, milliseconds)
        sqlite3_bind_text(stmt, 3, data, -1, sqliteTransient)
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_DONE)
    }

    private func deleteMessage(_ db: OpaquePointer, id: String) throws {
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "DELETE FROM session_message WHERE id = ?", -1, &stmt, nil), SQLITE_OK)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id, -1, sqliteTransient)
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_DONE)
    }

    private var now: Date { Date(timeIntervalSince1970: 1_800_000_000) }
    private var dayStart: Date { calendar.startOfDay(for: now) }
    private func milliseconds(_ date: Date) -> Int64 { Int64((date.timeIntervalSince1970 * 1000).rounded()) }

    // MARK: - Change detection

    func testUnchangedDatabaseReusesCacheAndWriterCommitInvalidatesIt() throws {
        var clock = now
        try write { db in
            try insertSession(db, updatedAt: milliseconds(now))
            try insertMessage(db, id: "m1", at: milliseconds(now.addingTimeInterval(-60)), tokens: ["input": 60, "output": 40])
        }
        let reader = OpencodeReader(dbPath: path, now: { clock })
        let first = reader.scan(visible: true, forceBaseline: true)
        XCTAssertFalse(first.cacheHit)
        XCTAssertTrue(first.reconciliationRan)
        XCTAssertGreaterThan(first.messageRowsRead, 0)
        XCTAssertEqual(first.tally.today, 100)

        let second = reader.scan(visible: true)
        XCTAssertTrue(second.cacheHit)
        XCTAssertEqual(second.messageRowsRead, 0)
        XCTAssertEqual(second.tally, first.tally)

        clock = clock.addingTimeInterval(2)
        try write { db in
            try insertMessage(db, id: "m2", at: milliseconds(clock), tokens: ["input": 100, "output": 25])
        }
        let third = reader.scan(visible: true)
        XCTAssertFalse(third.cacheHit)
        XCTAssertGreaterThan(third.messageRowsRead, 0)
        XCTAssertEqual(third.tally.today, 225)
    }

    // MARK: - Aggregate correctness

    func testAggregateMatchesSwiftTokenParserForTotalComponentsAndCache() throws {
        let a: [String: Any] = ["total": 100, "input": 1, "output": 2, "cache": ["read": 3, "write": 4]]
        let b: [String: Any] = ["input": 10, "output": 20, "reasoning": 3, "cache": ["read": 4, "write": 5]]
        let c: [String: Any] = ["input": 7, "output": 8, "reasoning": 9]
        try write { db in
            try insertMessage(db, id: "a", at: milliseconds(now.addingTimeInterval(-180)), tokens: a)
            try insertMessage(db, id: "b", at: milliseconds(now.addingTimeInterval(-120)), tokens: b)
            try insertMessage(db, id: "c", at: milliseconds(now.addingTimeInterval(-60)), tokens: c)
            try insertMessage(db, id: "no-tokens", at: milliseconds(now.addingTimeInterval(-30)))
        }
        let reader = OpencodeReader(dbPath: path, now: { self.now })
        let snapshot = reader.scan(visible: true, forceBaseline: true)
        let expected = OpencodeMonitor.messageTokens(a) + OpencodeMonitor.messageTokens(b) + OpencodeMonitor.messageTokens(c)
        XCTAssertEqual(snapshot.tally.today, expected)
        XCTAssertEqual(snapshot.tally.output, 2 + 20 + 8)
        XCTAssertEqual(snapshot.tally.messages, 4)
        XCTAssertEqual(snapshot.tally.hourly.reduce(0, +), expected)
    }

    // MARK: - Fallback and failures

    func testFallbackRunsOnlyAtTheReconciliationCadence() throws {
        var clock = now
        try write { db in
            try insertMessage(db, id: "m1", at: milliseconds(now.addingTimeInterval(-60)), tokens: ["input": 80, "output": 20])
        }
        let reader = OpencodeReader(dbPath: path, usesJSON1: false, now: { clock })
        let baseline = reader.scan(visible: true, forceBaseline: true)
        XCTAssertEqual(baseline.tally.today, 100)
        XCTAssertTrue(baseline.diagnostics.usedFallback)

        clock = clock.addingTimeInterval(10)
        try write { db in
            try insertMessage(db, id: "m2", at: milliseconds(clock), tokens: ["input": 40, "output": 10])
        }
        let beforeReconciliation = reader.scan(visible: true)
        XCTAssertEqual(beforeReconciliation.tally.today, 100, "No JSON1 delta should run before the bounded reconciliation")
        XCTAssertEqual(beforeReconciliation.messageRowsRead, 0)

        clock = clock.addingTimeInterval(Constants.Agents.opencodeReconcileInterval)
        let reconciled = reader.scan(visible: true)
        XCTAssertEqual(reconciled.tally.today, 150)
        XCTAssertTrue(reconciled.reconciliationRan)
        XCTAssertTrue(reconciled.diagnostics.usedFallback)
    }

    func testMalformedPayloadKeepsLastTotalsAndRecovers() throws {
        var clock = now
        try write { db in
            try insertMessage(db, id: "good", at: milliseconds(now.addingTimeInterval(-120)), tokens: ["input": 90, "output": 10])
        }
        let reader = OpencodeReader(dbPath: path, now: { clock })
        let baseline = reader.scan(visible: true, forceBaseline: true)
        XCTAssertEqual(baseline.tally.today, 100)

        clock = clock.addingTimeInterval(10)
        try write { db in
            try insertMessage(db, id: "bad", at: milliseconds(clock), rawData: "{not json")
        }
        let broken = reader.scan(visible: true)
        XCTAssertTrue(broken.dbAvailable)
        XCTAssertFalse(broken.usageAvailable)
        XCTAssertEqual(broken.tally.today, 100)

        try write { db in
            try deleteMessage(db, id: "bad")
            try insertMessage(db, id: "recovered", at: milliseconds(clock), tokens: ["input": 20, "output": 5])
        }
        clock = clock.addingTimeInterval(2)
        let recovered = reader.scan(visible: true)
        XCTAssertTrue(recovered.usageAvailable)
        XCTAssertEqual(recovered.tally.today, 125)
    }

    func testAMalformedPayloadThatStaysIsRetriedOnChangeOrAfterTheReconcileIntervalNotEveryPoll() throws {
        var clock = now
        try write { db in
            try insertMessage(db, id: "good", at: milliseconds(now.addingTimeInterval(-120)), tokens: ["input": 90, "output": 10])
            try insertMessage(db, id: "bad", at: milliseconds(now.addingTimeInterval(-60)), rawData: "{not json")
        }
        let reader = OpencodeReader(dbPath: path, now: { clock })
        let broken = reader.scan(visible: true, forceBaseline: true)
        XCTAssertTrue(broken.reconciliationRan)
        XCTAssertFalse(broken.usageAvailable)

        clock = clock.addingTimeInterval(Constants.Agents.opencodePollInterval)
        let idle = reader.scan(visible: true)
        XCTAssertFalse(idle.reconciliationRan, "an unchanged store must not reparse the day on every poll")
        XCTAssertTrue(idle.cacheHit)
        XCTAssertFalse(idle.usageAvailable)

        clock = clock.addingTimeInterval(Constants.Agents.opencodeReconcileInterval)
        let retried = reader.scan(visible: true)
        XCTAssertTrue(retried.reconciliationRan)
        XCTAssertFalse(retried.usageAvailable)

        clock = clock.addingTimeInterval(Constants.Agents.opencodePollInterval)
        try write { db in try deleteMessage(db, id: "bad") }
        let recovered = reader.scan(visible: true)
        XCTAssertTrue(recovered.reconciliationRan, "a store change retries at once")
        XCTAssertTrue(recovered.usageAvailable)
        XCTAssertEqual(recovered.tally.today, 100)
    }

    func testMissingAndLockedDatabaseKeepTheLastTotalsAndRetry() throws {
        var clock = now
        try write { db in
            try insertMessage(db, id: "m1", at: milliseconds(now.addingTimeInterval(-60)), tokens: ["input": 75, "output": 25])
        }
        let reader = OpencodeReader(dbPath: path, now: { clock })
        XCTAssertEqual(reader.scan(visible: true, forceBaseline: true).tally.today, 100)

        let writer = try XCTUnwrap(openWriter())
        defer { sqlite3_close(writer) }
        try exec(writer, "BEGIN EXCLUSIVE")
        try insertMessage(writer, id: "uncommitted", at: milliseconds(now), tokens: ["input": 1, "output": 1])
        clock = clock.addingTimeInterval(2)
        let locked = reader.scan(visible: true, forceBaseline: true)
        XCTAssertFalse(locked.usageAvailable)
        XCTAssertEqual(locked.tally.today, 100)
        try exec(writer, "ROLLBACK")

        clock = clock.addingTimeInterval(2)
        let recovered = reader.scan(visible: true)
        XCTAssertTrue(recovered.dbAvailable)
        XCTAssertTrue(recovered.usageAvailable)
        XCTAssertEqual(recovered.tally.today, 100)

        try FileManager.default.removeItem(at: databaseURL)
        clock = clock.addingTimeInterval(2)
        let missing = reader.scan(visible: true)
        XCTAssertFalse(missing.dbAvailable)
        XCTAssertEqual(missing.tally.today, 100)
    }

    // MARK: - Incremental history and reconciliation

    func testDeltaAddsOnlyNewMessagesAndReconciliationCorrectsEditsAndTies() throws {
        var clock = now
        let firstTimestamp = milliseconds(now.addingTimeInterval(-120))
        try write { db in
            try insertMessage(db, id: "m1", at: firstTimestamp, tokens: ["input": 70, "output": 30])
        }
        let reader = OpencodeReader(dbPath: path, now: { clock })
        let baseline = reader.scan(visible: true, forceBaseline: true)
        let firstCursor = try XCTUnwrap(reader.history?.cursorMs)
        XCTAssertEqual(baseline.tally.today, 100)

        clock = clock.addingTimeInterval(2)
        let secondTimestamp = milliseconds(clock)
        try write { db in
            try insertMessage(db, id: "m2", at: secondTimestamp, tokens: ["input": 40, "output": 10])
        }
        let delta = reader.scan(visible: true)
        XCTAssertFalse(delta.reconciliationRan)
        XCTAssertTrue(delta.deltaRan)
        XCTAssertEqual(delta.tally.today, 150)
        XCTAssertEqual(reader.history?.cursorMs, secondTimestamp)
        XCTAssertGreaterThan(reader.history?.cursorMs ?? 0, firstCursor)

        // A same-millisecond insert is deliberately missed by the cursor and
        // corrected by the next full reconciliation.
        try write { db in
            try insertMessage(db, id: "tie", at: secondTimestamp, tokens: ["input": 10, "output": 5])
        }
        clock = clock.addingTimeInterval(2)
        let tieMissed = reader.scan(visible: true)
        XCTAssertEqual(tieMissed.tally.today, 150)

        clock = clock.addingTimeInterval(Constants.Agents.opencodeReconcileInterval)
        let reconciled = reader.scan(visible: true)
        XCTAssertEqual(reconciled.tally.today, 165)

        try write { db in
            try deleteMessage(db, id: "m2")
            try insertMessage(db, id: "m1", at: firstTimestamp, tokens: ["input": 150, "output": 50])
        }
        clock = clock.addingTimeInterval(Constants.Agents.opencodeReconcileInterval)
        let corrected = reader.scan(visible: true)
        XCTAssertEqual(corrected.tally.today, 215, "The next reconciliation corrects edited and removed rows")
    }

    func testMidnightAndDatabaseReplacementResetHistory() throws {
        var clock = dayStart.addingTimeInterval(23 * 3600)
        try write { db in
            try insertMessage(db, id: "yesterday", at: milliseconds(clock), tokens: ["input": 100, "output": 20])
        }
        let reader = OpencodeReader(dbPath: path, now: { clock })
        XCTAssertEqual(reader.scan(visible: true, forceBaseline: true).tally.today, 120)

        clock = dayStart.addingTimeInterval(25 * 3600)
        try write { db in
            try insertMessage(db, id: "today", at: milliseconds(clock), tokens: ["input": 30, "output": 10])
        }
        let nextDay = reader.scan(visible: true)
        XCTAssertEqual(nextDay.tally.today, 40)
        XCTAssertEqual(nextDay.tally.hourly.reduce(0, +), 40)

        // Recreate the file at the same path. Its identity changes, so cached
        // history must be dropped and the replacement rebuilt from scratch.
        try FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: path + "-wal"))
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: path + "-shm"))
        try makeDatabase()
        clock = clock.addingTimeInterval(60)
        try write { db in
            try insertMessage(db, id: "replacement", at: milliseconds(clock), tokens: ["input": 12, "output": 3])
        }
        let replaced = reader.scan(visible: true)
        XCTAssertEqual(replaced.tally.today, 15)
        XCTAssertEqual(replaced.tally.messages, 1)
    }

    func testClosedTabNeverReadsMessageRowsAndOpeningEstablishesBaseline() throws {
        var clock = now
        try write { db in
            try insertSession(db, updatedAt: milliseconds(now), idleOutcome: nil)
            try insertMessage(db, id: "m1", at: milliseconds(now.addingTimeInterval(-60)), tokens: ["input": 60, "output": 40])
        }
        let reader = OpencodeReader(dbPath: path, now: { clock })
        let closed = reader.scan(visible: false)
        XCTAssertEqual(closed.messageRowsRead, 0)
        XCTAssertEqual(closed.tally.today, 0)
        XCTAssertTrue(closed.usageAvailable)

        clock = clock.addingTimeInterval(2)
        try write { db in
            try insertMessage(db, id: "m2", at: milliseconds(clock), tokens: ["input": 20, "output": 5])
        }
        let stillClosed = reader.scan(visible: false)
        XCTAssertEqual(stillClosed.messageRowsRead, 0)
        XCTAssertEqual(stillClosed.tally.today, 0)

        let opened = reader.scan(visible: true)
        XCTAssertTrue(opened.reconciliationRan)
        XCTAssertEqual(opened.tally.today, 125)
    }

    func testSessionStateRefreshesWhenClosedWithoutTouchingMessages() throws {
        var clock = now
        try write { db in
            try insertSession(db, updatedAt: milliseconds(now))
            try insertMessage(db, id: "m1", at: milliseconds(now.addingTimeInterval(-60)), tokens: ["input": 5, "output": 5])
        }
        let reader = OpencodeReader(dbPath: path, now: { clock })
        _ = reader.scan(visible: false)
        clock = clock.addingTimeInterval(2)
        try write { db in
            try insertSession(db, updatedAt: milliseconds(clock), idleOutcome: "succeeded")
        }
        let changed = reader.scan(visible: false)
        XCTAssertEqual(changed.rows.first?.idleOutcome, "succeeded")
        XCTAssertEqual(changed.messageRowsRead, 0)
        XCTAssertEqual(changed.tally.today, 0)
    }

    // MARK: - Monitor visibility API

    @MainActor
    func testVisibilityConsumersAreIdempotentAndBaselineOnFirstOpen() throws {
        let saved = Preferences.shared.opencodeEnabled
        Preferences.shared.opencodeEnabled = true
        defer { Preferences.shared.opencodeEnabled = saved }

        var clock = now
        try write { db in
            try insertMessage(db, id: "m1", at: milliseconds(now.addingTimeInterval(-60)), tokens: ["input": 64, "output": 36])
        }
        let monitor = OpencodeMonitor(store: AgentSessionStore(), dbPath: path, now: { clock })
        let first = UUID()
        let second = UUID()
        XCTAssertEqual(monitor.usageConsumerCount, 0)

        monitor.setUsageVisible(true, consumer: first)
        monitor.setUsageVisible(true, consumer: first)
        XCTAssertEqual(monitor.usageConsumerCount, 1)
        monitor.setUsageVisible(true, consumer: second)
        XCTAssertEqual(monitor.usageConsumerCount, 2)
        monitor.setUsageVisible(false, consumer: first)
        monitor.setUsageVisible(false, consumer: first)
        XCTAssertEqual(monitor.usageConsumerCount, 1)

        let expectation = expectation(description: "first consumer establishes a token baseline")
        let subscription = monitor.$tokens.dropFirst().sink { tally in
            if tally.today == 100 { expectation.fulfill() }
        }
        wait(for: [expectation], timeout: 3)
        withExtendedLifetime(subscription) {}

        monitor.setUsageVisible(false, consumer: second)
        XCTAssertEqual(monitor.usageConsumerCount, 0)
        clock = clock.addingTimeInterval(2)
    }

    @MainActor
    func testSessionTransitionAppearsWithinTwoSecondsWhileUsageIsClosed() throws {
        let saved = Preferences.shared.opencodeEnabled
        Preferences.shared.opencodeEnabled = true
        defer { Preferences.shared.opencodeEnabled = saved }

        var clock = now
        try write { db in
            try insertSession(db, updatedAt: milliseconds(now))
            try insertMessage(db, id: "m1", at: milliseconds(now.addingTimeInterval(-60)), tokens: ["input": 60, "output": 40])
        }
        let store = AgentSessionStore()
        let monitor = OpencodeMonitor(store: store, dbPath: path, now: { clock })

        let loaded = expectation(description: "initial session state")
        loaded.assertForOverFulfill = false
        let loadedSubscription = store.$sessions.sink { sessions in
            if sessions.contains(where: { $0.id == "ses_1" }) { loaded.fulfill() }
        }
        monitor.start()
        wait(for: [loaded], timeout: 3)
        withExtendedLifetime(loadedSubscription) {}

        clock = clock.addingTimeInterval(1)
        try write { db in
            let sql = "UPDATE session_v2 SET time_updated = ?, time_idle = ?, idle_outcome = 'succeeded' WHERE id = 'ses_1'"
            var stmt: OpaquePointer?
            XCTAssertEqual(sqlite3_prepare_v2(db, sql, -1, &stmt, nil), SQLITE_OK)
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, milliseconds(clock))
            sqlite3_bind_int64(stmt, 2, milliseconds(clock))
            XCTAssertEqual(sqlite3_step(stmt), SQLITE_DONE)
        }

        let transitioned = expectation(description: "session transitions to done")
        transitioned.assertForOverFulfill = false
        let transitionSubscription = store.$sessions.sink { sessions in
            if sessions.first(where: { $0.id == "ses_1" })?.status == .done { transitioned.fulfill() }
        }
        wait(for: [transitioned], timeout: 3)
        withExtendedLifetime(transitionSubscription) {}

        XCTAssertEqual(store.sessions.first(where: { $0.id == "ses_1" })?.status, .done)
        XCTAssertEqual(monitor.tokens.today, 0, "No token work runs while the Agents tab is closed")
        Preferences.shared.opencodeEnabled = false
    }

    private func openWriter() -> OpaquePointer? {
        var db: OpaquePointer?
        guard sqlite3_open(path, &db) == SQLITE_OK else { return nil }
        return db
    }
}
