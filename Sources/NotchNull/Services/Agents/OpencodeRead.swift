import Foundation
import SQLite3

/// Persistent, read-only reader for opencode's SQLite store.
///
/// The monitor owns one reader and calls it only from its serial utility queue.
/// The reader keeps one connection open, skips work when neither SQLite's
/// `data_version` nor the database/WAL stat fingerprint changed, and maintains
/// a per-day incremental token history while the Agents tab is visible.
final class OpencodeReader {
    struct FileIdentity: Equatable {
        var inode: UInt64
        var size: Int64
        var modified: Double
    }

    struct StoreIdentity: Equatable {
        var database: FileIdentity?
        var wal: FileIdentity?
    }

    struct Day {
        var start: Date
        var end: Date
        var startMs: Int64
        var endMs: Int64
    }

    struct History {
        var dayStartMs: Int64
        var cursorMs: Int64
        var tally: TokenTally
        var lastReconciliation: Date
    }

    struct Aggregate {
        var tally: TokenTally
        var maxCreatedMs: Int64?
        var rowsRead: Int
    }

    private enum ReadError: Error {
        case sqlite(String)
        case unsupportedPayload
        case json1Unavailable
    }

    let dbPath: String
    private let now: () -> Date
    private let usesJSON1: Bool

    private var db: OpaquePointer?
    private var connectionInode: UInt64?
    private var observedInode: UInt64?
    private var observedDayStartMs: Int64?
    private var fingerprint: StoreIdentity?
    private var dataVersion: Int64?
    private var cached: OpencodeMonitor.Snapshot?
    private(set) var history: History?
    private var lastTally = TokenTally()
    private var usageAvailable = true
    private var json1Available: Bool?
    private var lastVisible = false

    init(dbPath: String, usesJSON1: Bool = true, now: @escaping () -> Date = Date.init) {
        self.dbPath = dbPath
        self.usesJSON1 = usesJSON1
        self.now = now
    }

    deinit {
        close()
    }

    /// One scan of session state plus, only while `visible`, token history.
    /// `forceBaseline` is used by the monitor when a visibility consumer opens;
    /// transition tracking below also establishes a baseline on its own.
    func scan(visible: Bool, forceBaseline: Bool = false) -> OpencodeMonitor.Snapshot {
        let date = now()
        let day = Self.day(containing: date)
        let identity = Self.identity(at: dbPath)
        var diagnostics = OpencodeMonitor.ScanDiagnostics(usageVisible: visible)

        var replacement = false
        if let observedInode, let currentInode = identity.database?.inode, currentInode != observedInode {
            replacement = true
        }
        let dayChanged = observedDayStartMs.map { $0 != day.startMs } ?? false
        if let currentInode = identity.database?.inode { observedInode = currentInode }
        observedDayStartMs = day.startMs

        if replacement || dayChanged {
            // Cached token history belongs to the old day or the old file.
            history = nil
            lastTally = TokenTally()
            usageAvailable = true
            cached = nil
        }

        guard identity.database != nil else {
            close()
            cached = nil
            usageAvailable = false
            diagnostics.unavailableReason = "opencode database unavailable"
            return OpencodeMonitor.Snapshot(
                rows: [], tally: lastTally, dbAvailable: false,
                usageAvailable: false, diagnostics: diagnostics
            )
        }

        let connectionWasOpened = ensureConnection(identity)
        guard db != nil else {
            cached = nil
            usageAvailable = false
            diagnostics.unavailableReason = "opencode database unavailable"
            return OpencodeMonitor.Snapshot(
                rows: [], tally: lastTally, dbAvailable: false,
                usageAvailable: false, diagnostics: diagnostics
            )
        }
        let currentVersion = readDataVersion()
        let storeChanged = fingerprint != identity
            || (currentVersion != nil && dataVersion != nil && currentVersion != dataVersion)
        let changed = cached == nil || connectionWasOpened || replacement || dayChanged || storeChanged

        let becameVisible = visible && !lastVisible
        lastVisible = visible

        var baseline = false
        var reconcile = false
        var delta = false
        if visible {
            if history == nil || !usageAvailable || forceBaseline || becameVisible || replacement || dayChanged {
                baseline = true
            } else if let last = history?.lastReconciliation,
                      date.timeIntervalSince(last) >= Constants.Agents.opencodeReconcileInterval {
                reconcile = true
            } else if changed, usesJSON1, json1Available != false {
                // With no JSON1, there is no cheap delta. Wait for the bounded
                // reconciliation instead of reparsing the day on every write.
                delta = true
            }
        }

        if !changed && !baseline && !reconcile {
            guard let cached else {
                return OpencodeMonitor.Snapshot(
                    rows: [], tally: lastTally, dbAvailable: false,
                    usageAvailable: false, diagnostics: diagnostics
                )
            }
            diagnostics.cacheHit = true
            var snapshot = cached
            snapshot.diagnostics = diagnostics
            return snapshot
        }

        var rows = cached?.rows ?? []
        if changed || cached == nil {
            guard let next = readSessions(identity: identity) else {
                cached = nil
                usageAvailable = false
                fingerprint = identity
                dataVersion = currentVersion
                diagnostics.unavailableReason = "opencode database unavailable"
                return OpencodeMonitor.Snapshot(
                    rows: [], tally: lastTally, dbAvailable: false,
                    usageAvailable: false, diagnostics: diagnostics
                )
            }
            rows = next
        }

        if baseline || reconcile {
            diagnostics.reconciliationRan = true
            do {
                let (aggregate, usedFallback) = try fullAggregate(day: day)
                applyBaseline(aggregate, day: day, at: date)
                diagnostics.messageRowsRead = aggregate.rowsRead
                diagnostics.usedFallback = usedFallback
            } catch {
                usageAvailable = false
                diagnostics.unavailableReason = "opencode usage unavailable"
            }
        } else if delta, let currentHistory = history {
            do {
                let aggregate = try incrementalAggregate(after: currentHistory.cursorMs, day: day)
                applyDelta(aggregate)
                diagnostics.messageRowsRead = aggregate.rowsRead
                diagnostics.deltaRan = true
            } catch {
                usageAvailable = false
                diagnostics.unavailableReason = "opencode usage unavailable"
            }
        }

        fingerprint = identity
        dataVersion = readDataVersion()
        let snapshot = OpencodeMonitor.Snapshot(
            rows: rows, tally: lastTally, dbAvailable: true,
            usageAvailable: usageAvailable, diagnostics: diagnostics
        )
        // A failed usage read is retried on the next poll, not served from cache.
        cached = usageAvailable ? snapshot : nil
        return snapshot
    }

