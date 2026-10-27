# Design

## Context

See `proposal.md` for the measurements and motivation; `specs/agent-usage-reads/spec.md` for the required behavior.

Current state that shapes the approach:

- `OpencodeMonitor` owns a 2-second timer on `dev.notchnull.opencode`. Every poll runs `readSessions` (60 rows, 12 kept) and `readTodayTally`.
- `readTodayTally` sums cumulative token columns from `session_v2` rows updated today, then transfers up to 2,000 `session_message.data` values into Swift, converts each to a `String`, re-encodes it to `Data`, and parses the whole payload with `JSONSerialization` to find `tokens`.
- The real database today has 1,476 assistant messages and 14.3 MB of JSON; the largest message is 873 KB. The cumulative session totals are 363.99M tokens versus 333.94M for today's messages, so the current "today" number overcounts when a session spans midnight.
- `session_message` has an index on `time_created`; SQLite 3.54 with JSON1 is available. The same hourly aggregate runs in ~80 ms in SQL. The `session_v2` today query runs in ~10 ms.
- The hourly chart and the day's token total are shown only in `AgentsTab`. The closed notch and the other tabs show neither.
- Running/permission/finished transitions already arrive immediately through the opencode plugin (`/opencode`), with the DB poll as a backstop. `apply` already skips no-op upserts.
- `SystemStatsService.setActive(_:consumer:)` is the established per-window consumer-count pattern.
- `OpencodeTests` already builds a temporary SQLite fixture with `session_v2`, `session_message`, and the v1 table.

## Goals / Non-Goals

**Goals:**

- Make a poll's work proportional to what changed since the previous poll, not to the size of the day's history.
- Never read messages while the Agents tab is not visible.
- Report an accurate per-day token total, and reconcile edits/deletions within the visible freshness bound.
- Keep session transitions timely while keeping the closed notch cheap.

**Non-Goals:**

- Plugin-pushed token deltas, schema changes to opencode's database, or writing to it.
- Redesigning the Claude or Codex monitors in this change.
- Any notch, settings, or chart visual redesign.
- Revisiting the notch render budget (separate change).

## Decisions

### 1. Three read tiers: state, incremental total, reconciliation

- **Session state** (every poll): the existing `session_v2` status query. It is cheap and independent of token history.
- **Incremental total** (only while the Agents tab is visible): read messages newer than a cursor and add their tokens to the day's total, output, hourly buckets, and message count.
- **Full reconciliation** (on the first visibility of a day, and at most once per 60 seconds while visible): one SQL aggregate over the current day's messages. It corrects edits, deletions, and same-millisecond ties.

The closed notch and the other tabs perform no message reads at all. The Agents tab registers a visibility consumer while it is on screen.

Alternatives considered:

- Keep the `session_v2` headline and only gate the hourly scan. Rejected: the cumulative total is wrong across midnight (measured 30M overcount).
- Run the full aggregate every 2 seconds. Rejected: 80 ms per poll, and it hides the correctness bug rather than fixing the read path.
- Parse only new rows in Swift. Rejected as the primary path: SQL can return the token fields without transferring the payload; the Swift parser stays as a fallback.

### 2. Visibility consumers, not polling heuristics

Add `setUsageVisible(_:consumer:)` to the monitor, mirroring `SystemStatsService`: a `Set<UUID>` of consumers, baseline on the zero-to-one transition, and reconciliation while at least one remains.

- `AgentsTab` registers a consumer while it is on screen.
- Multiple windows are handled by the count; closing one does not stop the other.
- Snapshots do not start the monitor, so `onAppear` consumers have no timer to drive.

Alternative considered: derive visibility from each `NotchViewModel`'s `visibleTab` and forward it through `AgentHub`. Rejected as more cross-window plumbing for the same result; the view-level consumer is local and already proven by the stats service.

### 3. One read-only connection plus change detection

Keep one read-only connection (`SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX`, `busy_timeout = 0`) on the monitor queue instead of opening and closing per poll.

- Before reading, compare `PRAGMA data_version` and a `stat` fingerprint of the database and `-wal` file. If both match the previous poll, return the cached snapshot without querying.
- Reopen the connection when the inode changes or SQLite reports `SQLITE_SCHEMA`/`SQLITE_NOTADB`.
- Do not hold a long-lived read transaction; a parked reader can pin the WAL.

Alternatives considered: opening per poll (current behavior, no change detection); an FSEvents watcher on the WAL (more moving parts, and plugin events already cover the immediate path). The fingerprint is the pragmatic middle.

### 4. SQL aggregation instead of payload transfer

One aggregate returns 24 hourly rows plus total, output, and count:

