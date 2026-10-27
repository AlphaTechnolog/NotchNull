# Design

## Context

See `proposal.md` for motivation and the two delta specs for required behavior. Current constraints in the code:

- `AgentProvider` is a three-case enum (`.claude`, `.codex`, `.opencode`). `AgentHub` owns the monitors, hook/plugin install state, and is injected into every view through `AppServices`.
- Preferences are independent booleans (`claudeUsageEnabled`, `codexEnabled`, `opencodeEnabled`, `agentsEnabled`) registered to `true` by default. Nothing currently detects whether the binaries or data those toggles refer to exist.
- The notch Agents tab uses two `Card`s in an `HStack`. `Card` fills the available height; each column previously centered its content with matched top/bottom `Spacer(minLength: 0)`.
- `NotchScroll` already uses `ViewThatFits`: content that fits gets a top-leading full-size frame, overflowing content becomes a real scroll view. We can rely on it for top alignment.
- The panel window reserves a fixed `1320×720` canvas. Only `NotchViewModel.bodySize` changes the visible body, so a height request animates inside the existing window without an AppKit resize or window-controller change.
- `panelContentHeight` is currently a fixed user preference. The Agents tab adds a static 16pt; the selected tab's height is not content-driven.
- `SnapshotRenderer` seeds fixture services for deterministic PNGs, but agent availability would otherwise read the developer's real home directory.

## Goals / Non-Goals

**Goals:**

- One installability model shared by every agent-facing surface.
- Detection that works when the app is launched from Finder, where `PATH` is minimal.
- Persisted preferences untouched when an agent is absent.
- The Agents tab stays present and useful even with zero installed agents.
- A deterministic layout: intrinsic heights, top alignment, no fixed blank area below short content.
- The Agents tab fits the open panel to its taller column, capped by the configured height.
- Testable detection and snapshot fixtures independent of the host machine.

**Non-Goals:**

- Starting, stopping, or reconfiguring the agent monitors based on availability. Services keep their existing lifecycle.
- Automatically hiding or reordering the Agents tab. Users already control that in Settings → Tabs & Wings.
- Reading credentials, keychain items, or agent account state during detection.
- Adding new settings keys or changing `settings.json`.
- Redesigning the Home tab or other tabs' row stretching.
- Fitting every tab to its content. Only Agents opts in during this change; Home and other tabs keep their configured height.
- Resizing the AppKit panel window. The fixed canvas already accommodates a shorter body.

## Decisions

### 1. Detection model: executable plus watchable data

A new pure `AgentInstallation` helper answers "is this agent installed?" from two signals:

| Agent | Executables searched | Watchable data that also counts |
|---|---|---|
| Claude Code | `claude` | `~/.claude/projects/` |
| Codex | `codex` | `~/.codex/sessions/`, `~/.codex/config.toml`, `~/.codex/auth.json` |
| opencode | `opencode` | `~/.local/share/opencode/opencode.db` |

Executable search order:

1. `PATH` entries from `ProcessInfo.processInfo.environment`.
2. Common user prefixes: `~/.local/bin`, `~/.claude/local`, `~/.opencode/bin`, `~/.bun/bin`, `~/.npm-global/bin`, `~/.volta/bin`, `~/Library/pnpm`, `~/.local/share/pnpm`, `~/.asdf/shims`, `~/.local/share/mise/shims`.
3. Node version-manager bin folders: `~/.local/share/fnm/node-versions/*/installation/bin`, `~/.nvm/versions/node/*/bin`.
4. System prefixes: `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`.

Deliberately excluded: `~/.claude/settings.json` and `~/.codex/hooks.json` on their own, because NotchNull can create them.

Why not shell out to `command -v` or a login shell? A menu-bar app launched from Finder gets a minimal environment; a login shell would source user startup files, can be slow, and can have side effects. File checks against known locations plus the data markers cover normal installs without executing anything.

Why not count any config directory? Those directories survive uninstall and are frequently written by NotchNull itself, which is exactly the false-positive case this change removes.

### 2. Availability lives in `AgentHub`

`AgentHub` gains `@Published private(set) var installed: Set<AgentProvider>` initialized from `AgentInstallation.live()`, plus `refreshInstalled()`. `AppServices` already injects `AgentHub` into the settings window, notch views, and `BuildSettings`, so no new environment plumbing is needed outside `HomeRowsSettings` and `PermissionList`, which also receive the same environment object.

Alternatives considered:

