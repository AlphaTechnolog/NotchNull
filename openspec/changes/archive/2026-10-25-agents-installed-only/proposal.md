# Proposal

## Why

NotchNull shows every agent integration based only on preference toggles, even when Claude Code, Codex or opencode is not installed on the Mac. Users see empty or unavailable blocks, settings for tools they do not have, and an Agents tab whose columns float or stretch to fill height instead of reading as a fixed list. When only one agent is installed, the fixed open-panel height also leaves a large empty area below the short provider column. Hiding unavailable integrations, top-aligning the live ones, and fitting the Agents panel to its content makes the surface honest about what NotchNull can actually watch.

## What Changes

- Detect installed agents from both executables and real data:
  - Claude Code: `claude` executable or `~/.claude/projects`.
  - Codex: `codex` executable, `~/.codex/sessions`, `config.toml`, or `auth.json`.
  - opencode: `opencode` executable or `~/.local/share/opencode/opencode.db`.
  - Leftover `settings.json` / `hooks.json` alone do not count as installed.
- Show provider usage blocks, settings groups, permissions rows, Home "Agents" limits, and agent skill rows only for installed agents.
- Keep the notch Agents tab available even when no agent is installed. It becomes an explanatory empty state; users can already hide it themselves in Settings → Tabs & Wings.
- Add a Cleanup surface for Removed agents that still have NotchNull configuration: Claude hooks, the opencode plugin, or a dangling agent-skill link can be disconnected from Settings.
- Top-align both Agents tab columns. Provider blocks and session rows keep their intrinsic height and leave blank space below rather than stretching or centering in the available height.
- Let the Agents tab request a fitted open-panel height from the taller of its provider/plan and session columns plus padding. The configured panel height becomes the maximum for Agents; other tabs keep their fixed height, and content taller than the maximum still scrolls.
- Refresh installation state when the app launches and when agent-facing surfaces appear or the app is activated; no background polling.
- Add deterministic availability overrides for snapshots and unit tests.

## Capabilities

### New Capabilities

- `agent-integrations`: Installation-aware visibility, cleanup of orphaned hook/plugin/skill configuration, and remaining user control over the Agents tab.
- `agents-panel`: The notch Agents tab's top-aligned provider and session columns, intrinsic heights, content-fitted open-panel height, and installed-aware empty states.

### Modified Capabilities

<!-- No existing specs in this project yet. -->

## Impact

- **Services:** new agent installation detection helper; `AgentHub` owns published availability and refresh.
- **UI:** `AgentsTab`, `SessionsCard`, `HomeRows`/`QuickRowsCard`, `AgentSettings`, `PermissionList`, `BuildSettings`.
- **Panel sizing:** `NotchViewModel` owns per-tab fitted content heights; `AgentsTab` measures its intrinsic columns and requests a height. The AppKit window keeps its fixed canvas, so only the SwiftUI body height changes.
- **Panels/tabs:** `Preferences.isFeatureEnabled` and `NotchViewModel.panelTabs` keep their current Agents-tab gating; no new auto-hide behavior.
- **Preferences/settings.json:** existing feature toggles and `hiddenTabs` remain unchanged and keep working when an agent is installed later. `size.panelHeight` keeps its stored value and becomes a maximum for the Agents tab.
- **Tests/snapshots:** new detection tests, availability and fitted-height overrides in fixtures, and one-, two-, and three-installed-agent snapshots.
- **Docs:** document that the panel-height setting is a maximum for Agents, and refresh the Agents image; no settings keys are added.
