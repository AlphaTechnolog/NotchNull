# Spec Delta

## Purpose

Determines which coding-agent integrations NotchNull presents based on what is installed on this Mac, preserves user preferences when availability changes, and lets users clean up NotchNull configuration left behind by an agent they no longer have.

## ADDED Requirements

### Requirement: Agents are installed only when an executable or watchable data exists

NotchNull SHALL treat Claude Code, Codex or opencode as installed only when it finds that agent's executable in the user's shell path or a common install location, or finds the local data NotchNull watches. Configuration files that NotchNull itself can create, such as `~/.claude/settings.json` or `~/.codex/hooks.json`, SHALL NOT count on their own.

#### Scenario: Claude Code detected by executable
- **WHEN** a `claude` executable exists in a searched install directory
- **THEN** Claude Code is treated as installed even if `~/.claude/projects` does not exist yet

#### Scenario: Claude Code detected by session data
- **WHEN** `~/.claude/projects` exists
- **THEN** Claude Code is treated as installed

#### Scenario: Claude settings alone are not enough
- **WHEN** only `~/.claude/settings.json` exists, for example because NotchNull installed hooks
- **THEN** Claude Code is not treated as installed

#### Scenario: Codex detected by executable or watchable data
- **WHEN** a `codex` executable exists, or `~/.codex/sessions`, `~/.codex/config.toml`, or `~/.codex/auth.json` exists
- **THEN** Codex is treated as installed

#### Scenario: Codex hooks alone are not enough
- **WHEN** only `~/.codex/hooks.json` exists
- **THEN** Codex is not treated as installed

#### Scenario: opencode detected by executable or database
- **WHEN** an `opencode` executable exists in a searched install directory, or `~/.local/share/opencode/opencode.db` exists
- **THEN** opencode is treated as installed

### Requirement: Only installed agents appear in agent integrations

NotchNull SHALL present a Claude Code, Codex or opencode integration only when that agent is installed. Existing preference toggles SHALL continue to decide whether an installed agent is shown or watched.

#### Scenario: Provider block hidden when the agent is absent
- **WHEN** an agent is not installed but its watch preference is on
- **THEN** the Agents tab does not show that provider's usage block

#### Scenario: Settings groups hidden when the agent is absent
- **WHEN** Settings → Agents opens and an agent is not installed
- **THEN** that agent's settings group and footer are absent

#### Scenario: Home Agents row hides when none are installed
- **WHEN** no coding agent is installed
- **THEN** the Home quick rows do not include the "Agents" limits row

#### Scenario: Agent skill rows follow installation
- **WHEN** Settings → Build lists agent skill integrations
- **THEN** only installed agents are listed, except that an existing link for an absent agent remains removable

#### Scenario: Claude sign-in permission follows installation
- **WHEN** Claude Code is not installed
- **THEN** Settings → Permissions does not show the Claude Code sign-in row

#### Scenario: opencode account opt-in follows installation
- **WHEN** opencode is not installed
- **THEN** Settings → Agents does not offer the OpenCode account usage opt-in

### Requirement: Existing preferences survive an agent being absent

NotchNull SHALL NOT erase or rewrite an agent's watch preference just because the agent is not currently installed. The saved preference SHALL apply again when the agent becomes installed.

#### Scenario: Preference restored after installation
- **WHEN** a user had Codex watching enabled, Codex disappeared, and Codex is installed again
- **THEN** Codex integrations return with their previous enabled state

### Requirement: The Agents tab remains available with no installed agents

NotchNull SHALL keep the notch Agents tab available when no coding agent is installed. The tab SHALL explain that no agents were found and how sessions appear. Users SHALL continue to control tab visibility through Settings → Tabs & Wings.

#### Scenario: Empty Agents tab explains itself
- **WHEN** the user opens the Agents tab and no coding agent is installed
- **THEN** the tab remains visible and both columns show an explanatory empty state instead of blank cards

#### Scenario: User hides the tab
- **WHEN** the user turns off the Agents tab in Settings → Tabs & Wings
- **THEN** the notch no longer shows the tab

### Requirement: Orphaned NotchNull configuration can be cleaned up

NotchNull SHALL offer a way to remove its own hooks, plugin, or agent-skill link when the related agent is no longer installed.

#### Scenario: Claude hooks remain after Claude is gone
- **WHEN** Claude Code is not installed and NotchNull's hooks are still present in `~/.claude/settings.json`
- **THEN** Settings offers a cleanup action that disconnects those hooks

#### Scenario: opencode plugin remains after opencode is gone
- **WHEN** opencode is not installed and the NotchNull opencode plugin file still exists
- **THEN** Settings offers a cleanup action that removes that plugin

#### Scenario: Skill link remains after an agent is gone
- **WHEN** an agent-skill link exists for an agent that is not installed
- **THEN** Settings → Build still lists that link so the user can remove it

### Requirement: Availability changes are reflected without background polling

NotchNull SHALL refresh installed-agent availability when it launches and when agent-facing surfaces are opened or the app is activated after the user returns to it.

#### Scenario: Agent installed while NotchNull is running
- **WHEN** the user installs an agent, returns to NotchNull, and opens an agent-facing surface
- **THEN** that agent's integrations appear without restarting the app

#### Scenario: Agent removed while NotchNull is running
- **WHEN** an agent becomes unavailable and NotchNull refreshes availability
- **THEN** that agent's integrations stop appearing
