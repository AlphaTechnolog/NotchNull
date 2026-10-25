# Tasks

## 1. Detection foundation

- [x] 1.1 Add an `AgentInstallation` helper with injected home directory, executable directory list, and `FileManager`, and per-provider executable names plus watchable data markers; verify it compiles and returns an empty set for an empty temporary home.
- [x] 1.2 Implement executable lookup across `PATH`, common user prefixes, node version-manager bin folders, and system prefixes; verify a temporary bin directory containing a fake `claude`, `codex`, and `opencode` records each provider as installed.
- [x] 1.3 Add the watchable-data rules: `~/.claude/projects`, `~/.codex/sessions` or `config.toml`/`auth.json`, and `~/.local/share/opencode/opencode.db`; verify data-only installs are detected.
- [x] 1.4 Add negative tests proving `~/.claude/settings.json` alone and `~/.codex/hooks.json` alone do not count as installed, and run the new `AgentInstallationTests` with `swift test --filter AgentInstallationTests`.

## 2. Availability plumbing

- [x] 2.1 Add `AgentHub.installed` as a published set seeded from an injectable `AgentInstallation`, plus `refreshInstalled()`; verify a unit test swaps the installation fixture and observes the published set change without touching `Preferences`.
- [x] 2.2 Observe `NSWorkspace.didActivateApplicationNotification` with a two-second throttle and call `refreshInstalled()` at launch; verify repeated notifications inside the throttle window do not re-scan while a later notification does.
- [x] 2.3 Extend `AgentHub.preview(...)` with an `installed:` override and update snapshot call sites; verify `swift build` succeeds and snapshots no longer read the real home directory for availability.
- [x] 2.4 Add a pure provider-visibility helper that combines the installed set with the existing watch preferences, preserving `AgentProvider.allCases` order; verify tests cover 0, 1, 2 and 3 visible providers and the disabled-preference case.

## 3. Agents panel layout

- [x] 3.1 Restructure the provider column in `AgentsTab` to remove the outer spacer wrapper and lay out visible provider blocks at intrinsic height, with dividers generated only between visible entries; verify a single-provider render sits at the top with blank space below.
- [x] 3.2 Restructure `SessionsCard` to remove the top/bottom spacers around the session list while keeping the existing 32-point row height; verify one session sits directly below the header with blank space below.
- [x] 3.3 Add the zero-installed provider empty state and make the Sessions empty-state copy name only installed agents using `ListFormatter`; verify copy with 0, 1, 2 and 3 installed providers in a unit test or fixture render.
- [x] 3.4 Add a single-installed-provider snapshot fixture and render one-, two-, and three-provider Agents tabs; verify blocks stack at the top and nothing divides the available height.
- [x] 3.5 Regenerate `docs/images/agents.png` from the snapshot renderer if the layout changes the documented image; verify the image shows the top-aligned columns.

## 4. Settings and Home gating

- [x] 4.1 Gate the Claude Code, Codex and opencode groups in `AgentSettings` on availability, hide the Notch session group when none are installed, hide the opencode account opt-in when opencode is absent, and add the zero-installed explanation; verify each combination with a unit-tested pure state model and a settings render.
- [x] 4.2 Add the Settings → Agents `Cleanup` group for orphaned Claude hooks and the orphaned opencode plugin; verify a pure test covers each orphan condition and that Disconnect is shown only while the agent is absent and the integration remains installed.
- [x] 4.3 Hide the Claude Code sign-in row in `PermissionList` when Claude Code is absent; verify the permissions render and existing permission tests still pass.
- [x] 4.4 Gate the Home `Agents` limits row on at least one installed provider and filter its limits to installed agents; verify `HomeRowsTests` cover installed-only limits and the row disappearing when none are installed.
- [x] 4.5 Filter `BuildSettings` agent skill rows to installed agents while keeping a row whose skill link exists for an absent agent; verify a test covers the `NotchHome.Agent` to `AgentProvider` mapping and the linked-but-absent case.

## 5. Integration verification

- [x] 5.1 Run the full `swift test` suite and verify no existing suite regresses.
- [x] 5.2 Run the snapshot renderer and inspect the Agents tab with zero, one, two and three installed providers, plus Settings → Agents with zero and three installed; verify empty states, cleanup placement and top alignment.
- [x] 5.3 On this Mac, verify only opencode integrations appear while `~/.claude/settings.json` and `~/.codex/hooks.json` exist, then simulate an absent opencode fixture and verify both Agents-tab card columns show their empty states while the Agents tab remains in the panel.
- [x] 5.4 Run `openspec validate agents-installed-only --strict` and fix any spec formatting or length issues before review.

## 6. Fitted Agents panel height

- [x] 6.1 Add a pure panel-fit calculation that rounds the taller column height up, adds card and panel padding, and caps the result at the configured panel height and canvas bound; verify a new `PanelFitTests` covers one-, two-, and three-block fits, tall content, and canvas clamping.
- [x] 6.2 Add `NotchViewModel` fitted-height state and a `requestPanelContentHeight(_:for:)` API, make `bodySize` use the effective height for the Agents tab, and remove the static `panelExtraHeight`; verify `PanelSizingTests` cover shrink, cap, tab switching, preference changes, hidden/disabled Agents, and the canvas clamp.
- [x] 6.3 Measure the intrinsic heights of the provider/plan column, session header, session rows, empty state, and approval prompt, report the taller column plus padding to the model, and guard against layout oscillation with a rounding threshold; verify one-agent and multi-agent fixture renders shrink correctly.
- [x] 6.4 Add a fitted-height override to the snapshot preview path so `ImageRenderer` does not depend on a live measurement pass, then render one-, two-, and three-agent fixtures at their fitted sizes; verify the images show no fixed-height blank area.
- [x] 6.5 Update the open-panel height settings wording, the generated settings reference text, and `docs/images/agents.png` to describe and show the fitted Agents panel; verify the Platform settings-reference tests and the refreshed documentation image.
- [x] 6.6 Run the full `swift test` suite, review the fitted Agents snapshots, and run `openspec validate agents-installed-only --strict`; verify all pass.

## Workflow follow-up

- Archive the change after implementation and review are complete.
