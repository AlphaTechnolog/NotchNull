import SwiftUI

/// Settings › About › Updates: where the app stands against the newest release, the button that
/// installs it, and where the copies of your files are.
struct UpdateSettings: View {
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var updates: UpdateService

    var body: some View {
        SettingsGroup(title: "Updates", footer: "An update replaces the app and nothing else: ~/.notchnull and your settings stay as they are. macOS asks for Accessibility again afterwards, because each NotchNull build is signed on its own rather than with an Apple developer certificate.") {
            SettingsRow(title: title, subtitle: subtitle, symbol: symbol, tint: tint) {
                controls
            }
            .animation(Motion.state, value: updates.state)
            SettingsToggle(
                title: "Check automatically",
                subtitle: "Asks GitHub once a day for the latest release. Nothing about you or this Mac is sent.",
                symbol: "clock.arrow.2.circlepath",
                tint: Theme.Accent.system,
                isOn: $preferences.checkForUpdates
            )
            SettingsRow(
                title: "Backups",
                subtitle: "Your settings, widgets, presets and looks are copied to ~/.notchnull/backups the first time a new version runs.",
                symbol: "clock.arrow.circlepath",
                tint: Theme.Accent.clipboard
            ) {
                Button("Open") {
                    try? FileManager.default.createDirectory(at: NotchBackup.root, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(NotchBackup.root)
                }
                .controlSize(.small)
            }
        }
    }

    private var title: String {
        switch updates.state {
        case .idle: "Check for a new version"
        case .checking: "Checking for a new version…"
        case .upToDate: "\(Constants.appName) is up to date"
        case .available(let release): "\(Constants.appName) \(release.version) is available"
        case .downloading(let release): "Downloading \(release.version)…"
        case .installing(let release): "Installing \(release.version)…"
        case .failed: "The update did not go through"
        }
    }

    /// A build run from source has no version to show.
    private var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    private var subtitle: String {
        switch updates.state {
        case .available(let release) where release.asset == nil:
            "You have \(current). This release has to be downloaded by hand."
        case .available, .downloading:
            "You have \(current)."
        case .installing:
            "\(Constants.appName) restarts when it is done."
        case .failed(let message):
            message
        case .idle, .checking, .upToDate:
            updates.lastChecked.map { "Version \(current) · checked \($0.formatted(.relative(presentation: .named)))" } ?? "Version \(current) · not checked yet"
        }
    }

    private var symbol: String {
        switch updates.state {
        case .available, .downloading, .installing: "arrow.down.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .idle, .checking: "arrow.triangle.2.circlepath"
        case .upToDate: "checkmark.circle.fill"
        }
    }

    private var tint: Color {
        switch updates.state {
        case .available, .downloading, .installing: preferences.accent
        case .failed: Theme.Accent.danger
        case .idle, .checking: Theme.Accent.system
        case .upToDate: Theme.Accent.success
        }
    }

    @ViewBuilder private var controls: some View {
        switch updates.state {
        case .checking, .downloading, .installing:
            ProgressView().controlSize(.small)
        case .available(let release):
            Button("What's new") { NSWorkspace.shared.open(release.page) }
                .controlSize(.small)
            if release.asset == nil {
                Button("Download") { NSWorkspace.shared.open(release.page) }
                    .controlSize(.small)
            } else {
                Button("Update") { Task { await updates.install() } }
                    .controlSize(.small)
            }
        case .failed:
            Button("Releases") { NSWorkspace.shared.open(Constants.Links.releases) }
                .controlSize(.small)
            Button("Try again") { Task { await updates.check() } }
                .controlSize(.small)
        case .idle, .upToDate:
            Button("Check") { Task { await updates.check() } }
                .controlSize(.small)
        }
    }
}
