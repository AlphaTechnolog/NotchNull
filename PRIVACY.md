# Privacy

NotchNull has no analytics, no telemetry, no accounts and no server. This page lists everything it reads, writes and sends, so you can check it against the source.

## Network

| Request | When | What is sent |
|---|---|---|
| `GET https://api.anthropic.com/api/oauth/usage` | Every 90 seconds while Claude usage is enabled | Your existing Claude Code access token, read from the macOS keychain item `Claude Code-credentials`. NotchNull never refreshes, copies or stores the token. |

That is the only outgoing request. Codex usage is read from local files. opencode sessions are read from a local database.

## Files read

| Path | Why |
|---|---|
| `~/.claude/projects/*/*.jsonl` | Live Claude Code sessions, the last message of a turn, tokens used today |
| `~/.codex/sessions/**/*.jsonl` | Codex sessions and rate limits |
| `~/.local/share/opencode/opencode.db` | opencode sessions and token totals (read-only; v2 `session_v2`/`session_message` tables, pre-2.0 `session` history ignored) |
| `~/.claude/settings.json` | Only when you click **Enable** for approval alerts |
| `~/Downloads` | Download progress and AirDrop arrivals (file names and the quarantine record) |
| Screenshots (Spotlight query) | The screenshot preview |
| The pasteboard | Clipboard history, only while enabled; password managers' concealed items are skipped |

## Files written

Everything lives in `~/Library/Application Support/NotchNull/`:

| File | Contents |
|---|---|
| `clipboard.sealed` | Clipboard history, encrypted with AES-GCM |
| `clipboard.key` | The key for it, readable only by your user |
| `Tray/`, `tray.json` | Files you parked in the Tray |
| `claude-hook.sh`, `hook-token` | Only after you enable approval alerts |
| `~/.config/opencode/plugins/notchnull.js` | Only after you enable the opencode plugin in Settings → Agents |

When you enable approval alerts, NotchNull adds its hook to `~/.claude/settings.json`, keeps your other hooks and saves a backup next to it. The hook talks to NotchNull over `127.0.0.1` with a per-install token. The opencode plugin (`POST 127.0.0.1:47823/opencode`) uses the same token. No new external network.

## Permissions

All optional. Accessibility (to replace the system volume/brightness HUD), Calendars (Up next), Bluetooth (device connections), Camera (the mirror tab, off by default).

## Removing NotchNull

Quit it, delete the app, delete `~/Library/Application Support/NotchNull/`, and — if you enabled approval alerts — click **Disconnect** in Settings → Agents first, or delete the `notchnull-hook` entries from `~/.claude/settings.json`.
