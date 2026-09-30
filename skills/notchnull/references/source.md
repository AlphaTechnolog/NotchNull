# Changing NotchNull itself

Files cover widgets, activities and every setting. For anything else (a new view type, a new tab,
a new system integration, different physics, a redesigned Settings page) change the source.
NotchNull is GPL-3.0 Swift: https://github.com/Obed0101/NotchNull

Ask the user before replacing their installed app, and tell them what you changed.

## Get it building

```sh
git clone https://github.com/Obed0101/NotchNull ~/Code/NotchNull   # or the user's existing clone
cd ~/Code/NotchNull
swift build && swift test
.build/debug/NotchNull --snapshots /tmp/snap        # every notch state as PNGs, fixture data
scripts/build-app.sh                                 # build/NotchNull.app, release, ad-hoc signed
```

Needs Xcode's toolchain (Swift 6 compiler, Swift 5 language mode), macOS 14+.

To run the build: `pkill -x NotchNull; open build/NotchNull.app`. To install over the current
app: `scripts/build-app.sh --install` (copies to /Applications). Each ad-hoc build is a new
signature, so macOS asks again for Accessibility (HUD replacement, pasting from Clipboard).

## Map

| Path | What |
|---|---|
| `App/` | Launch, services wiring (`AppServices`), coordinator per screen, snapshot renderer. |
| `Core/` | Notch geometry, the panel window, phases (`NotchViewModel`), activity priorities (`ActivityCenter`). |
| `Config/` | `Preferences` (every setting), `Theme` (colors, type, sizes), `Motion` (springs), `Constants`. |
| `Services/` | One source of data each: media, agents, devices, system, files. |
| `Platform/` | The user-facing platform: `~/.notchnull` (`NotchHome`), `settings.json` sync (`SettingsFile`), widgets (`Widgets/`), custom activities, local API (`NotchAPI`), CLI (`NotchCLI`). |
| `UI/Notch/` | The notch body, its shape, and how much room each activity takes (`ActivityLayout`). |
| `UI/Activities/` | What shows beside the notch for each `ActivityKind`. |
| `UI/Panel/` | The open panel and each tab. |
| `UI/Settings/` | The Settings window, one struct per section. |
| `UI/Components/` | Shared pieces: gauges, sparkline, scroll, pressable buttons, formatting. |

Read `docs/design-contract.md` before visual changes. Use `Theme` and `Motion` tokens rather
than new colors and durations; everything animates and respects Reduce Motion.

## Common changes

**A new widget node type.** `Platform/Widgets/WidgetView.swift`: add a `case` to the `switch type`
in `WidgetNodeView.content` and a computed view beside the others. Read props with `prop`, `text`,
`number`, `color`. Document it in `skills/notchnull/references/widgets.md`.

**A new setting.** Add the `@Published` property with its key in `Config/Preferences.swift`
(follow an existing one), a row in the right `UI/Settings` section, and a `SettingField` in
`Platform/SettingsFile.swift` so it appears in settings.json and its generated reference.

**A new tab.** Add the case to `NotchTab` (`Core/NotchViewModel.swift`) with a symbol, route it in
`UI/Panel/ExpandedPanel.swift`, decide in `Preferences.isFeatureEnabled` when it shows, and add a
snapshot state in `App/SnapshotRenderer.swift`.

**A new activity.** Add a case to `ActivityKind` (`Core/ActivityCenter.swift`; position is
priority), its layout in `UI/Notch/ActivityLayout.swift`, its view in `UI/Activities/` routed from
`ActivityContentView`, a tint in `NotchRootView`, and a fixture in `SnapshotRenderer.seed`.

**A new data source.** A service in `Services/` owned by `AppServices`, published as an
`ObservableObject` and injected in `withServices`. Keep work off the main thread and give it a
`preview(…)` for snapshots.

**The Settings page.** `UI/Settings/SettingsView.swift` (sections, `SettingsGroup`, `SettingsRow`,
`SettingsToggle`) and the section files beside it. Add a section by adding a `Section` case with
a title, symbol and tint, and routing it to a new struct. `SetupSettings` (presets and looks,
read by `Platform/Recipes.swift` from `skills/notchnull/presets` and `themes`) and `BuildSettings`
(skill, CLI, examples, widgets) are good models; `81-settings-setup` and `80-settings-build`
in the snapshots show them.

**A new preset, look or example.** Add a file to `skills/notchnull/presets`, `themes` or
`examples`; `scripts/build-app.sh` copies the folder into the app. A preset's preview is
`<id>.png` next to it: render it with `notchnull render <id>.png --tab home --demo --transparent`
using the preset's settings.

## Check your work

1. `swift build` with no errors, `swift test` green.
2. `.build/debug/NotchNull --snapshots /tmp/snap` and look at the states you touched.
3. Run the built app and try the change for real.
4. If what NotchNull reads or writes changed, update `PRIVACY.md`.
