# Privacy

NotchNull has no analytics, no telemetry, no accounts and no server. This page lists everything it reads, writes and sends, so you can check it against the source.

## Network

| Request | When | What is sent |
|---|---|---|
| `GET https://api.anthropic.com/api/oauth/usage` | Every 90 seconds while Claude usage is enabled | Your existing Claude Code access token, read from the macOS keychain item `Claude Code-credentials`. NotchNull never refreshes, copies or stores the token. |

That is the only outgoing request. Codex usage is read from local files.

## Files read

| Path | Why |
|---|---|
| `~/.claude/projects/*/*.jsonl` | Live Claude Code sessions, the last message of a turn, tokens used today |
| `~/.codex/sessions/**/*.jsonl` | Codex sessions and rate limits |
| `~/.claude/settings.json` | Only when you click **Enable** for approval alerts |
| `~/Downloads` | Download progress, AirDrop arrivals and cleanup deadlines (file names, sizes, the quarantine record and the site a file came from) |
| `~/.notchnull/` | Your settings file and widgets, watched while the app runs |
| Screenshots (Spotlight query) | The screenshot preview |
| The pasteboard | Clipboard history, only while enabled; password managers' concealed items are skipped |

## Files written

Everything lives in `~/Library/Application Support/NotchNull/`:

| File | Contents |
|---|---|
| `clipboard.sealed` | Clipboard history, encrypted with AES-GCM |
| `clipboard.key` | The key for it, readable only by your user |
| `Tray/`, `tray.json` | Files you parked in the Tray |
| `hook-token` | The per-install secret for the local API and hooks, readable only by you |
| `claude-hook.sh` | Only after you enable approval alerts |
| `download-cleanup.json` | Downloads waiting for their deadline: file name, size, source site, a bookmark to follow renames, and when it expires |

And `~/.notchnull/`, the folder you (or your agent) edit to change the notch:

| File | Contents |
|---|---|
| `settings.json`, `settings.reference.md` | Every setting, rewritten when you change one in the app; the generated reference |
| `widgets/*.json` | Your widgets. The app writes one example (`disk.json`) the first time only and never touches the rest |
| `status.json` | Errors in your files and each widget's latest data |
| `bin/notchnull`, `skill/`, `README.md` | The CLI, the agent skill and a guide, refreshed on every launch |
| `token` | A copy of `hook-token` for scripts, readable only by you |

Widget files can contain shell commands. NotchNull runs them in your login shell with a timeout, exactly as written, and only from files in that folder. Their output stays on your Mac, but a command you or your agent write can do anything a command in Terminal can, network included. Read a widget before you drop it in.

**Install** in Settings › Build creates one symbolic link, `~/.claude/skills/notchnull` or `~/.codex/skills/notchnull`, pointing at `~/.notchnull/skill`. **Remove** deletes only that link.

## Local API

NotchNull listens on `127.0.0.1:47823`, never on the network. Every request must carry the token in an `X-NotchNull-Token` header, so web pages cannot call it. It shows activities, opens tabs, pushes widget data and reads or changes settings; it cannot run arbitrary commands by itself, though an activity or widget button can run the command it was given when you click it.

When you enable approval alerts, NotchNull adds its hook to `~/.claude/settings.json`, keeps your other hooks and saves a backup next to it. The hook talks to NotchNull over `127.0.0.1` with a per-install token.

## Permissions

All optional. Accessibility (to replace the system volume/brightness HUD, and to paste with Return from the Clipboard shortcut), Calendars (Up next), Bluetooth (device connections), Camera (the mirror tab, off by default).

## Removing NotchNull

Quit it, delete the app, delete `~/Library/Application Support/NotchNull/` and `~/.notchnull/` (plus the skill links above if you installed them), and — if you enabled approval alerts — click **Disconnect** in Settings → Agents first, or delete the `notchnull-hook` entries from `~/.claude/settings.json`.
