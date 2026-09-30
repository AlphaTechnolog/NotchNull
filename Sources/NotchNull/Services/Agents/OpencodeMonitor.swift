import Combine
import Foundation
import SQLite3
import SwiftUI

/// opencode state from its SQLite store (`~/.local/share/opencode/opencode.db`, WAL):
/// live session rows per top-level session plus today's token totals.
/// Passive observer only: read-only open, `LIMIT 12`, never blocks the UI.
/// Instant running/needsYou/done transitions arrive via `OpencodeHookHandler`
/// (the `~/.config/opencode/plugins/notchnull.js` plugin); the DB poll covers
/// sessions started without the plugin and idles quiet ones.
@MainActor
final class OpencodeMonitor: ObservableObject {
    @Published private(set) var usage = ProviderUsage.placeholder(.opencode)
    @Published private(set) var tokens = TokenTally()

    private let store: AgentSessionStore
    private let queue = DispatchQueue(label: "dev.notchnull.opencode", qos: .utility)
    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    // Background-queue state.
    private nonisolated(unsafe) var announced: Set<String> = []
    private nonisolated(unsafe) var tokenDay = Calendar.current.startOfDay(for: Date())

    init(store: AgentSessionStore) {
        self.store = store
    }

    func start() {
        Preferences.shared.$opencodeEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in enabled ? self?.resume() : self?.pause() }
            .store(in: &cancellables)
    }

    /// Fixture entry point for snapshot rendering.
    func preview(usage: ProviderUsage, tokens: TokenTally) {
        self.usage = usage
        self.tokens = tokens
    }

    private func resume() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Constants.Agents.opencodePollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        poll()
    }

    private func pause() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        queue.async { [weak self] in
            guard let self else { return }
            let snapshot = Self.scan()
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self.apply(snapshot) }
            }
        }
    }

    // MARK: - Row model (pure, tested)

    struct Row {
        var id: String
        var directory: String
        var title: String?
        var agent: String?
        var model: String?
        var cost: Double
        var tokensInput: Int
        var tokensOutput: Int
        var tokensReasoning: Int
        var tokensCacheRead: Int
        var tokensCacheWrite: Int
        var updatedAt: Date
        /// When the current turn went idle (`idle_outcome`: succeeded/interrupted/…).
        /// Nil while a turn is in flight — this is the "actually running" signal,
        /// replacing the earlier recency heuristic that marked recently-touched
        /// (viewed/synced) rows as running.
        var timeIdle: Date?
        var idleOutcome: String?
    }

    struct Snapshot {
        var rows: [Row]
        var tally: TokenTally
        var dbAvailable: Bool
    }

    /// ms epoch (opencode) vs s epoch disambiguation.
    nonisolated static func normalizeTime(_ raw: Int64) -> Date {
        raw > 1_000_000_000_000 ? Date(timeIntervalSince1970: Double(raw) / 1000) : Date(timeIntervalSince1970: Double(raw))
    }

    /// `parent_id != null` rows are subagents and never surface.
    nonisolated static func shouldInclude(parentID: String?, timeArchived: Int64?) -> Bool {
        guard parentID == nil || parentID?.isEmpty == true else { return false }
        return timeArchived == nil || timeArchived == 0
    }

    /// Extracts the model id from the JSON blob opencode stores
    /// (`{"id":"big-pickle","providerID":"opencode",...}`), else the raw string.
    nonisolated static func parseModelID(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix("{"),
           let data = raw.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let id = json["id"] as? String, !id.isEmpty {
            return id
        }
        return raw
    }

    /// Chip shown in the plan pill: `agent • model`, either half, or nil.
    nonisolated static func label(agent: String?, model: String?) -> String? {
        let parsed = parseModelID(model)
        let a: String? = (agent?.isEmpty == false) ? agent : nil
        let m: String? = (parsed?.isEmpty == false) ? parsed : nil
        if let a, let m { return "\(a) • \(m)" }
        if let a { return a }
        if let m { return m }
        return nil
    }

    nonisolated static func totalTokens(_ row: Row) -> Int {
        row.tokensInput + row.tokensOutput + row.tokensReasoning + row.tokensCacheRead + row.tokensCacheWrite
    }

    // MARK: - Scanning (background queue)

    private nonisolated func currentSnapshot() -> Snapshot {
        Self.scan()
    }

    nonisolated static func scan(dbPath: String = Constants.Paths.opencodeDB.path) -> Snapshot {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(dbPath, &db, flags, nil) == SQLITE_OK, let db else {
            return Snapshot(rows: [], tally: TokenTally(), dbAvailable: false)
        }
        defer { sqlite3_close(db) }
        // Never wait on a writer; fail fast and report unavailable.
        sqlite3_busy_timeout(db, 0)

        guard let rows = readSessions(db) else {
            return Snapshot(rows: [], tally: TokenTally(), dbAvailable: false)
        }
        let tally = readTodayTally(db, rows: rows)
        return Snapshot(rows: rows, tally: tally, dbAvailable: true)
    }

    private nonisolated static func readSessions(_ db: OpaquePointer) -> [Row]? {
        // v2 table holds live sessions; the v1 `session` table is migrated
        // history (pre-2.0) and is intentionally never read.
        let sql = """
        SELECT id,directory,title,agent,model,cost,tokens_input,tokens_output,
               tokens_reasoning,tokens_cache_read,tokens_cache_write,
               parent_id,time_updated,time_archived,time_idle,idle_outcome
        FROM session_v2 ORDER BY time_updated DESC LIMIT 60
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return nil }
        defer { sqlite3_finalize(stmt) }
        var rows: [Row] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = stringColumn(stmt, 0) ?? ""
            guard !id.isEmpty else { continue }
            let parentID = stringColumn(stmt, 11)
            let archived: Int64? = sqlite3_column_type(stmt, 13) == SQLITE_NULL ? nil : sqlite3_column_int64(stmt, 13)
            guard shouldInclude(parentID: parentID?.isEmpty == true ? nil : parentID, timeArchived: archived) else { continue }
            let rawUpdated = sqlite3_column_int64(stmt, 12)
            rows.append(Row(
                id: id,
                directory: stringColumn(stmt, 1) ?? "",
                title: stringColumn(stmt, 2),
                agent: stringColumn(stmt, 3),
                model: stringColumn(stmt, 4),
                cost: sqlite3_column_double(stmt, 5),
                tokensInput: Int(sqlite3_column_int64(stmt, 6)),
                tokensOutput: Int(sqlite3_column_int64(stmt, 7)),
                tokensReasoning: Int(sqlite3_column_int64(stmt, 8)),
                tokensCacheRead: Int(sqlite3_column_int64(stmt, 9)),
                tokensCacheWrite: Int(sqlite3_column_int64(stmt, 10)),
                updatedAt: normalizeTime(rawUpdated),
                timeIdle: sqlite3_column_type(stmt, 14) == SQLITE_NULL ? nil : normalizeTime(sqlite3_column_int64(stmt, 14)),
                idleOutcome: stringColumn(stmt, 15)
            ))
            if rows.count >= 12 { break }
        }
        return rows
    }

    /// Today's totals come from session rows updated today (no full-table message
    /// scan on a ~1GB DB); hourly buckets come from a capped `message` sample and
    /// stay zero when the sample has nothing parseable.
    private nonisolated static func readTodayTally(_ db: OpaquePointer, rows: [Row]) -> TokenTally {
        var tally = TokenTally()
        let today = Calendar.current.startOfDay(for: Date())
        let dayMs: Int64 = Int64(today.timeIntervalSince1970 * 1000)
        // Session totals for rows touched today.
        let sql = "SELECT tokens_input,tokens_output,tokens_reasoning,tokens_cache_read,tokens_cache_write,time_updated FROM session_v2 WHERE parent_id IS NULL AND time_archived IS NULL AND time_updated >= ? LIMIT 500"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt {
            sqlite3_bind_int64(stmt, 1, dayMs)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let total = Int(sqlite3_column_int64(stmt, 0) + sqlite3_column_int64(stmt, 1) + sqlite3_column_int64(stmt, 2) + sqlite3_column_int64(stmt, 3) + sqlite3_column_int64(stmt, 4))
                tally.today += total
                tally.output += Int(sqlite3_column_int64(stmt, 1))
                let hour = Calendar.current.component(.hour, from: normalizeTime(sqlite3_column_int64(stmt, 5)))
                if hour >= 0, hour < 24 { tally.hourly[hour] += total }
            }
            sqlite3_finalize(stmt)
        }
        // Refine hourly buckets from v2 assistant messages when available.
        // Assistant-ness comes from the `type` column; v2 payloads carry
        // `tokens:{input,output,reasoning,cache}` with no `total` field.
        let messageSQL = "SELECT time_created,data FROM session_message WHERE time_created >= ? AND type = 'assistant' ORDER BY time_created DESC LIMIT 2000"
        var messageCount = 0
        var hourly = tally.hourly
        var hourlyFromMessages = Array(repeating: 0, count: 24)
        var foundMessageTokens = false
        var mstmt: OpaquePointer?
        if sqlite3_prepare_v2(db, messageSQL, -1, &mstmt, nil) == SQLITE_OK, let mstmt {
            sqlite3_bind_int64(mstmt, 1, dayMs)
            while sqlite3_step(mstmt) == SQLITE_ROW {
                messageCount += 1
                let created = normalizeTime(sqlite3_column_int64(mstmt, 0))
                guard let bytes = sqlite3_column_text(mstmt, 1) else { continue }
                let json = String(cString: bytes)
                guard let data = json.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tokens = obj["tokens"] as? [String: Any] else { continue }
                let total = Self.messageTokens(tokens)
                guard total > 0 else { continue }
                foundMessageTokens = true
                let hour = Calendar.current.component(.hour, from: created)
                if hour >= 0, hour < 24 { hourlyFromMessages[hour] += total }
            }
            sqlite3_finalize(mstmt)
        }
        if foundMessageTokens { hourly = hourlyFromMessages }
        tally.hourly = hourly
        if messageCount > 0 { tally.messages = messageCount }
        return tally
    }

    nonisolated static func messageTokens(_ tokens: [String: Any]) -> Int {
        if let total = (tokens["total"] as? NSNumber)?.intValue, total > 0 { return total }
        var sum = 0
        for key in ["input", "output", "reasoning"] {
            sum += (tokens[key] as? NSNumber)?.intValue ?? 0
        }
        if let cache = tokens["cache"] as? [String: Any] {
            sum += (cache["read"] as? NSNumber)?.intValue ?? 0
            sum += (cache["write"] as? NSNumber)?.intValue ?? 0
        }
        return sum
    }

    private nonisolated static func stringColumn(_ stmt: OpaquePointer, _ index: Int32) -> String? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL, let bytes = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: bytes)
    }

    // MARK: - Applying (main)

    /// The full session state a DB row maps to. `apply` skips the upsert when
    /// the target already matches, because `AgentSessionStore.upsert` stamps
    /// `updatedAt = now` — without the skip, every 2s poll would keep idle
    /// rows reading "just now" forever.
    struct Target: Equatable {
        var status: AgentSession.Status
        var cwd: String
        var origin: String?
        var detail: String?
        var turnStartedAt: Date?
    }

    /// Pure mapping from a DB row (+ the current session, if any) to its
    /// target state. Deliberately one-sided: the DB can only report rest.
    /// `.running` comes solely from the plugin's `prompt` event (ground truth
    /// of activity) — the DB has no reliable activity signal (`time_updated`
    /// bumps on views/syncs; missing idle markers outlive crashed turns), so
    /// letting it promote to running produced phantom sessions and timers.
    /// Rules:
    /// - unknown/`.idle` rows → recent-`succeeded` becomes `.done`, else `.idle`.
    /// - hook-posted `.running` yields only to a *newer* idle marker
    ///   (`succeeded` → `.done`, anything else → `.idle`), or to a full
    ///   active window of DB quiet (no streaming happened however the running
    ///   state arose).
    /// - hook-posted `.needsYou`/`.done` are never touched by the DB.
    nonisolated static func target(existing: AgentSession?, row: Row, label: String?, now: Date) -> Target {
        let titleDetail = row.title?.isEmpty == true ? nil : row.title
        let quietCutoff = now.addingTimeInterval(-Constants.Agents.opencodeActiveWindow)
        func rested() -> Target {
            if row.timeIdle != nil, row.idleOutcome == "succeeded", let idleAt = row.timeIdle, idleAt >= quietCutoff {
                return Target(status: .done, cwd: row.directory, origin: label, detail: titleDetail, turnStartedAt: nil)
            }
            return Target(status: .idle, cwd: row.directory, origin: label, detail: titleDetail, turnStartedAt: nil)
        }
        guard let existing else { return rested() }
        switch existing.status {
        case .idle:
            // Fill detail once; later title rewrites must not bump timestamps.
            if rested().status == .done { return rested() }
            let detail = existing.detail?.isEmpty == true ? titleDetail : existing.detail
            return Target(status: .idle, cwd: row.directory, origin: label, detail: detail, turnStartedAt: nil)
        case .running:
            let start = existing.turnStartedAt ?? .distantPast
            if let idleAt = row.timeIdle, idleAt > start {
                let detail = existing.detail?.isEmpty == true ? titleDetail : existing.detail
                if row.idleOutcome == "succeeded" {
                    return Target(status: .done, cwd: row.directory, origin: label, detail: detail, turnStartedAt: nil)
                }
                return Target(status: .idle, cwd: row.directory, origin: label, detail: detail, turnStartedAt: nil)
            }
            if row.updatedAt < quietCutoff, start < quietCutoff {
                let detail = existing.detail?.isEmpty == true ? titleDetail : existing.detail
                return Target(status: .idle, cwd: row.directory, origin: label, detail: detail, turnStartedAt: nil)
            }
            return Target(status: .running, cwd: row.directory, origin: label, detail: existing.detail, turnStartedAt: existing.turnStartedAt)
        case .needsYou, .done:
            return Target(status: existing.status, cwd: row.directory, origin: label, detail: existing.detail, turnStartedAt: existing.turnStartedAt)
        }
    }

    private func apply(_ snapshot: Snapshot) {
        guard Preferences.shared.opencodeEnabled else { return }
        let now = Date()
        let liveIDs = Set(snapshot.rows.map(\.id))
        for row in snapshot.rows {
            let label = Self.label(agent: row.agent, model: row.model)
            let existing = store.sessions.first(where: { $0.id == row.id })
            let next = Self.target(existing: existing, row: row, label: label, now: now)
            if let existing,
               existing.status == next.status, existing.cwd == next.cwd,
               existing.origin == next.origin, existing.detail == next.detail,
               existing.turnStartedAt == next.turnStartedAt {
                continue
            }
            store.upsert(id: row.id, provider: .opencode) { session in
                session.status = next.status
                session.cwd = next.cwd
                session.origin = next.origin
                session.detail = next.detail
                session.turnStartedAt = next.turnStartedAt
            }
        }
        // Sessions that fell out of the recent list are no longer live.
        // Guarded the same way: no upsert (and no updatedAt bump) for rows
        // that are already idle.
        for id in announced.subtracting(liveIDs) {
            if let session = store.sessions.first(where: { $0.id == id }), session.status == .running {
                store.upsert(id: id, provider: .opencode) { $0.status = .idle }
            }
        }
        announced = liveIDs
        // Plugin-posted running rows with no live DB row (or no DB row at
        // all): a turn quiet for a full active window is stuck, never live.
        // A genuinely streaming turn keeps its DB row fresh, so this only
        // reaps orphans like completions the plugin never delivered.
        let staleCutoff = now.addingTimeInterval(-Constants.Agents.opencodeActiveWindow)
        for session in store.sessions where session.provider == .opencode {
            guard session.status == .running, !liveIDs.contains(session.id),
                  (session.turnStartedAt ?? .distantPast) < staleCutoff else { continue }
            store.upsert(id: session.id, provider: .opencode) { $0.status = .idle }
        }

        if snapshot.tally != tokens { withAnimation(Motion.state) { tokens = snapshot.tally } }
        let plan = snapshot.rows.first.flatMap { Self.label(agent: $0.agent, model: $0.model) }
        let next: ProviderUsage
        if !snapshot.dbAvailable {
            next = ProviderUsage(provider: .opencode, plan: plan, updatedAt: now, state: .unavailable("opencode database unavailable"))
        } else if snapshot.rows.isEmpty {
            next = ProviderUsage(provider: .opencode, plan: nil, updatedAt: now, state: .unavailable("No opencode sessions yet"))
        } else {
            // Opencode is BYO-keys: no rate-limit windows, so `.ready` with
            // empty windows renders just the title row (no warning line).
            next = ProviderUsage(provider: .opencode, plan: plan, updatedAt: now, state: .ready)
        }
        if next != usage { withAnimation(Motion.state) { usage = next } }
    }
}
