import AppKit
import Foundation

/// `~/.notchnull`: the folder you (or your agent) edit to reshape the notch while it runs.
///
///     settings.json            every setting, live in both directions
///     settings.reference.md    what each setting does, generated from the app itself
///     widgets/*.json           your own panels, hot-reloaded
///     status.json              what the app thinks of your files: errors, widget state
///     bin/notchnull            CLI: show activities, open tabs, render PNGs
///     skill/                   the agent skill that explains all of this
///     token                    secret for the local API on 127.0.0.1
enum NotchHome {
    static let root = Constants.Paths.home.appendingPathComponent(".notchnull", isDirectory: true)
    static let widgets = root.appendingPathComponent("widgets", isDirectory: true)
    static let settings = root.appendingPathComponent("settings.json")
    static let settingsReference = root.appendingPathComponent("settings.reference.md")
    static let status = root.appendingPathComponent("status.json")
    static let bin = root.appendingPathComponent("bin", isDirectory: true)
    static let cli = bin.appendingPathComponent("notchnull")
    static let skill = root.appendingPathComponent("skill", isDirectory: true)
    static let token = root.appendingPathComponent("token")
    static let readme = root.appendingPathComponent("README.md")

    /// Where agents look for skills. Linking is only done when the user asks in Settings.
    enum Agent: String, CaseIterable, Identifiable {
        case claude, codex

        var id: String { rawValue }
        var title: String { self == .claude ? "Claude Code" : "Codex" }
        var skillsFolder: URL {
            Constants.Paths.home.appendingPathComponent(self == .claude ? ".claude/skills" : ".codex/skills", isDirectory: true)
        }
        var link: URL { skillsFolder.appendingPathComponent("notchnull") }
    }

    /// Creates the folder on launch and refreshes the parts the app owns (skill, CLI, token copy,
    /// README). User files (settings.json, widgets) are never overwritten here.
    static func bootstrap() {
        let fm = FileManager.default
        for dir in [root, widgets, bin] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        writeIfChanged(readmeContents, to: readme)
        writeIfChanged(cliContents, to: cli)
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cli.path)
        writeIfChanged(ClaudeHookInstaller.token(), to: token)
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: token.path)
        installBundledSkill()
        removeUntouchedExampleWidget()
    }

    // MARK: Skill

    /// The skill ships inside the app (and in the repo at skills/notchnull) and is copied here
    /// on every launch so it always matches the running version.
    static var bundledSkill: URL? {
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("skill"), FileManager.default.fileExists(atPath: bundled.appendingPathComponent("SKILL.md").path) {
            return bundled
        }
        // `swift run` from the repo: use the source tree's copy.
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("skills/notchnull")
        return FileManager.default.fileExists(atPath: repo.appendingPathComponent("SKILL.md").path) ? repo : nil
    }

    private static func installBundledSkill() {
        guard let source = bundledSkill else {
            Log.app.notice("No bundled skill found; ~/.notchnull/skill left as is")
            return
        }
        let fm = FileManager.default
        let staging = root.appendingPathComponent(".skill-new", isDirectory: true)
        try? fm.removeItem(at: staging)
        do {
            try fm.copyItem(at: source, to: staging)
            if fm.fileExists(atPath: skill.path) { _ = try fm.replaceItemAt(skill, withItemAt: staging) } else { try fm.moveItem(at: staging, to: skill) }
        } catch {
            Log.app.error("Could not refresh the skill: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func isSkillLinked(for agent: Agent) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: agent.link.path)) == skill.path
    }

    /// Links ~/.claude/skills/notchnull (or Codex's) to the skill here. An existing folder with
    /// that name that is not our link is left alone and reported.
    static func linkSkill(for agent: Agent) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: agent.skillsFolder, withIntermediateDirectories: true)
        if let existing = try? fm.destinationOfSymbolicLink(atPath: agent.link.path) {
            if existing == skill.path { return }
            try fm.removeItem(at: agent.link)
        } else if fm.fileExists(atPath: agent.link.path) {
            throw CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: agent.link.path])
        }
        try fm.createSymbolicLink(at: agent.link, withDestinationURL: skill)
    }

    static func unlinkSkill(for agent: Agent) {
        guard isSkillLinked(for: agent) else { return }
        try? FileManager.default.removeItem(at: agent.link)
    }

    // MARK: Files the app owns

    static func writeIfChanged(_ text: String, to url: URL) {
        let data = Data(text.utf8)
        guard (try? Data(contentsOf: url)) != data else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// The executable inside the running app, so the CLI always calls the installed version.
    static var executable: String { Bundle.main.executableURL?.path ?? CommandLine.arguments[0] }

    private static var cliContents: String {
        """
        #!/bin/sh
        # NotchNull CLI. Generated by the app on launch; edits are overwritten.
        # Add to PATH: export PATH="$HOME/.notchnull/bin:$PATH"
        exec "\(executable)" cli "$@"
        """
    }

    private static var readmeContents: String {
        """
        # ~/.notchnull

        This folder is your notch. NotchNull watches it and applies changes while it runs.

        - `settings.json`: every setting. Edit it and the notch changes; change a setting in the app and this file updates. `settings.reference.md` lists each key.
        - `widgets/*.json`: your own panels. The Widgets tab appears with the first file; save a file and it reloads.
        - `status.json`: errors in your files and the state of each widget. Read it after an edit.
        - `bin/notchnull`: `notchnull show "Deploy done" --symbol checkmark.circle.fill --tint green`, `notchnull render out.png --tab widgets`, `notchnull help`.
        - `skill/`: the agent skill. Settings › Build lets you link it for Claude Code and Codex.

        Want more than files can do? NotchNull is open source: https://github.com/Obed0101/NotchNull. The skill explains how to change the app itself.
        """
    }

    /// Earlier versions wrote this example the first time. The notch now starts without widgets
    /// (the Widgets tab appears with the first one), so the example goes away unless it was edited.
    private static func removeUntouchedExampleWidget() {
        let file = widgets.appendingPathComponent("disk.json")
        guard let data = try? Data(contentsOf: file), data == Data(legacyExampleWidget.utf8) else { return }
        try? FileManager.default.removeItem(at: file)
    }

    private static let legacyExampleWidget = """
        {
          "title": "Startup disk",
          "symbol": "internaldrive.fill",
          "tint": "teal",
          "size": "small",
          "refresh": 60,
          "command": "df -k / | awk 'NR==2{print $5+0}'",
          "view": {
            "type": "column", "spacing": 6, "children": [
              { "type": "value", "value": "{{data}}", "unit": "%", "label": "Used" },
              { "type": "bar", "value": "{{data | div 100}}", "color": "teal" },
              { "type": "text", "text": "Edit ~/.notchnull/widgets/disk.json", "style": "caption", "color": "tertiary" }
            ]
          }
        }
        """
}
