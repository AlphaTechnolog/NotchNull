# Tasks

## 1. Read path foundation

- [x] 1.1 Keep one read-only SQLite connection on the monitor queue, compare `PRAGMA data_version` and a database/`-wal` stat fingerprint before each read, and add internal scan diagnostics (cache hit, reconciliation ran, message rows read). Verify with a new `OpencodeReadTests` case: an unchanged temporary database reuses the cache with zero rows read, and a writer commit invalidates it.
- [x] 1.2 Add the JSON1 probe and a SQL aggregate that returns total, output, message count, and 24 hourly buckets without transferring the `data` column. Verify the aggregate matches `OpencodeMonitor.messageTokens` on the existing fixture for totals, component-only payloads, and nested cache values.
- [x] 1.3 Keep the existing Swift token parser as the fallback when JSON1 or a payload shape is unsupported, and report unavailable instead of a wrong value. Verify with fixtures for a malformed payload, a missing database, and a locked database; the last totals survive and the next poll retries.

## 2. Visibility and session state

- [x] 2.1 Add `setUsageVisible(_:consumer:)` with an idempotent consumer set, a baseline trigger on the zero-to-one transition, and a debug-visible consumer count. Verify duplicate `true`/`false` calls, two consumers, and the last removal with `OpencodeReadTests`.
- [x] 2.2 Register the consumer from `AgentsTab` while it is on screen and release it on disappear. Verify by opening and closing the Agents tab in the running app and observing the monitor's consumer count and a baseline scan; a second window must not double-release.
- [x] 2.3 Keep the two-second session-state poll independent of token work, gated by the change detector. Verify with a temporary database that a status change written from another connection appears within two seconds, and that no message rows are read while the Agents tab is closed.

## 3. Daily totals and history

- [x] 3.1 Add the day state (local day, cursor, total, output, hourly, message count), a baseline full aggregate, and a delta query for `time_created > cursor`. Verify with a fixture that only the new message contributes after the baseline and that the cursor advances.
- [x] 3.2 Make the day's headline total the sum of today's messages, not the cumulative `session_v2` columns, and keep output and hourly buckets from the same aggregate. Verify with a session that has yesterday and today messages: only today's tokens count, including the previously overcounted case (363.99M vs 333.94M on the reference database).
- [x] 3.3 Reconcile with a full aggregate on tab open and at most once per 60 seconds while visible, resetting the cursor from the result. Verify that an edited or deleted message is corrected on the next reconciliation and that a same-millisecond insert is picked up.
- [x] 3.4 Reset the history state at local midnight and when the database file is replaced. Verify both with an injected date and a recreated fixture database: totals and hourly buckets restart from the current day.
- [x] 3.5 Keep the last known totals and report usage unavailable when the message table or token shape is unreadable. Verify the unavailable state and that a later successful scan recovers without restarting the monitor.

## 4. Wiring and UI

- [x] 4.1 Call `refreshNow()` from the `/opencode` hook path in `AgentHub` and from app activation, debounced to one scan per run-loop turn. Verify a hook event and an activation each trigger a scan without waiting for the two-second timer.
- [x] 4.2 Remove the cumulative session-total query from the headline path and publish the new per-day `TokenTally`. Verify `OpencodeTests` and the Agents-tab token display read the corrected values, and that unchanged totals do not republish.
- [x] 4.3 Update the fixture and snapshot seeds if the corrected day total changes a rendered Agents image. Verify the existing snapshot suite still renders and the Agents tab shows the expected value.

## 5. Measurement and release note

- [x] 5.1 Build with `scripts/build-app.sh`, run a real or synthetic opencode session, and record `top` CPU plus a `sample` with the notch closed and with the Agents tab open. Verify the settled app stays below 5% of one core with the tab closed, the `dev.notchnull.opencode` queue no longer dominates, and session transitions still appear within two seconds.
- [x] 5.2 Add the next release note (`docs/releases/1.5.4.md` if 1.5.4 is next) describing the read path, the measured before/after, and the corrected per-day total. Verify the numbers match 5.1 and the note follows the existing release-note format.
- [x] 5.3 Run the full `swift test` suite and `openspec validate "reduce-opencode-monitor-cpu" --strict`. Verify both pass; the only allowed skip is the existing network-only live-update test.

## Workflow follow-up

- Close `reduce-notch-activity-cpu` tasks 6.1/6.2 with the split acceptance agreed in exploration, then archive it.
- Archive this change after review.
- Re-measure a real two-display setup after release if the hardware is available.
