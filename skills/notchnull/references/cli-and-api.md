# CLI and local API

## CLI

`~/.notchnull/bin/notchnull` (the app writes it on launch; it calls the installed app's binary).
To type just `notchnull`: `export PATH="$HOME/.notchnull/bin:$PATH"` in the shell profile.

```sh
notchnull show "Tests passed" --subtitle "142 in 8.1s" --symbol checkmark.circle.fill --tint green
notchnull show "Uploading" --id upload --progress 0.4 --persistent
notchnull show "Uploading" --id upload --progress 0.9 --persistent   # same id updates in place
notchnull hide upload                                              # or `notchnull hide` for all
notchnull wing --symbol hammer.fill --leading "build" --trailing "42s" --tint orange --for 30
notchnull show "PR merged" --symbol arrow.triangle.merge --open https://github.com/o/r/pull/12

notchnull open widgets        # open the panel on a tab (no tab: last one)
notchnull close
notchnull reload              # re-read ~/.notchnull/widgets
notchnull widget ci run       # run a widget's command now
notchnull widget ci data '{"failing": ["e2e"]}'
notchnull settings            # current settings.json as the app sees it
notchnull settings set '{"motion": {"speed": 1.4}}'
notchnull status              # same as ~/.notchnull/status.json

notchnull render /tmp/n.png --tab widgets        # open panel on a tab
notchnull render /tmp/n.png --closed             # closed notch
notchnull render /tmp/n.png --wing               # the widget wing that is up, if any
notchnull render /tmp/n.png --activity '{"symbol":"bell.fill","title":"Hi","subtitle":"there"}'
notchnull render /tmp/n.png --tab home --demo    # sample music, agents, battery…
notchnull render /tmp/n.png --tab home --full    # whole canvas instead of a crop
notchnull render /tmp/n.png --tab home --transparent   # no wallpaper, for compositing
```

`show` options: `--subtitle`, `--symbol` (SF Symbol, default `bell.fill`), `--tint` (color name or
`#RRGGBB`), `--leading`/`--trailing` (short text beside the camera), `--progress 0..1`,
`--for SECONDS` (default 4, max 3600), `--persistent` (until hidden), `--id` (default `cli`),
`--open URL` (what a click opens). `wing` takes the same options without a title.

Exit status is 0 on success. When the app is not running, every command except `render` and
`path` fails with a message saying so.

`render` runs in its own process with the user's settings.json and widget files (commands run
once), draws at 2x and exits. The PNG is cropped to the notch plus a margin. It is how you check
your work: read the image and look for truncated text, red "Unknown type" labels and clutter.

## Hooks for agents

End of a long task: `notchnull show "Refactor done" --subtitle "12 files · tests green" --symbol checkmark.circle.fill --tint green`.

Progress during a task: show with `--id task --persistent --progress …` at milestones, then
`notchnull hide task`.

(Claude Code and Codex sessions already appear in the notch on their own: running time,
approvals and finished runs. Use these commands for things NotchNull cannot see.)

## HTTP API

`http://127.0.0.1:47823/v1/…`, listening on this Mac only. Every request needs the header
`X-NotchNull-Token: <contents of ~/.notchnull/token>`; without it the server answers 403.
Bodies are JSON. Responses are JSON: `{"ok": true}` or `{"ok": false, "error": "…"}`.

| Method and path | Body | Does |
|---|---|---|
| `GET /v1/status` | | App version, settings errors, widgets with state/data/error, activity ids. |
| `POST /v1/activity` | activity (below) | Shows or updates an activity by `id`. |
| `POST /v1/activity/hide` | `{"id": "…"}` or `{}` | Hides one, or all. |
| `POST /v1/open` | `{"tab": "widgets"}` or `{}` | Opens the panel. |
| `POST /v1/close` | | Closes it. |
| `POST /v1/widgets/reload` | | Re-reads widget files. |
| `POST /v1/widgets/<id>/run` | | Runs the widget's command. |
| `POST /v1/widgets/<id>/data` | any JSON | Replaces the widget's data. |
| `GET /v1/settings` | | Current settings. |
| `POST /v1/settings` | partial settings | Applies it; 400 with `errors` if something was rejected. |

Activity body:

```json
{
  "id": "deploy",
  "symbol": "paperplane.fill",
  "tint": "accent",
  "leading": "web",
  "trailing": "64%",
  "title": "Deploying landing",
  "subtitle": "vercel · production",
  "progress": 0.64,
  "duration": 8,
  "persistent": false,
  "leadingView": { "type": "gauge", "value": 0.64, "size": 18 },
  "action": { "open": "https://vercel.com/dashboard" }
}
```

At least one of `symbol`, `leading`, `trailing`, `title`, `subtitle`, `leadingView`, `trailingView`
is required. With `title` or `subtitle` it is a banner under the notch; otherwise a wing beside it.
`leadingView`/`trailingView` take widget nodes (see widgets.md). `action` uses the widget action keys.

```sh
curl -s -X POST http://127.0.0.1:47823/v1/activity \
  -H "X-NotchNull-Token: $(cat ~/.notchnull/token)" \
  -d '{"id":"backup","symbol":"externaldrive.fill","title":"Backup finished","subtitle":"212 GB"}'
```
