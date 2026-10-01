import SwiftUI

/// Settings › Build: the folder, skill, CLI and widgets that let you (or your agent) reshape the notch.
struct BuildSettings: View {
    @EnvironmentObject private var widgets: WidgetStore
    @EnvironmentObject private var settingsFile: SettingsFile
    @State private var linked: Set<NotchHome.Agent> = []
    @State private var linkError: String?
    @State private var copied: String?
    @State private var examples = Recipes.examples()
    @State private var installed = Set(Recipes.examples().filter(\.isInstalled).map(\.id))
    @State private var exampleError: String?

    static let starterPrompt = "Use the notchnull skill: add a widget with my open pull requests, and show a red wing beside the notch while CI is failing."
    private static let pathLine = #"export PATH="$HOME/.notchnull/bin:$PATH""#

    var body: some View {
        SettingsGroup(title: "Your notch", footer: "Everything here is plain files. Edit them by hand or let an agent do it; the notch updates as you save, and this window stays in sync with settings.json.") {
            SettingsRow(title: "~/.notchnull", subtitle: "settings.json, widgets/, presets/, themes/, backups/, status.json, bin/notchnull", symbol: "folder.fill", tint: Theme.Accent.clipboard) {
                Button("Open") { NSWorkspace.shared.open(NotchHome.root) }
                copyButton("path", NotchHome.root.path)
            }
            if settingsFile.errors.isEmpty {
                SettingsRow(title: "settings.json", subtitle: "Read without errors.", symbol: "checkmark.circle.fill", tint: Theme.Accent.success) {
                    Button("Reference") { NSWorkspace.shared.open(NotchHome.settingsReference) }
                }
            } else {
                ForEach(settingsFile.errors, id: \.self) { error in
                    SettingsRow(title: "settings.json", subtitle: error, symbol: "exclamationmark.triangle.fill", tint: Theme.Accent.danger) {
                        Button("Edit") { NSWorkspace.shared.open(NotchHome.settings) }
                    }
                }
            }
        }
        SettingsGroup(title: "Agent skill", footer: "The skill teaches an agent the widget format, every setting, the CLI, how to check its work with a rendered PNG, and how to change NotchNull's own source when files are not enough. Installing links it into the agent's skills folder; nothing else is touched.") {
            ForEach(NotchHome.Agent.allCases) { agent in
                let isLinked = linked.contains(agent)
                SettingsRow(
                    title: agent.title,
                    subtitle: isLinked ? "Installed at \(agent.link.path.replacingOccurrences(of: Constants.Paths.home.path, with: "~"))" : "Not installed.",
                    symbol: agent == .claude ? "sparkle" : "circle.hexagongrid.fill",
                    tint: agent == .claude ? Theme.Accent.claude : Theme.Accent.codex
                ) {
                    if isLinked {
                        Button("Remove") { unlink(agent) }
                    } else {
                        Button("Install") { link(agent) }
                    }
                }
            }
            if let linkError {
                SettingsRow(title: linkError, symbol: "exclamationmark.triangle.fill", tint: Theme.Accent.danger) { EmptyView() }
            }
            SettingsRow(title: "Try it", subtitle: "“\(Self.starterPrompt)”", symbol: "text.bubble.fill", tint: Theme.Accent.clipboard) {
                copyButton("prompt", Self.starterPrompt)
            }
        }
        SettingsGroup(title: "Command line", footer: "Scripts and agents can also call the local API on 127.0.0.1:\(Constants.Agents.eventServerPort) with the token in the X-NotchNull-Token header. It only listens on this Mac.") {
            SettingsRow(title: "notchnull", subtitle: Self.pathLine, symbol: "terminal.fill", tint: Theme.Accent.system) {
                copyButton("cli", Self.pathLine)
            }
            SettingsRow(title: "API token", subtitle: "Also in ~/.notchnull/token, readable only by you.", symbol: "key.fill", tint: Theme.Accent.warning) {
                copyButton("token", ClaudeHookInstaller.token())
            }
        }
        SettingsGroup(title: "Examples", footer: "Working widgets to start from. Adding one copies its file into ~/.notchnull/widgets, where you or your agent can change it. More examples, presets and looks live in ~/.notchnull/skill.") {
            ForEach(examples) { example in
                SettingsRow(
                    title: example.title,
                    subtitle: example.summary,
                    symbol: example.symbol ?? "square.dashed",
                    tint: WidgetStyle.color(example.tint) ?? Theme.Accent.clipboard
                ) {
                    if installed.contains(example.id) {
                        Label("Added", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.Accent.success)
                            .transition(.scale(scale: 0.25).combined(with: .opacity))
                    } else {
                        Button("Add") { add(example) }
                    }
                }
                .animation(Motion.state, value: installed)
            }
            if let exampleError {
                SettingsRow(title: exampleError, symbol: "exclamationmark.triangle.fill", tint: Theme.Accent.danger) { EmptyView() }
            }
        }
        SettingsGroup(title: "Your widgets") {
            if widgets.widgets.isEmpty {
                SettingsRow(title: "No widgets yet", subtitle: "Save a .json file in ~/.notchnull/widgets, or ask your agent.", symbol: "square.dashed", tint: Theme.Accent.system) {
                    Button("Open folder") { NSWorkspace.shared.open(NotchHome.widgets) }
                }
            }
            ForEach(widgets.widgets) { widget in
                SettingsRow(
                    title: widget.definition?.title ?? widget.file.lastPathComponent,
                    subtitle: status(of: widget),
                    symbol: widget.error == nil ? (widget.definition?.symbol ?? "square.dashed") : "exclamationmark.triangle.fill",
                    tint: widget.error == nil ? (WidgetStyle.color(widget.definition?.tint) ?? Theme.Accent.clipboard) : Theme.Accent.danger
                ) {
                    if widget.definition?.command != nil {
                        Button("Run") { widgets.run(widget.id) }
                    }
                    Button("Edit") { NSWorkspace.shared.open(widget.file) }
                }
            }
        }
        .onAppear {
            refreshLinks()
            installed = Set(examples.filter(\.isInstalled).map(\.id))
        }
    }

    private func add(_ example: ExampleWidget) {
        do {
            try Recipes.install(example)
            exampleError = nil
            installed.insert(example.id)
        } catch {
            exampleError = "Could not add \(example.title): \(error.localizedDescription)"
        }
    }

    private func status(of widget: LoadedWidget) -> String {
        switch widget.state {
        case .loading: return "Running its command…"
        case .failed(let message): return message
        case .ready(_, let date):
            guard widget.definition?.command != nil else { return "\(widget.file.lastPathComponent) · static" }
            return "\(widget.file.lastPathComponent) · updated \(date.formatted(.relative(presentation: .named)))"
        }
    }

    private func copyButton(_ id: String, _ text: String) -> some View {
        Button(copied == id ? "Copied" : "Copy") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            withAnimation(Motion.state) { copied = id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if copied == id { withAnimation(Motion.state) { copied = nil } }
            }
        }
        .frame(minWidth: 58)
    }

    private func refreshLinks() {
        linked = Set(NotchHome.Agent.allCases.filter(NotchHome.isSkillLinked(for:)))
    }

    private func link(_ agent: NotchHome.Agent) {
        do {
            try NotchHome.linkSkill(for: agent)
            linkError = nil
        } catch {
            linkError = "\(agent.link.path) already exists and is not NotchNull's. Move it away, then install again."
        }
        refreshLinks()
    }

    private func unlink(_ agent: NotchHome.Agent) {
        NotchHome.unlinkSkill(for: agent)
        refreshLinks()
    }
}