- A separate `AgentAvailability` environment object: cleaner separation, but requires adding another long-lived service to `AppServices` and every `withServices` call site.
- Computing `FileManager` checks inside each view body: no shared truth, repeated I/O, and snapshots become machine-dependent.
- Putting it in `Preferences`: mixes user choices with machine state and makes `Preferences` depend on the file system.

Refresh triggers:

- `AgentHub.start()`.
- `.onAppear` of `AgentsTab`, `AgentSettings`, and `BuildSettings`.
- `NSWorkspace.didActivateApplicationNotification`, throttled to at most once every two seconds. This catches "install in Terminal, return to the app" even when NotchNull is an accessory app that never becomes active itself.

No timer or continuous file watching. The checks are a small number of `fileExists` calls plus bounded directory listings.

### 3. Gate views, never mutate preferences

Every surface applies availability as an AND with the existing preference. Saved booleans are not rewritten. This means:

- An absent agent's block/group/row disappears.
- An installed agent still respects its watch toggle.
- Installing an agent later restores the user's previous preference without migration.

A small pure helper on `AgentProvider` (for example `visible(installed:enabled:)`) keeps the provider order and separator logic testable without rendering SwiftUI.

### 4. Keep the Agents tab; make the empty state do the explaining

`Preferences.isFeatureEnabled(.agents)` remains `agentsEnabled`; no availability check is added. The user can already hide any tab in Settings → Tabs & Wings through `hiddenTabs`, and that behavior stays untouched.

When the tab has no visible providers and no plans:

- Provider column: an empty state naming Claude Code, Codex and opencode and telling the user that installing any of them makes the block appear. Keep it short enough for the default panel height.
- Sessions column: an empty state that says no live sessions exist and explains that sessions appear after an installed agent runs.
- When some agents are installed but idle, the session copy names only those installed agents, built with `ListFormatter.localizedString(byJoining:)`.

### 5. Cleanup is separate from the hidden integrations

Hiding an absent agent must not strand NotchNull-owned configuration. Two cleanup surfaces:

- Settings → Agents: a `Cleanup` group rendered only when at least one of these is true:
  - `!installed.contains(.claude) && agents.hooksInstalled`
  - `!installed.contains(.opencode) && agents.opencodePluginInstalled`
  Each row explains the leftover and offers Disconnect.
- Settings → Build → Agent skill: a row is shown when the agent is installed **or** its skill link still exists. This lets a user remove a link for an absent agent without resurrecting the full integration.

Adding a `NotchHome.Agent` → `AgentProvider` mapping makes the Build filter explicit. `NotchHome.Agent` currently covers only Claude Code and Codex; opencode is out of scope for the skill list.

### 6. Layout: remove distribution, keep scroll behavior

`AgentsTab` becomes:

- A plain top-aligned `VStack` of visible provider blocks and plan blocks, with dividers computed from the visible sequence.
- No outer `VStack(spacing: 0)` and no top/bottom spacers.
- `NotchScroll` keeps its existing fitting/scrolling behavior, so content that fits stays top-aligned and taller content scrolls.

`SessionsCard` removes the spacers around its list and around its empty state. Session rows already have a fixed 32-point height; no new numeric height is introduced for them. Provider blocks are never given `maxHeight: .infinity` or an explicit height.

This deliberately reverses the "center the complete content group" choice from `c74214f`; the new requirement is blank space below, not balanced margins above and below. The fitted-height decision below then removes that remaining blank area by shrinking the body itself.

### 7. Snapshot and test determinism

`AgentHub.preview(...)` gains an `installed:` argument. `SnapshotRenderer.seed` sets all three providers for existing fixtures, so current snapshots do not change because of the host machine. A new fixture renders the Agents tab with one installed provider to exercise the new layout.

`AgentInstallation` accepts an injected home directory, executable directory list, and `FileManager`, so tests create temporary trees for positive and negative cases. A pure visibility helper is tested with 0, 1, 2 and 3 providers and with preferences on/off. Fitted-height snapshots use an explicit preview override (see decision 8) so `ImageRenderer` does not depend on a preference-change pass.

### 8. Fitted Agents panel height

Only the Agents tab opts into a content-fitted height. `panelHeight` remains the configured height for every other tab, and becomes the maximum for Agents.

Measurement:

