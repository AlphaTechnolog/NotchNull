# Recipes: looks, presets and whole notches

A recipe is one JSON file that changes many settings at once and can carry widgets with it. The
presets and looks on the Setup page are recipes; so is a notch you package for someone else.

```json
{
  "name": "Night Shift",
  "summary": "Deep plum, slow motion, only Home and Widgets.",
  "order": 50,
  "settings": {
    "look": { "body": "tinted", "tint": "#1B1226", "accent": "#C9A7FF", "accentFollowsMac": false },
    "motion": { "speed": 1.1, "bounce": 0.05 },
    "tabs": { "hidden": ["tray", "downloads", "clipboard", "mirror", "controls"] }
  },
  "widgets": {
    "focus": { "title": "Focus", "view": { "type": "text", "text": "Deep work until 6" } }
  }
}
```

| Key | Meaning |
|---|---|
| `settings` | Required. A partial settings.json: only the keys it names change. Check each against `~/.notchnull/settings.reference.md`. |
| `name`, `summary` | Shown on the Setup page and by `notchnull recipes`. Without `name`, the file name is used. |
| `order` | Position on the Setup page; lower first. The shipped ones use 0–20. |
| `widgets` | Optional. `{ "<id>": <widget file> }`, each in the format of [widgets.md](widgets.md). |

A recipe cannot set the `downloads` section. What happens to the files in someone's Downloads
folder is theirs to decide, so that section is dropped when a recipe is read. Change it only with
`notchnull settings set` when the user asks for it.

## Where the file goes

| Folder | Shows up as | Use it for |
|---|---|---|
| `~/.notchnull/themes/<id>.json` | A swatch under **Look** in Settings › Setup | Colors, corners, glow: the `look` section, sometimes `motion`. |
| `~/.notchnull/presets/<id>.json` | A card at the top of Setup | How much the notch shows: `features`, `tabs`, `home`, `activities`, sizes. |

Both folders belong to the user and survive every update. A file there with the same name as a
shipped one replaces it in the list. Never save into `~/.notchnull/skill/`: that folder is
rewritten on every launch.

A preset card shows `<id>.png` beside its file when there is one. Render it after applying the
preset: `notchnull render ~/.notchnull/presets/<id>.png --tab home --demo --transparent`.

## Designing a notch from a brief

When the user describes a notch they want ("calm, for writing", "everything about my deploys",
"like a terminal") rather than one setting:

1. Read `status.json`, `settings.reference.md` and the closest shipped file in
   [../themes/](../themes/) or [../presets/](../presets/). Start from that file, not from nothing.
2. `notchnull backup before-<id>` so there is a way back.
3. Write the recipe into `~/.notchnull/themes/` or `presets/`. Decide a small number of things on
   purpose: one body material, one accent, how fast it moves, which tabs exist. Leave the rest of
   the user's settings alone by not naming them.
4. `notchnull apply <id>`. It prints the backup it took and any setting the app rejected.
5. Render the states the brief is about and look at them: `--closed`, `--tab home`, a wing with
   `--activity '{"symbol":"hammer.fill","leading":"build","trailing":"42s"}'`. Check the accent
   against the body: text and symbols must stay readable.
6. Fix the file, apply again, render again. Stop when the render matches the brief.
7. Tell the user the name it has in Setup, the file's path, and that `notchnull restore` undoes it.

Widgets that belong to the notch you designed go in `~/.notchnull/widgets/` as usual; put them in
the recipe's `widgets` only when the recipe is meant to travel.

## Sharing a notch

```sh
notchnull export ~/Desktop/my-notch.json --name "Night Shift" --summary "Plum, slow, two tabs"
```

writes the user's current look and layout (`look`, `size`, `island`, `motion`, `tabs`, `home`,
`activities`) and every widget file as one recipe. It leaves out which features are on, behavior,
shortcuts and downloads: those describe one person's Mac, not a design. Before the user sends the
file, read its `widgets` and remove anything personal: paths with their name, repository names,
tokens in a command.

## Applying a notch someone sent

```sh
notchnull apply ~/Downloads/their-notch.json
```

backs up the user's files, applies the settings, and lists the widgets the file carries with their
commands, installing none. Read every command. A widget command is a shell command that runs on a
timer with the user's permissions: explain what each one does, and what it needs (`gh`, a file, a
repository). When the user agrees:

```sh
notchnull apply ~/Downloads/their-notch.json --widgets            # keeps widgets they already have
notchnull apply ~/Downloads/their-notch.json --widgets --replace  # overwrites same-named ones
```

Then check `status.json` for widgets in `"state": "error"` (a missing tool, a path from the other
person's Mac) and fix or disable them, and render. To keep the notch as a look they can return to,
copy the file into `~/.notchnull/themes/`. `notchnull restore` puts everything back.
