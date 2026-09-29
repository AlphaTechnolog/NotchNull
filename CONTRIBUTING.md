# Contributing to NotchNull

Thanks for helping. Bug reports, ideas and pull requests are all welcome.

## Getting started

```sh
swift build && swift test
scripts/build-app.sh && open build/NotchNull.app
```

Quit any running copy first (`pkill -x NotchNull`). Each local build is signed ad hoc, so macOS asks for Accessibility again after a rebuild if you use the HUD replacement.

## Seeing your change

`.build/debug/NotchNull --snapshots /tmp/snap` renders every notch state (closed, each activity, each tab at several sizes) to PNGs. Attach before/after snapshots to UI pull requests. New states belong in `Sources/NotchNull/App/SnapshotRenderer.swift`.

## Where things live

| Folder | What |
|---|---|
| `Sources/NotchNull/Core` | Notch geometry, phases and the activity priority queue |
| `Sources/NotchNull/Services` | One service per data source (media, agents, devices, system, files) |
| `Sources/NotchNull/UI` | Notch body, activities (wings), panel tabs, settings, shared components |
| `Sources/NotchNull/Config` | Preferences, theme tokens, motion, constants |
| `MediaBridge` | The Now Playing bridge that runs inside `/usr/bin/perl` |
| `docs/design-contract.md` | The visual direction: read it before changing UI |

## Guidelines

- **Everything animates.** Content condenses from blur, numbers use numeric transitions, the body springs. Respect Reduce Motion (`Motion.reduceMotion`).
- **Use the tokens** in `Theme.swift` and `Motion.swift` instead of new colors or durations.
- **Adding a device source or activity** means a new file: a watcher in `Services/Devices` that calls `DeviceEvents.shared.announce(_:)`, or a new `ActivityKind` with its layout and view.
- **Privacy is a feature.** No network calls beyond the one listed in [PRIVACY.md](PRIVACY.md); update that file if what NotchNull reads or writes changes.
- Add a test for parsing and logic (see `Tests/NotchNullTests`).

## License

By contributing you agree that your contribution is licensed under the [GPL-3.0](LICENSE).
