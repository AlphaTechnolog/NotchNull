# agent-usage-reads Specification

## Purpose

Keeps local agent-usage reads cheap and predictable: unchanged data is skipped, expensive history is demand-driven, totals stay incremental, and freshness degrades gracefully when a source is unavailable.

## Requirements

### Requirement: Unchanged data is not reread

A monitor SHALL detect that its data source has not changed since the previous poll. When no change is detected, the poll MUST NOT read message bodies or recompute aggregates.

#### Scenario: Unchanged database

- **WHEN** a poll follows another poll and no connection has committed a write in between
- **THEN** no rows are parsed and the previous totals are reused

#### Scenario: A write is detected

- **WHEN** another process commits a change between polls
- **THEN** the next poll observes the change and refreshes the affected state

### Requirement: Expensive aggregation is demand-driven

A monitor SHALL run full-day token aggregation only when the Agents tab becomes visible, and for reconciliation while it remains visible. It MUST NOT run that aggregation while the tab is not visible, and session state MUST NOT wait for it.

#### Scenario: The Agents tab opens

- **WHEN** the Agents tab becomes visible
- **THEN** one full-day aggregation establishes the current totals

#### Scenario: The Agents tab remains visible

- **WHEN** the Agents tab stays visible
- **THEN** reconciliation runs on its bounded interval, not on every poll

#### Scenario: The Agents tab is closed

- **WHEN** the notch is closed or another tab is showing
- **THEN** no message aggregation runs; session state keeps updating independently

### Requirement: Token totals consume new messages only

While the Agents tab is visible, after the first scan of a day, a monitor SHALL compute token totals from messages created since the previous scan and MUST NOT reparse older messages.

#### Scenario: First scan of the day

- **WHEN** the Agents tab becomes visible on a new day
- **THEN** the monitor scans the current day's messages once to establish a baseline

#### Scenario: New messages arrive

- **WHEN** messages are added after the baseline while the Agents tab is visible
- **THEN** only those new messages contribute to the next totals

#### Scenario: No new messages

- **WHEN** the source changes but no new message rows exist
- **THEN** the existing totals are kept without parsing message bodies

### Requirement: Daily totals cover the current local day

A monitor SHALL report token totals for messages created in the current local day. Cumulative session totals MUST NOT be used as the day's total.

#### Scenario: Session spans midnight

- **WHEN** a session created yesterday continues into today
- **THEN** today's total counts only messages created today, not the session's lifetime total

#### Scenario: Older session touched today

- **WHEN** a session created on an earlier day is updated today
- **THEN** its lifetime tokens do not inflate today's total

### Requirement: Incremental state resets with the day or the source

A monitor SHALL discard its incremental cache at the start of a new local day or when its data source is replaced, then rebuild from the current day.

#### Scenario: Midnight rollover

- **WHEN** the local date changes
- **THEN** the monitor starts a new baseline and hourly buckets begin at zero

#### Scenario: Database replaced

- **WHEN** the database file is recreated or its identity changes
- **THEN** the monitor drops cached totals and rescans the replacement

### Requirement: Session transitions stay timely

A monitor SHALL reflect running, idle, and needs-you transitions from its local data within two seconds of the data becoming available.

#### Scenario: A turn finishes

- **WHEN** the data source records that a session went idle or succeeded
- **THEN** the session's displayed status changes within two seconds

#### Scenario: Plugin event arrives

- **WHEN** the agent plugin reports a prompt, permission, or completion
- **THEN** the session state changes immediately without waiting for the next database poll

### Requirement: Token totals stay bounded while visible

While the Agents tab is visible, a monitor SHALL keep its token totals no more than sixty seconds stale and MUST reconcile updated or removed rows at least once per interval.

#### Scenario: Visible totals

- **WHEN** the Agents tab has been open for more than sixty seconds
- **THEN** the displayed totals have been reconciled within the last sixty seconds

#### Scenario: Corrected history

- **WHEN** a previously counted message is edited or removed
- **THEN** the next reconciliation corrects the total instead of leaving it inflated

### Requirement: Activation and events refresh immediately

When the app activates or an agent plugin event arrives, a monitor SHALL refresh its session state immediately instead of waiting for the next scheduled poll.

#### Scenario: App activates

- **WHEN** the app becomes active after being in the background
- **THEN** session state is checked immediately

#### Scenario: Plugin event arrives

- **WHEN** the agent plugin reports a prompt, permission, or completion
- **THEN** the session state changes without waiting for the next database poll

### Requirement: Read failures degrade gracefully

When the data source is missing, locked, or a payload cannot be parsed, the monitor SHALL keep the last known totals, report usage as unavailable, and MUST NOT block the UI or terminate.

#### Scenario: Database unavailable

- **WHEN** the database cannot be opened or is locked by a writer
- **THEN** usage is reported unavailable and the next poll retries

#### Scenario: Unexpected payload

- **WHEN** a message payload no longer matches the expected token shape
- **THEN** the last known totals are kept and the failure is surfaced as unavailable rather than a wrong value
