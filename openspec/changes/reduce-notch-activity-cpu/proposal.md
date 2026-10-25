# Proposal

## Why

While a live agent activity was shown in the collapsed notch, a 1.5.0 build sustained 37–56% of one CPU core for minutes at a time. A 5-second `sample` put roughly half of the main thread inside the CoreAnimation display-link flush: SwiftUI was re-rendering the notch's display list every frame, including glyph rasterization and the emission-edge blur, because the elapsed-time label's rolling numeric transition and spring never finished before the next 1-second tick. 1.5.2 already recorded ~23% CPU with a collapsed agent activity and explicitly left SwiftUI/CoreAnimation work under investigation. Agent sessions are long, the notch is usually visible while they run, and the cost doubles on a two-display setup, so every agent turn pays this price today.

## What Changes

- Replace the animated elapsed and countdown labels in live notch activities with plain, fixed-width monospaced text driven by one shared one-second clock. No `contentTransition(.numericText(...))` plus spring on a value that changes once a second, so no interpolator survives until the next tick.
- Keep the notch body's size and position stable when a label changes width (`9s` → `10s`, `59s` → `1m 0s`, `59m` → `1h 0m`): reserve a fixed time slot instead of re-measuring and animating the wings on every digit-count change.
- Separate static chrome from ticking content so a label change does not re-rasterize the body fill, emission edge blur or shadow.
- Do no animation work for notch windows that are not actually on screen: hidden panels, fullscreen-hidden displays, sleeping displays and inactive Spaces. Each visible window may redraw at most once per label tick, not per display refresh.
- Preserve existing visible behavior: music bars, needs-you glow and media scrubbers keep their animation cadence while genuinely visible; only the idle/settled label work changes.
- Out of scope: agent monitor polling and transcript/JSON scanning, panel information architecture, and a visual redesign of the notch.

## Capabilities

### New Capabilities

- `notch-render-budget`: How much rendering work the notch may do while idle — when notifications may keep a display link alive, how often time-driven text updates, how label changes affect body geometry, and when hidden or duplicate windows must stop animating.

### Modified Capabilities

<!-- No existing specs in this project yet. -->

## Impact

- **Activities/UI:** `AgentActivities` (elapsed label), `SystemActivities` (`TimerActivity` countdown), `HomeTab` timer and any other notch-window time label; `NotchRootView` layering of body chrome versus content; `IslandViews` and `Light` visibility gating.
- **State/layout:** `NotchViewModel` owns the shared ticker, the fixed time slot and wing-measurement policy; `NotchWindowController` reports real visibility/occlusion to the model.
- **Multi-display:** `NotchCoordinator` continues to create one window per display, but hidden windows no longer animate and visible windows do one redraw per tick.
- **No settings or stored-data changes:** existing preferences, saved panel sizes and agent integrations keep working; no new settings keys.
- **Tests/snapshots:** new coverage for label cadence, stable geometry across digit-count changes, and paused timelines on hidden windows; snapshot renders should remain pixel-comparable for settled states.
- **Docs:** a release note describing the measured improvement; no README or settings reference changes expected.
