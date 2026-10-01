import XCTest
import SQLite3
@testable import NotchNull

final class OpencodeTests: XCTestCase {
    func testModelIDParsesFromJSONBlob() {
        XCTAssertEqual(OpencodeMonitor.parseModelID(#"{"id":"big-pickle","providerID":"opencode"}"#), "big-pickle")
        XCTAssertEqual(OpencodeMonitor.parseModelID(#"{"id":"minimax-m3","providerID":"opencode-go","variant":"default"}"#), "minimax-m3")
        XCTAssertEqual(OpencodeMonitor.parseModelID("big-pickle"), "big-pickle")
        XCTAssertNil(OpencodeMonitor.parseModelID(nil))
        XCTAssertNil(OpencodeMonitor.parseModelID(""))
    }

    func testLabelJoinsAgentAndModel() {
        XCTAssertEqual(OpencodeMonitor.label(agent: "build", model: #"{"id":"big-pickle"}"#), "build • big-pickle")
        XCTAssertEqual(OpencodeMonitor.label(agent: "build", model: nil), "build")
        XCTAssertEqual(OpencodeMonitor.label(agent: nil, model: #"{"id":"big-pickle"}"#), "big-pickle")
        XCTAssertNil(OpencodeMonitor.label(agent: nil, model: nil))
        XCTAssertNil(OpencodeMonitor.label(agent: "", model: ""))
    }

    func testNormalizesMsAndSecondEpochs() {
        let fromMs = OpencodeMonitor.normalizeTime(1_790_224_541_423)
        let fromS = OpencodeMonitor.normalizeTime(1_790_224_541)
        XCTAssertEqual(fromMs.timeIntervalSince1970, Double(1_790_224_541_423) / 1000, accuracy: 0.001)
        XCTAssertEqual(fromS.timeIntervalSince1970, 1_790_224_541, accuracy: 0.001)
    }

    func testSubagentAndArchivedRowsAreExcluded() {
        XCTAssertTrue(OpencodeMonitor.shouldInclude(parentID: nil, timeArchived: nil))
        XCTAssertTrue(OpencodeMonitor.shouldInclude(parentID: "", timeArchived: 0))
        XCTAssertFalse(OpencodeMonitor.shouldInclude(parentID: "ses_parent", timeArchived: nil))
        XCTAssertFalse(OpencodeMonitor.shouldInclude(parentID: nil, timeArchived: 1_790_000_000_000))
    }

    private func idleSession(cwd: String = "/Users/alpha/work/aether", detail: String? = "Aether theme", origin: String? = "build • minimax-m3", status: AgentSession.Status = .idle) -> AgentSession {
        AgentSession(
            id: "ses_1", provider: .opencode, cwd: cwd, status: status,
            turnStartedAt: nil, lastTurnDuration: nil, updatedAt: Date(timeIntervalSince1970: 1_000_000),
            terminalBundleID: nil, tty: nil, detail: detail, origin: origin
        )
    }

    private func dbRow(timeIdle: Date? = nil, idleOutcome: String? = nil, updatedAt: Date = Date()) -> OpencodeMonitor.Row {
        OpencodeMonitor.Row(
            id: "ses_1", directory: "/Users/alpha/work/aether", title: "Aether theme",
            agent: "build", model: #"{"id":"minimax-m3"}"#, cost: 0,
            tokensInput: 0, tokensOutput: 0, tokensReasoning: 0, tokensCacheRead: 0, tokensCacheWrite: 0,
            updatedAt: updatedAt, timeIdle: timeIdle, idleOutcome: idleOutcome
        )
    }

    func testUnchangedIdleRowMapsToItselfSoTimestampsAge() {
        // Same cwd/detail/origin, still quiet: target equals current state, so
        // `apply` skips the upsert and `updatedAt` is left alone.
        let existing = idleSession()
        let next = OpencodeMonitor.target(existing: existing, row: dbRow(timeIdle: Date(timeIntervalSince1970: 1_000_000)), label: "build • minimax-m3", now: Date())
        XCTAssertEqual(next.status, .idle)
        XCTAssertEqual(next.cwd, existing.cwd)
        XCTAssertEqual(next.origin, existing.origin)
        XCTAssertEqual(next.detail, existing.detail)
    }

    func testRowWithoutIdleMarkerMapsToIdle() {
        // The DB cannot prove activity (touches come from views/syncs too),
        // so it never promotes to running — the plugin owns that state.
        let next = OpencodeMonitor.target(existing: nil, row: dbRow(), label: "build • minimax-m3", now: Date())
        XCTAssertEqual(next.status, .idle)
        XCTAssertNil(next.turnStartedAt)
    }

    func testRecentSucceededIdleMarkerMapsToDone() {
        let row = dbRow(timeIdle: Date(), idleOutcome: "succeeded")
        let next = OpencodeMonitor.target(existing: nil, row: row, label: "build • minimax-m3", now: Date())
        XCTAssertEqual(next.status, .done)
    }

    func testOldSucceededIdleMarkerMapsToIdle() {
        let row = dbRow(timeIdle: Date(timeIntervalSince1970: 1_000_000), idleOutcome: "succeeded")
        let next = OpencodeMonitor.target(existing: nil, row: row, label: "build • minimax-m3", now: Date())
        XCTAssertEqual(next.status, .idle)
    }

    func testRunningSurvivesAStaleIdleMarker() {
        var existing = idleSession(status: .running)
        existing.turnStartedAt = Date()
        let row = dbRow(timeIdle: Date(timeIntervalSince1970: 1_000_000), idleOutcome: "succeeded")
        let next = OpencodeMonitor.target(existing: existing, row: row, label: "build • minimax-m3", now: Date())
        XCTAssertEqual(next.status, .running)
    }

    func testQuietStuckRunningDemotesToIdle() {
        // No idle marker, but neither the DB row nor the turn start has moved
        // in a full active window: no streaming happened, however the running
        // state arose. This is the phantom-timer killer.
        var existing = idleSession(status: .running)
        existing.turnStartedAt = Date(timeIntervalSince1970: 1_000_000)
        let row = dbRow(updatedAt: Date(timeIntervalSince1970: 1_000_000))
        let next = OpencodeMonitor.target(existing: existing, row: row, label: "build • minimax-m3", now: Date())
        XCTAssertEqual(next.status, .idle)
        XCTAssertNil(next.turnStartedAt)
    }

    func testFreshRunningSurvivesDespiteQuietRow() {
        // Prompt just posted (turn start now); the DB hasn't caught up yet.
        var existing = idleSession(status: .running)
        existing.turnStartedAt = Date()
        let row = dbRow(updatedAt: Date(timeIntervalSince1970: 1_000_000))
        let next = OpencodeMonitor.target(existing: existing, row: row, label: "build • minimax-m3", now: Date())
        XCTAssertEqual(next.status, .running)
    }

    func testRunningYieldsToANewerIdleMarker() {
        var existing = idleSession(status: .running)
        existing.turnStartedAt = Date(timeIntervalSince1970: 1_000_000)
        let row = dbRow(timeIdle: Date(), idleOutcome: "succeeded")
        let next = OpencodeMonitor.target(existing: existing, row: row, label: "build • minimax-m3", now: Date())
        XCTAssertEqual(next.status, .done)
    }

    func testNeedsYouIsNeverDemotedByTheDB() {
        let existing = idleSession(status: .needsYou("Wants to use Bash"))
        let row = dbRow(timeIdle: Date(), idleOutcome: "succeeded")
        let next = OpencodeMonitor.target(existing: existing, row: row, label: "build • minimax-m3", now: Date())
        XCTAssertEqual(next.status, .needsYou("Wants to use Bash"))
    }

    func testMissingDatabaseReportsUnavailable() {
        let snapshot = OpencodeMonitor.scan(dbPath: "/nonexistent/opencode.db")
        XCTAssertFalse(snapshot.dbAvailable)
        XCTAssertTrue(snapshot.rows.isEmpty)
    }

    func testMessageTokensSumsV2PartsWithoutTotal() {
        // v2 payloads carry no `total` field.
        let tokens: [String: Any] = ["input": 8382, "output": 204, "reasoning": 0, "cache": ["read": 138, "write": 0]]
        XCTAssertEqual(OpencodeMonitor.messageTokens(tokens), 8724)
    }

    func testScanReadsV2TableAndIgnoresV1() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("opencode.db").path
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path, &db), SQLITE_OK)
        func exec(_ sql: String) {
            XCTAssertEqual(sqlite3_exec(db, sql, nil, nil, nil), SQLITE_OK, sql)
        }
        let sessionCols = "(id TEXT PRIMARY KEY, project_id TEXT NOT NULL, directory TEXT NOT NULL, title TEXT, agent TEXT, model TEXT, cost REAL DEFAULT 0 NOT NULL, tokens_input INTEGER DEFAULT 0 NOT NULL, tokens_output INTEGER DEFAULT 0 NOT NULL, tokens_reasoning INTEGER DEFAULT 0 NOT NULL, tokens_cache_read INTEGER DEFAULT 0 NOT NULL, tokens_cache_write INTEGER DEFAULT 0 NOT NULL, parent_id TEXT, time_updated INTEGER NOT NULL, time_archived INTEGER, time_idle INTEGER, idle_outcome TEXT)"
        exec("CREATE TABLE session \(sessionCols)")
        exec("CREATE TABLE session_v2 \(sessionCols)")
        exec("CREATE TABLE session_message (id TEXT PRIMARY KEY, session_id TEXT NOT NULL, type TEXT NOT NULL, time_created INTEGER NOT NULL, data TEXT NOT NULL)")
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        exec("INSERT INTO session (id,project_id,directory,title,agent,model,time_updated) VALUES ('ses_v1','p','/old','Old v1','build','{\"id\":\"old\"}',\(nowMs))")
        exec("INSERT INTO session_v2 (id,project_id,directory,title,agent,model,time_updated) VALUES ('ses_v2','p','/Users/alpha/repo/NotchNull','Live v2','plan','{\"id\":\"muse-spark\"}',\(nowMs))")
        XCTAssertEqual(sqlite3_close(db), SQLITE_OK)
        db = nil
        let snapshot = OpencodeMonitor.scan(dbPath: path)
        XCTAssertTrue(snapshot.dbAvailable)
        XCTAssertEqual(snapshot.rows.map(\.id), ["ses_v2"])
        XCTAssertEqual(snapshot.rows.first?.directory, "/Users/alpha/repo/NotchNull")
        XCTAssertEqual(snapshot.rows.first?.model, #"{"id":"muse-spark"}"#)
    }

    func testPluginBodyUsesHookChannelAndNeverBlocks() {
        let body = OpencodePluginInstaller.pluginContents
        XCTAssertTrue(body.contains(Constants.Agents.hookMarker))
        XCTAssertTrue(body.contains(#"ctx.permission.hook("evaluate""#))
        XCTAssertTrue(body.contains(#"ctx.session.hook("prompt""#))
        XCTAssertTrue(body.contains(#"ctx.tool.hook("execute.before""#))
        XCTAssertTrue(body.contains(#"ctx.tool.hook("execute.after""#))
        XCTAssertTrue(body.contains("permission.replied"))
        XCTAssertTrue(body.contains("ctx.event.subscribe"))
        XCTAssertTrue(body.contains("/opencode"))
        // Fire-and-forget: no bare throw, aborts fetches instead of hanging.
        XCTAssertTrue(body.contains("AbortController"))
    }

    @MainActor
    func testHookPromptMovesSessionToRunning() {
        let store = AgentSessionStore()
        let handler = OpencodeHookHandler(store: store)
        handler.handle(AgentEventServer.Request(
            path: "/opencode", headers: [:],
            body: Data(#"{"sessionID":"ses_1","event":"prompt","cwd":"/tmp/app","message":"Refactor the theme loader please"}"#.utf8)
        ))
        let session = store.sessions.first { $0.id == "ses_1" }
        XCTAssertEqual(session?.provider, .opencode)
        XCTAssertEqual(session?.status, .running)
        XCTAssertEqual(session?.cwd, "/tmp/app")
        XCTAssertEqual(session?.detail, "Refactor the theme loader please")
    }

    @MainActor
    func testHookPermissionMovesSessionToNeedsYou() {
        let store = AgentSessionStore()
        let handler = OpencodeHookHandler(store: store)
        handler.handle(AgentEventServer.Request(
            path: "/opencode", headers: [:],
            body: Data(#"{"sessionID":"ses_2","event":"permission","cwd":"/tmp/app","message":"Wants to use Bash"}"#.utf8)
        ))
        XCTAssertTrue(store.sessions.first { $0.id == "ses_2" }?.needsAttention == true)
    }

    @MainActor
    func testHookPromptClearsNeedsYouAfterAnswer() {
        // Question answered (tool.execute.after) or permission replied posts
        // a `prompt` with no message: status must flip back to running while
        // keeping the previous detail and turn start.
        let store = AgentSessionStore()
        let handler = OpencodeHookHandler(store: store)
        handler.handle(AgentEventServer.Request(
            path: "/opencode", headers: [:],
            body: Data(#"{"sessionID":"ses_q","event":"prompt","cwd":"/tmp/app","message":"go"}"#.utf8)
        ))
        handler.handle(AgentEventServer.Request(
            path: "/opencode", headers: [:],
            body: Data(#"{"sessionID":"ses_q","event":"permission","cwd":"/tmp/app","message":"Has a question"}"#.utf8)
        ))
        XCTAssertTrue(store.sessions.first { $0.id == "ses_q" }?.needsAttention == true)
        let turnStart = store.sessions.first { $0.id == "ses_q" }?.turnStartedAt
        handler.handle(AgentEventServer.Request(
            path: "/opencode", headers: [:],
            body: Data(#"{"sessionID":"ses_q","event":"prompt","cwd":"/tmp/app"}"#.utf8)
        ))
        let session = store.sessions.first { $0.id == "ses_q" }
        XCTAssertEqual(session?.status, .running)
        XCTAssertEqual(session?.detail, "go")
        XCTAssertEqual(session?.turnStartedAt, turnStart)
    }

    @MainActor
    func testHookResumedClearsNeedsYou() {
        let store = AgentSessionStore()
        let handler = OpencodeHookHandler(store: store)
        handler.handle(AgentEventServer.Request(
            path: "/opencode", headers: [:],
            body: Data(#"{"sessionID":"ses_r","event":"question","cwd":"/tmp/app","message":"Has a question"}"#.utf8)
        ))
        XCTAssertTrue(store.sessions.first { $0.id == "ses_r" }?.needsAttention == true)
        handler.handle(AgentEventServer.Request(
            path: "/opencode", headers: [:],
            body: Data(#"{"sessionID":"ses_r","event":"resumed","cwd":"/tmp/app"}"#.utf8)
        ))
        XCTAssertEqual(store.sessions.first { $0.id == "ses_r" }?.status, .running)
    }

    @MainActor
    func testHookCompleteMovesSessionToDoneWithTruncatedSummary() {
        let store = AgentSessionStore()
        let handler = OpencodeHookHandler(store: store)
        let long = String(repeating: "done work ", count: 40)
        handler.handle(AgentEventServer.Request(
            path: "/opencode", headers: [:],
            body: Data(#"{"sessionID":"ses_3","event":"prompt","cwd":"/tmp/app","message":"go"}"#.utf8)
        ))
        handler.handle(AgentEventServer.Request(
            path: "/opencode", headers: [:],
            body: Data(#"{"sessionID":"ses_3","event":"complete","cwd":"/tmp/app","message":"\#(long)"}"#.utf8)
        ))
        let session = store.sessions.first { $0.id == "ses_3" }
        XCTAssertEqual(session?.status, .done)
        XCTAssertNotNil(session?.detail)
        XCTAssertLessThanOrEqual(session?.detail?.count ?? 0, 161)
    }

    @MainActor
    func testHookErrorIdlesRunningSessionAndIgnoresWrongPath() {
        let store = AgentSessionStore()
        let handler = OpencodeHookHandler(store: store)
        handler.handle(AgentEventServer.Request(
            path: "/opencode", headers: [:],
            body: Data(#"{"sessionID":"ses_4","event":"prompt","cwd":"/tmp/app","message":"go"}"#.utf8)
        ))
        handler.handle(AgentEventServer.Request(
            path: "/opencode", headers: [:],
            body: Data(#"{"sessionID":"ses_4","event":"error","cwd":"/tmp/app"}"#.utf8)
        ))
        XCTAssertEqual(store.sessions.first { $0.id == "ses_4" }?.status, .idle)
        handler.handle(AgentEventServer.Request(
            path: "/claude", headers: [:],
            body: Data(#"{"sessionID":"ses_4","event":"prompt"}"#.utf8)
        ))
        // Wrong path is ignored by this handler (Claude handler owns /claude).
        XCTAssertEqual(store.sessions.first { $0.id == "ses_4" }?.status, .idle)
    }

    @MainActor
    func testHookErrorClearsNeedsYouOnCancel() {
        // Cancelling mid-tool-call (e.g. dismissing a question) posts
        // `error`/`interrupted` with no answer coming; the banner must hide.
        let store = AgentSessionStore()
        let handler = OpencodeHookHandler(store: store)
        handler.handle(AgentEventServer.Request(
            path: "/opencode", headers: [:],
            body: Data(#"{"sessionID":"ses_c","event":"permission","cwd":"/tmp/app","message":"Has a question"}"#.utf8)
        ))
        XCTAssertTrue(store.sessions.first { $0.id == "ses_c" }?.needsAttention == true)
        handler.handle(AgentEventServer.Request(
            path: "/opencode", headers: [:],
            body: Data(#"{"sessionID":"ses_c","event":"interrupted","cwd":"/tmp/app"}"#.utf8)
        ))
        XCTAssertEqual(store.sessions.first { $0.id == "ses_c" }?.status, .idle)
    }
}
