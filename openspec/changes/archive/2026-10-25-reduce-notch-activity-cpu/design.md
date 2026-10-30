# Design

## Context

See `proposal.md` for the measurements and motivation; `specs/notch-render-budget/spec.md` for the required behavior.

Current state that shapes the approach:

- 1.5.2 added `NotchViewModel.isWindowVisible`, driven by `NotchWindowController.refreshSampling()` from panel occlusion, fullscreen hiding, app hiding and teardown. Hidden media timelines and pulse dots already use it.
- Time labels in the notch still use `TimelineView(.periodic(...))` plus `contentTransition(.numericText(...))` and `animation(Motion.value, ...)`: the agent elapsed label in `AgentActivities`, the timer countdown in `SystemActivities`, and the Home timer row.
- `WingsLayout` measures each wing's natural width through a preference and reports it to `NotchViewModel.reportWingContent`, which animates `measuredWings` by more than one point. A label that changes digit count therefore re-measures and animates the whole body.
- `NotchBodyView` draws the body fill, content, emission edge (a 9-point blur with a gradient mask) and chasing outline in one SwiftUI display list, so a content change invalidates the chrome too.
- `NotchCoordinator` creates one `NotchWindowController`, `NotchViewModel` and hosting view per display. Both windows render the same shared activity.
- `SystemStatsService.setActive(_:consumer:)` already demonstrates the per-window consumer-count pattern for pausing shared work.
- `SnapshotRenderer` sets `Motion.isSnapshot` and renders views with `ImageRenderer`; fixtures currently seed times from `Date()`.

## Goals / Non-Goals

**Goals:**

- A one-second time label costs one label redraw, not a display-link render loop.
- Label changes cannot resize or move the notch body.
- Static chrome is not re-rasterized for label changes.
- No notch animation work while the window is not actually visible.
- One tick per visible window per second when several displays show the same activity.

**Non-Goals:**

- Agent monitor polling, transcript parsing or JSON scanning (separate concern).
- Changing the notch's visual design, fonts, or activity layout beyond the reserved time slot.
- Changing panel sizing, tab contents, or settings.
- Memory-footprint work.

## Decisions

### 1. A shared, pausable one-second clock, injected only where time is shown

Add `NotchClock`, a `@MainActor ObservableObject` owned by `AppServices`, with `@Published private(set) var now: Date`. One main-run-loop timer fires on whole-second boundaries; no per-view `TimelineView` for clock text.

- `setActive(_:consumer:)` mirrors `SystemStatsService`: a window inserts/removes its consumer id from `refreshSampling()` and `tearDown()`. The timer runs only while at least one window is visible, and the first activation schedules the first tick at the next whole second.
- The clock is injected through the existing `.withServices(services)` environment. Only `TimeText` and the timer ring observe it, so a tick invalidates those subviews, not `NotchRootView` or `NotchViewModel`.
- On resume the label formats from `now`, so it shows the current value rather than replaying missed ticks.

Alternatives considered:

- Keep `TimelineView(.periodic)` and only remove the animated modifiers. Simpler, but leaves one timer per window running while hidden and makes cross-display ticks independent. Rejected because it cannot satisfy the hidden-window requirement without extra conditional views, and the shared clock also makes tests deterministic.
- Put `now` on `NotchViewModel`. Rejected: `NotchWindowController` observes `model.objectWillChange` and would re-run visibility sampling every second.

### 2. `TimeText`: plain monospaced text with a reserved slot

Add a small `TimeText(value:widest:)` view used by the agent elapsed label, the wing timer, and the Home timer row:

- Renders `value` in the existing rounded monospaced-digit font with no `contentTransition` and no `animation`.
- Lays out a hidden `widest` sample in a `ZStack(alignment: .trailing)` so the slot always has the widest expected width for that activity.
- Widest samples: `"59m 59s"` for agent elapsed (the hour form `"1h 5m"` is shorter) and `"99:59:59"` for timers.
- Because the frame is constant, `WingsLayout` reports a constant width while the activity is unchanged, so `reportWingContent` does not fire on ticks. Its animation stays for genuine content changes such as a new provider count.