    // MARK: - Connection and change detection

    /// A schema change or a replaced file can leave the prepared statements
    /// invalid. Reopen once and retry; locks are left for the next poll.
    private func readSessions(identity: StoreIdentity) -> [OpencodeMonitor.Row]? {
        guard let db else { return nil }
        if let rows = OpencodeMonitor.readSessions(db) { return rows }
        let code = sqlite3_errcode(db)
        guard code == SQLITE_SCHEMA || code == SQLITE_NOTADB else { return nil }
        close()
        guard ensureConnection(identity), let reopened = self.db else { return nil }
        return OpencodeMonitor.readSessions(reopened)
    }

    private func ensureConnection(_ identity: StoreIdentity) -> Bool {
        guard let inode = identity.database?.inode else {
            close()
            return false
        }
        if db != nil, connectionInode == inode { return false }
        close()
        guard let opened = Self.openReadOnly(dbPath) else { return false }
        db = opened
        connectionInode = inode
        sqlite3_busy_timeout(opened, 0)
        json1Available = usesJSON1 ? Self.probeJSON1(opened) : false
        fingerprint = identity
        dataVersion = readDataVersion()
        return true
    }

    private func close() {
        if let db { sqlite3_close(db) }
        db = nil
        connectionInode = nil
        fingerprint = nil
        dataVersion = nil
    }

    private func readDataVersion() -> Int64? {
        guard let db else { return nil }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA data_version", -1, &stmt, nil) == SQLITE_OK, let stmt else { return nil }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return sqlite3_column_int64(stmt, 0)
    }

    private static func openReadOnly(_ path: String) -> OpaquePointer? {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK, let handle else {
            if let handle { sqlite3_close(handle) }
            return nil
        }
        return handle
    }

