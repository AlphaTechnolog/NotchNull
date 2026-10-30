# Proposal

## Why

NotchNull's opencode monitor reparses the day's assistant messages on every two-second poll. On this Mac that is 1,451 messages and 14.3 MB of JSON per poll (largest single message 873 KB), even when nothing changed. After the notch render fix, this is the app's largest remaining CPU cost: ~10% of one core on average, with 20–33% spikes. The session table gives cheap session state, but its token totals are cumulative for a session, so they overstate today by about 30 million tokens on this Mac (363.99M versus 333.94M for today's messages). The hourly chart is only visible in the Agents tab, and SQLite can aggregate today's messages in about 80 ms.

## What Changes

- Skip message parsing entirely when the database has not changed since the previous poll.
- Run token aggregation only while the Agents tab is visible; session state keeps its cadence, and the closed notch performs no token reads.
- Replace the 2,000-row Swift/`JSONSerialization` scan with one SQL aggregate over `json_extract` and `GROUP BY`, and parse only messages newer than the last scan.
- Report the day's total from messages created today. Cumulative session totals, which overstate a day when a session spans midnight, are no longer the headline.
- Keep a read-only connection and prepared statements instead of reopening the database every poll; reset caches at midnight or when the database is replaced.
- Refresh immediately on opencode plugin events or app activation instead of waiting for the next scheduled poll.
- Define freshness explicitly: session transitions within two seconds; token totals within sixty seconds while the Agents tab is visible.
- Degrade gracefully when the database is missing, locked, or its schema/JSON shape changes; keep the last known totals and mark usage unavailable.
- Out of scope: plugin-pushed token deltas, schema changes to opencode's database, Claude/Codex monitor redesign, and any notch or settings UI redesign.

## Capabilities

### New Capabilities

- `agent-usage-reads`: How local agent-usage monitors read their data sources — change detection, demand-driven aggregation, incremental totals, freshness, immediate refresh, and graceful degradation.

### Modified Capabilities

<!-- No existing specs in this project yet. -->

## Impact

- **Services:** `OpencodeMonitor` scan, tally, and polling; `AgentHub` wires plugin events and usage-UI visibility; a small per-window visibility consumer modelled on `SystemStatsService`.
- **UI:** `AgentsTab` reports when it is visible. No visual change; it reads the corrected per-day total.
- **Data:** read-only SQLite access. No writes to opencode's database and no schema changes.
- **Correctness:** the Agents tab token total becomes a per-day total instead of the cumulative total of sessions touched today; a session that spans midnight no longer inflates the new day.
- **Tests:** fixture database with large payloads; unchanged-database skip, incremental delta, aggregate correctness, Agents-tab visibility gating, midnight/replacement reset, malformed-payload fallback, and a two-second session-freshness check.
- **Acceptance:** app-wide CPU below 5% of one core in the settled state (notch closed, no active turn), closing the app-wide number that `reduce-notch-activity-cpu` intentionally left to this change.
- **Docs:** a release note with the measured before/after and the read path described.
