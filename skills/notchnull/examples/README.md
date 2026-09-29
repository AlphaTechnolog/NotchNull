# Example widgets

Each file is a working widget. Copy one into `~/.notchnull/widgets/` (or press Add in
Settings › Build › Examples), then change it. The `description` key says what it does and what
it needs; the app ignores it otherwise.

| File | What it shows | Needs |
|---|---|---|
| `ci.json` | Failing GitHub Actions runs, and a red wing beside the notch while any fail. | `gh`, and your OWNER/REPO in the command |
| `pull-requests.json` | Your open pull requests, each with a button that opens it. | `gh` |
| `disk.json` | How full the startup disk is, as a number and a bar. | nothing |
| `todo.json` | The first lines of `~/todo.txt`. | a `~/todo.txt` |
| `world-clock.json` | The time in a few other zones. Edit the zones in the command. | nothing |

Between them they use most node types (`column`, `row`, `list`, `text`, `value`, `badge`, `bar`,
`symbol`, `button`, `spacer`), a `wing`, and templates with filters. See
[../references/widgets.md](../references/widgets.md) for the full format.