Alternatives considered:

- `.frame(width: <constant>)`: needs per-font tuning and breaks with accessibility text sizes.
- Keep the natural width and drop only the animation: the body would still jump at digit boundaries, violating the stable-slot requirement.

### 3. Remove interpolated time transitions, keep discrete transitions

Delete `.contentTransition(.numericText(...))` and the per-tick `.animation(...)` from the three time labels. Activity enter/leave transitions, condensed content, music bars and the needs-you chase keep their current animations; they change for real reasons and are allowed per the spec. The timer ring steps once per second instead of animating progress between ticks; at a once-per-second cadence the step is not visible.

### 4. Cache static chrome as its own rasterized group

Wrap `EmissionEdge` and `BodyFill` in `.drawingGroup()` inside `NotchBodyView`. Their inputs (tint, radii, intensity, expanded) change only with the phase or shape, so SwiftUI can reuse the rasterized group while only the label changes. During body morphs they re-rasterize as they do today; the idle case is the one that matters.

If a post-change `sample` still shows `Layer::make_cgimage` or glyph work on label ticks, the fallback is a sibling `NSHostingView` for chrome behind the content hosting view. That is deliberately a follow-up, not the first step, because it complicates the shared shape animation.

### 5. Visibility gating covers display sleep and app hiding

Extend the existing `refreshSampling()` predicate with a `displayAsleep` flag and subscribe to `NSWorkspace.screensDidSleepNotification` / `screensDidWakeNotification` and `NSApplication.didHide` / `didUnhide` in `NotchWindowController`. Each change recomputes visibility, updates `model.isWindowVisible`, and calls `clock.setActive(visible, consumer:)`.

Also gate the remaining continuous animation on visibility: `ChasingOutline.active` gains `model.isWindowVisible`, and `AgentRunningActivity` passes `animating: model.isWindowVisible` to `ProviderStack` so a spinning mark stops in a hidden or sleeping window. `PulseDot` and `AudioBars` already read `isWindowVisible`.

### 6. One clock, one tick, several windows

All windows read the same `NotchClock.now`. Each visible window still draws its own label once at that tick, which the spec permits; there is no per-frame work to multiply. Hidden windows have no active clock consumer, so they do no work.

### 7. Deterministic snapshots

`NotchClock` does not start its timer when `Motion.isSnapshot` is set. `SnapshotRenderer` seeds a fixed reference date on the clock and computes fixture times (`turnStartedAt`, timer start) against it, so `TimeText` renders the same string on every snapshot run. Existing snapshot fixtures keep their look; only the elapsed label's second value becomes stable.

## Risks / Trade-offs

- **Visible polish loss**: removing rolling digits is a deliberate visual change. → Snapshot review and a release note; the reserved slot keeps the layout calm.
- **Wider timer slot**: reserving `99:59:59` widens the timer wing. → It only applies while the timer activity is shown; the wing measurement still fits the body.
- **`.drawingGroup()` changes blur sampling or color**: → Compare the affected snapshots pixel-wise before/after; keep the sibling-layer fallback if it regresses.
- **Clock resumption shows up to one stale second**: → Recompute from `now` on activation, never replay ticks.
- **Missed sleep/hide notifications**: → Recompute visibility from the same predicate on the existing 2.5-second fullscreen poll, which already reconciles windows.
- **Shared clock invalidates too much**: → Keep it off `NotchViewModel`; only `TimeText` and the timer ring observe it. A unit test asserts one publication per tick.
- **Two windows tick together**: → Accepted; the spec requires one redraw per visible window, not a single global draw.

## Migration Plan

1. Land the clock and `TimeText`, and switch the three labels; measure with `sample` on the same app state before and after.
2. Add chrome rasterization; re-measure.
3. Add sleep/hide gating; verify by hiding the app, entering fullscreen, and sleeping the display with the timer visible.
4. Regenerate snapshots and the release note.

No stored-data or settings migration. Rollback is reverting the change; time labels fall back to the previous animated behavior.

## Open Questions

- None blocking. Whether the chrome `.drawingGroup()` is sufficient is answered by measurement during implementation, with the sibling-layer fallback already specified.