```sql
SELECT strftime('%H', time_created / 1000, 'unixepoch', 'localtime') AS hour,
       sum(COALESCE(json_extract(data, '$.tokens.total'),
                    json_extract(data, '$.tokens.input') +
                    json_extract(data, '$.tokens.output') +
                    json_extract(data, '$.tokens.reasoning') +
                    COALESCE(json_extract(data, '$.tokens.cache.read'), 0) +
                    COALESCE(json_extract(data, '$.tokens.cache.write'), 0))),
       sum(COALESCE(json_extract(data, '$.tokens.output'), 0)),
       count(*)
FROM session_message
WHERE type = 'assistant' AND time_created >= ?
GROUP BY hour
```

- The delta query reuses the same expression for `time_created > ?`, so no `data` column crosses into Swift.
- Probe JSON1 once on open (`json_extract('{"a":1}', '$.a')`). If unavailable, fall back to the existing `messageTokens` parser at the reconciliation cadence only, never on every poll.
- Hourly values are displayed from the aggregate; the day's total is the sum of the buckets, not the cumulative session columns.
- If the message table is unavailable, keep the last known total and report usage unavailable. Do not substitute the cumulative session total, which would reintroduce the overcount.

### 5. Accurate per-day totals and reconciliation

`HistoryState` holds the local day, the last message timestamp, the day's total/output/hourly, and the count.

- Baseline: full aggregate for the day; set the cursor to the latest message timestamp.
- Delta: `time_created > cursor`; add the returned sums and advance the cursor.
- Reconciliation: full aggregate every 60 seconds while the Agents tab is visible, and whenever the tab becomes visible after being closed. This corrects edited or deleted rows and any same-millisecond tie missed by the cursor.
- Reset on local-day change, database replacement, or an explicit schema/parse failure that requires a rebuild.

The 60-second bound matches the spec's visible freshness requirement; the headline does not depend on the expensive hourly refresh because deltas keep it current between reconciliations.

### 6. Timers and immediate refresh

- Session state keeps the existing 2-second timer; it is cheap and preserves the two-second transition guarantee.
- Message work is driven only by the Agents-tab visibility state, so there is no separate token timer to back off.
- The plugin handler calls `refreshNow()` after `/opencode` events; app activation calls it too. `refreshNow()` debounces to one scan per run-loop turn and invalidates the timer's next fire.
- This deliberately keeps the cheap state poll instead of adding a slow cadence that would weaken the two-second guarantee.

Alternative considered: back off the whole timer when idle. Rejected because the expensive part is message parsing, which is already visibility-gated; slowing the 10 ms state query would only delay session transitions.

### 7. Diagnostics and tests

`Snapshot` gains internal, non-published counters: whether the cache was reused, whether a reconciliation ran, and how many message rows were read. They make the tests assert the read path, not just the totals.

Tests will cover:

- unchanged `data_version` → cache reused, zero rows read; a writer commit → refresh;
- baseline then one new message → exactly one row contributes;
- aggregate correctness for `tokens.total`, components, and cache; a session spanning midnight counts only today;
- midnight and database-replacement resets;
- no consumer → no message reads; first visibility → baseline; 60-second reconciliation;
- app activation/plugin event → immediate refresh;
- missing/locked database and malformed payload → last known totals, unavailable state;
- the two-second session transition path.

## Risks / Trade-offs

- **`data_version` and WAL**: `data_version` may not change for every WAL frame. → Compare the WAL `stat` fingerprint too, and reconcile on the visible cadence.
- **JSON1 unavailable**: unlikely on macOS 14+, but possible. → Probe once and fall back to the existing Swift parser at the reconciliation cadence.
- **Schema drift in opencode**: a future release can rename tables or token fields. → Detect prepare/extract failure, keep the last totals, report unavailable, and retry on the next poll.
- **Edits and same-millisecond inserts**: the incremental cursor can miss a corrected row or a same-time message. → The 60-second full reconciliation corrects both; the spec's freshness bound is 60 seconds.
- **Visibility callbacks**: `onAppear`/`onDisappear` can fire around retained transitions. → Use an idempotent consumer set and test duplicate appearance/removal.
- **A full aggregate takes ~80 ms on a 14 MB day**: acceptable on open and once per minute while visible, but avoid it in the closed notch.
- **The day's total changes after this fix** (lower for sessions spanning midnight): expected and correct; call it out in the release note.

## Migration Plan

1. Land the visibility consumer and the SQL baseline/reconciliation, keeping the old parser as a fallback.
2. Switch the day total and hourly chart to the new state; remove the session-total headline.
3. Add change detection and the incremental cursor.
4. Wire plugin events and app activation to immediate refresh.
5. Measure with the notch closed and with the Agents tab open; record `top` and `sample`.
6. Add the release note. No stored data or settings migration; rollback is reverting the change.

## Open Questions

- None blocking. The 60-second reconciliation interval and the 5-second visible delta cadence are tuning values; they can change without altering the spec or approach.
