# Tasks

## 1. Shared one-second clock

- [x] 1.1 Add `NotchClock` (`Sources/NotchNull/Services/System/NotchClock.swift`) with a published `now`, a timer aligned to whole seconds, a consumer-count `setActive(_:consumer:)`, and a frozen preview date for snapshots. Verify with new `NotchClockTests`: one publication per tick, the timer stops at zero consumers, and the first activation ticks at the next second boundary.
- [x] 1.2 Own the clock in `AppServices` and inject it from `withServices` so every window shares it. Verify `swift build` succeeds and the existing `AppServices`-based tests still construct without starting services.
- [x] 1.3 Activate and release the clock from `NotchWindowController.refreshSampling()` and `tearDown()` with a per-window consumer id. Verify `NotchWindowRecoveryTests` asserts the clock pauses for an ordered-out or fullscreen-hidden panel and resumes when it is restored.

## 2. Unanimated, fixed-slot time labels

- [x] 2.1 Add `TimeText(value:widest:)` (`UI/Components/TimeText.swift`) using the existing monospaced-digit wing font, a hidden widest sample for layout, and no content transition or animation. Verify with new `TimeTextTests`: `9s`, `10s`, `59s`, and `1m 0s` render at the same size through `ImageRenderer`, and the hour form is shorter than `59m 59s`.
- [x] 2.2 Switch `AgentRunningActivity`'s elapsed label to `NotchClock` plus `TimeText(widest: "59m 59s")`, and remove `.contentTransition(.numericText(...))` and `.animation(...)`. Verify the tests pass and two consecutive renders of the `72-agents-both-running` snapshot are byte-identical.
- [x] 2.3 Switch the wing `TimerActivity` to the same clock and `TimeText(widest: "99:59:59")`, and make `RingGauge` advance one step per second instead of animating between ticks. Verify the timer tests pass and two consecutive renders of the `93-island-timer` snapshot are byte-identical.
- [x] 2.4 Switch the Home timer row in `HomeTab` to the same clock and time slot, removing its numeric transition. Verify the timer tests pass and the Home timer snapshot renders the same text on repeated runs.

## 3. Static chrome caching

- [x] 3.1 Wrap `BodyFill` and `EmissionEdge` in `.drawingGroup()` inside `NotchBodyView`. Verify the notch snapshots (90-95 and the activity states) still match apart from the intended label text, and that the blur and edge keep their existing appearance.
- [x] 3.2 Profile a settled agent activity with `sample`: verify label ticks no longer show `Layer::make_cgimage`, `vSepConvolveARGB8bgf_vec`, or `CGGlyphBitmapCreateWithPathAndDilation_8` samples. If they remain, implement the sibling chrome hosting view from the design and re-check.

## 4. Visibility and display-sleep gating

- [x] 4.1 Add a `displayAsleep` flag plus `NSWorkspace.screensDidSleepNotification` / `screensDidWakeNotification` and `NSApplication.didHide` / `didUnhide` subscriptions to `NotchWindowController`, include them in `refreshSampling()`, and forward the result to the clock. Verify a controller test posts each notification and asserts `model.isWindowVisible` and the clock consumer state change.
- [x] 4.2 Gate `ChasingOutline.active` and the agent activity's `ProviderStack(animating:)` on `model.isWindowVisible` so no chase or mark timeline runs in a hidden window. Verify with predicate unit tests and a `sample` while the panel is ordered out: no chase/mark timeline work appears.
- [x] 4.3 Extend `NotchWindowRecoveryTests` to cover the fullscreen-hidden, ordered-out, and display-asleep paths, asserting the clock has no active consumer and that restoring visibility resumes it.

## 5. Multi-display and deterministic snapshots

- [x] 5.1 Freeze `NotchClock` when `Motion.isSnapshot` is set and seed snapshot fixture times (`turnStartedAt`, timer start) against the frozen date in `SnapshotRenderer`. Verify two consecutive `notchnull render` runs produce identical PNGs for `72-agents-both-running`, `93-island-timer`, and the Home timer snapshot.
- [x] 5.2 Add a two-window test (two `NotchWindowController`s over the same services) asserting both windows read the same clock tick, both hold one consumer while visible, hiding one leaves one consumer, and the hidden window performs no clock work. Verify with `NotchClockTests` plus a controller test.
- [x] 5.3 With two displays attached, run a live agent activity and `sample` both windows: verify each visible window redraws once per second with no display-link loop between ticks.

## 6. Measurement and release note

- [ ] 6.1 Build with `scripts/build-app.sh`, run an agent activity plus a timer, and record `top` CPU and a `sample` before and after on the same machine state. Verify the settled notch now sits below 5% CPU with only a time label changing, and that the main-thread display-link share is effectively gone.
- [ ] 6.2 Add the next release note (`docs/releases/1.5.4.md` if 1.5.4 is next) in the existing format, describing the change plus the measured before/after from 6.1. Verify the numbers match the measurements and the note matches the surrounding release notes.
- [x] 6.3 Run the full `swift test` suite and `openspec validate "reduce-notch-activity-cpu" --strict`. Verify both pass with no skipped render tests.

## Workflow follow-up

- Archive the change after review.
- Re-measure a real two-display setup after release if the user's hardware is available.