- A `PreferenceKey` carries the natural height of intrinsic content; `GeometryReader` backgrounds are used because the deployment target is macOS 14 (no `onGeometryChange`).
- The provider/plan column reports its inner `VStack` height (the `NotchScroll` content, not the stretched card).
- The Sessions card reports the sum of its header, session-row `VStack`, empty state, and approval prompt. Measuring the outer card would report the stretched height and create a feedback loop.
- `AgentsTab` adds the `Card` padding (`2 * 8`) and the `ExpandedPanel` vertical padding (top 4, bottom `Theme.Radius.panelPadding`), rounds up to a whole point, and requests `max(left, right) + padding`.
- Reports are ignored when the change is under one point, so a layout pass cannot oscillate.

Model:

- `NotchViewModel` owns `requestedPanelHeights: [NotchTab: CGFloat]` and `requestPanelContentHeight(_:for:)`.
- `effectivePanelContentHeight(for:)` returns `min(configuredHeight, requestedHeight)` for Agents and the configured height for every other tab.
- `bodySize`'s open case uses the effective height. The static `NotchTab.panelExtraHeight` +16 is removed; before the first measurement, Agents falls back to the configured height.
- Requests animate with `Motion.state`, matching tab selection. Switching tabs reuses the cached per-tab value so returning to Agents does not re-expand first.
- The existing canvas clamp in `bodySize` remains the hard bound. Content taller than the configured height keeps the existing scroll path instead of growing the panel.

Snapshot determinism:

- `NotchViewModel.preview(...)` gains a fitted-height override (or accepts a seed dictionary of requested heights) so fixtures draw at their target size immediately.
- Snapshot fixtures set the fitted height for the one-, two-, and three-agent Agents tabs; live measurement is covered by sizing tests.

Alternatives considered:

- Analytic row heights: brittle with wrapped plan names, messages, and changing row content.
- Resizing the AppKit window: unnecessary because the window already reserves the full canvas.
- Fitting all tabs: Home's player uses a `GeometryReader` to fill its card, and other tabs have scroll-heavy layouts; changing all of them is outside this change.

## Risks / Trade-offs

- **A stale `~/.codex/sessions` or `~/.claude/projects` can keep an uninstalled agent visible** → The data genuinely exists and remains watchable; the Cleanup surface lets users remove NotchNull-owned leftovers. We intentionally prefer "watchable" over "strictly installed" so a fresh install with data is not hidden by a missed executable.
- **An agent installed under an unusual prefix is not detected** → Common prefixes, node version-manager globs, the inherited `PATH`, and data markers cover normal installs. Opening Settings/Agents and app activation re-check without a restart.
- **Finder-launched `PATH` is narrow** → Known prefixes and directory globs are searched explicitly; no shell sourcing.
- **Availability changes while the panel is open** → Refreshes are cheap and published; changes animate with `Motion.state`. Throttling prevents repeated directory scans when switching apps quickly.
- **Removing the centering spacers changes the look at tall panel sizes** → This is the requested behavior; a single-provider snapshot and the existing large/medium snapshots make the difference reviewable.
- **Empty states at short fitted heights have little room** → Copy stays short; the session empty state is the only longer text and is included in the measured height.
- **Snapshot fixtures become machine-dependent if the override is forgotten** → The `installed:` parameter is explicit and existing snapshot seeding sets it. Detection tests do not depend on the host. Fitted heights use a separate explicit preview override.
- **Measurement feedback loop** → Probes sit on intrinsic content, not the stretched `Card`; reports are rounded and ignored below a one-point delta.
- **First visit flashes at the configured height** → Agents falls back to the configured height for one layout pass, then animates to the fitted height; the per-tab value is cached for later visits.
- **The right column is harder to measure than the provider column** → Measure the header, row stack, empty state, and approval prompt separately; cap the result at the configured height so a long session list cannot grow the panel without bound.
- **`panelHeight` changes meaning for Agents** → Treat it as a maximum only for Agents, keep its exact meaning for other tabs, and state that in the settings copy and generated reference.
- **Tab switches animate two size changes** → Tab selection already uses `Motion.state`; fitted-height requests use the same animation and the body canvas makes the change safe.

## Migration Plan

No data migration. Existing preferences, `hiddenTabs`, and integrations are read as they are. On first launch after the change, availability is detected and absent integrations stop rendering. `panelHeight` keeps its stored value and becomes a maximum for Agents; no preference is rewritten. Rollback is a code revert.

## Open Questions

None blocking. Whether Setup should stop naming Claude Code and Codex when neither is installed is a copy polish item that does not change this design or the specification.