    private static func probeJSON1(_ db: OpaquePointer) -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, #"SELECT json_extract('{"a":1}', '$.a')"#, -1, &stmt, nil) == SQLITE_OK,
              let stmt else { return false }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW && sqlite3_column_int64(stmt, 0) == 1
    }

    private static func identity(at path: String) -> StoreIdentity {
        StoreIdentity(
            database: fileIdentity(at: path),
            wal: fileIdentity(at: path + "-wal")
        )
    }

    private static func fileIdentity(at path: String) -> FileIdentity? {
        var info = stat()
        guard stat(path, &info) == 0 else { return nil }
        return FileIdentity(
            inode: UInt64(info.st_ino),
            size: Int64(info.st_size),
            modified: Double(info.st_mtimespec.tv_sec) + Double(info.st_mtimespec.tv_nsec) / 1_000_000_000
        )
    }

    private static func day(containing date: Date, calendar: Calendar = .current) -> Day {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return Day(
            start: start,
            end: end,
            startMs: Int64((start.timeIntervalSince1970 * 1000).rounded()),
            endMs: Int64((end.timeIntervalSince1970 * 1000).rounded())
        )
    }

    // MARK: - SQL aggregate

    private func fullAggregate(day: Day) throws -> (Aggregate, Bool) {
        if usesJSON1, json1Available != false {
            if json1Available == nil { json1Available = Self.probeJSON1(db!) }
            if json1Available == true {
                do {
                    return (try aggregateSQL(from: day.startMs, before: day.endMs, after: nil), false)
                } catch {
                    // JSON1 can be absent at runtime, and a payload may not match the
                    // expected shape. Try the existing Swift parser before declaring
                    // usage unavailable.
                    return (try fallbackAggregate(day: day), true)
                }
            }
        }
        return (try fallbackAggregate(day: day), true)
    }

    private func incrementalAggregate(after cursor: Int64, day: Day) throws -> Aggregate {
        guard usesJSON1, json1Available != false else { throw ReadError.json1Unavailable }
        if json1Available == nil { json1Available = Self.probeJSON1(db!) }
        guard json1Available == true else { throw ReadError.json1Unavailable }
        return try aggregateSQL(from: day.startMs, before: day.endMs, after: cursor)
    }

    private func aggregateSQL(from startMs: Int64, before endMs: Int64, after cursor: Int64?) throws -> Aggregate {
        guard let db else { throw ReadError.sqlite("database closed") }

        if try invalidPayloadCount(from: startMs, before: endMs, after: cursor) > 0 {
            throw ReadError.unsupportedPayload
        }

        let comparison = cursor == nil ? "time_created >= ? AND time_created < ?" : "time_created > ? AND time_created < ?"
        let sql = """
        SELECT CAST(strftime('%H', time_created / 1000, 'unixepoch', 'localtime') AS INTEGER) AS hour,
               COALESCE(SUM(
                   CASE
                       WHEN json_type(data, '$.tokens.total') IN ('integer', 'real')
                            AND json_extract(data, '$.tokens.total') > 0
                       THEN json_extract(data, '$.tokens.total')
                       ELSE COALESCE(json_extract(data, '$.tokens.input'), 0)
                            + COALESCE(json_extract(data, '$.tokens.output'), 0)
                            + COALESCE(json_extract(data, '$.tokens.reasoning'), 0)
                            + COALESCE(json_extract(data, '$.tokens.cache.read'), 0)
                            + COALESCE(json_extract(data, '$.tokens.cache.write'), 0)
                   END), 0) AS total,
               COALESCE(SUM(
                   CASE
                       WHEN json_type(data, '$.tokens.output') IN ('integer', 'real')
                       THEN json_extract(data, '$.tokens.output')
                       ELSE 0
                   END), 0) AS output,
               COUNT(*) AS messages,
               MAX(time_created) AS newest
        FROM session_message
        WHERE type = 'assistant' AND \(comparison) AND json_valid(data)
        GROUP BY hour
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ReadError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, cursor ?? startMs)
        sqlite3_bind_int64(stmt, 2, endMs)

        var tally = TokenTally()
        var newest: Int64?
        var rows = 0
        while true {
            let step = sqlite3_step(stmt)
            if step == SQLITE_DONE { break }
            guard step == SQLITE_ROW else {
                throw ReadError.sqlite(String(cString: sqlite3_errmsg(db)))
            }
            let hour = Int(sqlite3_column_int64(stmt, 0))
            let total = Int(sqlite3_column_int64(stmt, 1))
            let output = Int(sqlite3_column_int64(stmt, 2))
            let count = Int(sqlite3_column_int64(stmt, 3))
            if let raw = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : sqlite3_column_int64(stmt, 4) {
                newest = max(newest ?? raw, raw)
            }
            tally.today += total
            tally.output += output
            if hour >= 0, hour < 24 { tally.hourly[hour] += total }
            tally.messages += count
            rows += count
        }
        return Aggregate(tally: tally, maxCreatedMs: newest, rowsRead: rows)
    }

    private func invalidPayloadCount(from startMs: Int64, before endMs: Int64, after cursor: Int64?) throws -> Int {
        guard let db else { throw ReadError.sqlite("database closed") }
        let comparison = cursor == nil ? "time_created >= ? AND time_created < ?" : "time_created > ? AND time_created < ?"
        let malformedSQL = "SELECT COUNT(*) FROM session_message WHERE type = 'assistant' AND \(comparison) AND NOT json_valid(data)"
        if try count(db, sql: malformedSQL, startMs: startMs, endMs: endMs, after: cursor) > 0 {
            return 1
        }
        let shapeSQL = """
        SELECT COUNT(*) FROM session_message
        WHERE type = 'assistant' AND \(comparison)
          AND (
              (json_type(data, '$.tokens') IS NOT NULL AND json_type(data, '$.tokens') <> 'object')
              OR json_type(data, '$.tokens.total') NOT IN ('integer', 'real', 'null')
              OR json_type(data, '$.tokens.input') NOT IN ('integer', 'real', 'null')
              OR json_type(data, '$.tokens.output') NOT IN ('integer', 'real', 'null')
              OR json_type(data, '$.tokens.reasoning') NOT IN ('integer', 'real', 'null')
              OR (json_type(data, '$.tokens.cache') IS NOT NULL AND json_type(data, '$.tokens.cache') <> 'object')
              OR json_type(data, '$.tokens.cache.read') NOT IN ('integer', 'real', 'null')
              OR json_type(data, '$.tokens.cache.write') NOT IN ('integer', 'real', 'null')
          )
        """
        return try count(db, sql: shapeSQL, startMs: startMs, endMs: endMs, after: cursor)
    }

    private func count(_ db: OpaquePointer, sql: String, startMs: Int64, endMs: Int64, after cursor: Int64?) throws -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ReadError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, cursor ?? startMs)
        sqlite3_bind_int64(stmt, 2, endMs)
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw ReadError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    private func fallbackAggregate(day: Day) throws -> Aggregate {
        guard let db else { throw ReadError.sqlite("database closed") }
        let sql = """
        SELECT time_created, data FROM session_message
        WHERE type = 'assistant' AND time_created >= ? AND time_created < ?
        ORDER BY time_created
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ReadError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, day.startMs)
        sqlite3_bind_int64(stmt, 2, day.endMs)

        var tally = TokenTally()
        var newest: Int64?
        var rows = 0
        while true {
            let step = sqlite3_step(stmt)
            if step == SQLITE_DONE { break }
            guard step == SQLITE_ROW else {
                throw ReadError.sqlite(String(cString: sqlite3_errmsg(db)))
            }
            rows += 1
            let createdMs = sqlite3_column_int64(stmt, 0)
            newest = max(newest ?? createdMs, createdMs)
            let length = Int(sqlite3_column_bytes(stmt, 1))
            guard sqlite3_column_type(stmt, 1) != SQLITE_NULL,
                  let bytes = sqlite3_column_text(stmt, 1), length > 0
            else { throw ReadError.unsupportedPayload }
            let data = Data(bytes: bytes, count: length)
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ReadError.unsupportedPayload
            }
            guard let rawTokens = object["tokens"], !(rawTokens is NSNull) else { continue }
            guard let tokens = rawTokens as? [String: Any],
                  Self.hasSupportedTokenShape(tokens) else { throw ReadError.unsupportedPayload }
            let total = OpencodeMonitor.messageTokens(tokens)
            guard total > 0 else { continue }
            let created = OpencodeMonitor.normalizeTime(createdMs)
            let hour = Calendar.current.component(.hour, from: created)
            if hour >= 0, hour < 24 { tally.hourly[hour] += total }
            tally.today += total
            tally.output += (tokens["output"] as? NSNumber)?.intValue ?? 0
        }
        tally.messages = rows
        return Aggregate(tally: tally, maxCreatedMs: newest, rowsRead: rows)
    }

    private static func hasSupportedTokenShape(_ tokens: [String: Any]) -> Bool {
        for key in ["total", "input", "output", "reasoning"] {
            if let value = tokens[key], !(value is NSNull), !(value is NSNumber) { return false }
        }
        if let rawCache = tokens["cache"], !(rawCache is NSNull) {
            guard let cache = rawCache as? [String: Any] else { return false }
            for key in ["read", "write"] {
                if let value = cache[key], !(value is NSNull), !(value is NSNumber) { return false }
            }
        }
        return true
    }

    // MARK: - History

    private func applyBaseline(_ aggregate: Aggregate, day: Day, at date: Date) {
        var tally = aggregate.tally
        tally.messages = aggregate.rowsRead
        let cursor = aggregate.maxCreatedMs ?? (day.startMs - 1)
        history = History(
            dayStartMs: day.startMs,
            cursorMs: cursor,
            tally: tally,
            lastReconciliation: date
        )
        lastTally = tally
        usageAvailable = true
    }

    private func applyDelta(_ aggregate: Aggregate) {
        guard var history else { return }
        history.tally.today += aggregate.tally.today
        history.tally.output += aggregate.tally.output
        history.tally.messages += aggregate.tally.messages
        for hour in 0..<24 { history.tally.hourly[hour] += aggregate.tally.hourly[hour] }
        if let newest = aggregate.maxCreatedMs { history.cursorMs = max(history.cursorMs, newest) }
        self.history = history
        lastTally = history.tally
        usageAvailable = true
    }
}
