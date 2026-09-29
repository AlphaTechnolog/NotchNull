import ServiceManagement
import SwiftUI

struct SettingsView: View {
    enum Section: String, CaseIterable, Identifiable {
        case style, motion, layout, general, activities, agents, files, permissions, about

        var id: String { rawValue }
        var title: String {
            switch self {
            case .style: "Style"
            case .motion: "Motion"
            case .layout: "Tabs & Wings"
            case .general: "General"
            case .activities: "Features"
            case .agents: "Claude & Codex"
            case .files: "Tray & Clipboard"
            case .permissions: "Permissions"
            case .about: "About"
            }
        }
        var symbol: String {
            switch self {
            case .style: "paintbrush.pointed.fill"
            case .motion: "wind"
            case .layout: "square.stack.3d.up.fill"
            case .general: "gearshape.fill"
            case .activities: "rectangle.topthird.inset.filled"
            case .agents: "sparkle"
            case .files: "tray.full.fill"
            case .permissions: "lock.shield.fill"
            case .about: "info.circle.fill"
            }
        }
        var tint: Color {
            switch self {
            case .style: Theme.Accent.mirror
            case .motion: Theme.Accent.awake
            case .layout: Theme.Accent.codex
            case .general: Theme.Accent.system
            case .activities: Theme.Accent.music
            case .agents: Theme.Accent.claude
            case .files: Theme.Accent.tray
            case .permissions: Theme.Accent.warning
            case .about: Theme.Accent.airdrop
            }
        }
    }

    @State private var section: Section = .style
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().opacity(0.4)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(section.title)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .padding(.top, 34)
                    content
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(section)
                .transition(.notchContent)
            }
            .animation(Motion.state, value: section)
        }
        .frame(minWidth: 720, minHeight: 520)
        .background(Color(hex: 0x111214))
        .preferredColorScheme(.dark)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.black)
                    .overlay(
                        NotchShape(topRadius: 3, bottomRadius: 6)
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 16, height: 7)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .padding(.top, 5)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.white.opacity(0.12)))
                    .frame(width: 26, height: 26)
                Text(Constants.appName)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.top, 40)
            .padding(.bottom, 10)

            ForEach(Section.allCases) { item in
                let selected = item == section
                Button {
                    withAnimation(Motion.state) { section = item }
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(item.tint))
                        Text(item.title)
                            .font(.system(size: 13, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 30)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Theme.Palette.surfaceHover)
                                .matchedGeometryEffect(id: "selection", in: selection)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle(hoverFill: Theme.Palette.surface, cornerRadius: 8, padding: EdgeInsets()))
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(width: 210)
        .background(Color(hex: 0x0B0B0D))
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .style: StyleSettings()
        case .motion: MotionSettings()
        case .layout: LayoutSettings()
        case .general: GeneralSettings()
        case .activities: ActivitiesSettings()
        case .agents: AgentSettings()
        case .files: FileSettings()
        case .permissions: PermissionSettings()
        case .about: AboutSettings()
        }
    }
}

// MARK: Building blocks

struct SettingsGroup<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .padding(.leading, 4)
            }
            VStack(spacing: 0) { content }
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.Palette.hairline))
            if let footer {
                Text(footer)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    var tint: Color = Theme.Accent.system
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(tint.opacity(0.16)))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13)).foregroundStyle(Theme.Palette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.Palette.hairline).frame(height: 1).padding(.leading, symbol == nil ? 12 : 46)
        }
    }
}

struct SettingsToggle: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    var tint: Color = Theme.Accent.system
    @Binding var isOn: Bool

    var body: some View {
        SettingsRow(title: title, subtitle: subtitle, symbol: symbol, tint: tint) {
            Toggle("", isOn: $isOn.animation(Motion.state))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .tint(tint)
        }
    }
}

// MARK: Sections

private struct GeneralSettings: View {
    @EnvironmentObject private var preferences: Preferences
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        SettingsGroup(title: "Behavior") {
            SettingsRow(title: "Open the notch on", symbol: "cursorarrow.motionlines", tint: Theme.Accent.airdrop) {
                Picker("", selection: $preferences.openTrigger) {
                    ForEach(Preferences.OpenTrigger.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 150)
            }
            SettingsRow(title: "Show on", symbol: "display", tint: Theme.Accent.system) {
                Picker("", selection: $preferences.displayMode) {
                    ForEach(Preferences.DisplayMode.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .frame(width: 170)
            }
            SettingsToggle(title: "Haptic tap when opening", subtitle: "On Force Touch trackpads.", symbol: "hand.tap.fill", tint: Theme.Accent.tray, isOn: $preferences.haptics)
            SettingsToggle(title: "Launch at login", symbol: "power", tint: Theme.Accent.success, isOn: Binding(
                get: { launchAtLogin },
                set: { setLaunchAtLogin($0) }
            ))
        }
        if let loginError {
            Text(loginError).font(.system(size: 11)).foregroundStyle(Theme.Accent.danger)
        }
        SettingsGroup(title: "Extras") {
            SettingsToggle(title: "Sounds", subtitle: "Timer chime and meeting reminder.", symbol: "speaker.wave.2.fill", tint: Theme.Accent.volumeHigh, isOn: $preferences.sounds)
            SettingsToggle(title: "Say hello", subtitle: "Handwritten hello at launch and when you unlock.", symbol: "hand.wave.fill", tint: Theme.Accent.mirror, isOn: $preferences.sayHello)
            SettingsToggle(title: "Menu bar icon", symbol: "menubar.rectangle", tint: Theme.Accent.system, isOn: $preferences.showMenuBarIcon)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Launch at login needs the app to be in /Applications: \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

private struct ActivitiesSettings: View {
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var levels: LevelsService

    var body: some View {
        SettingsGroup(title: "Media") {
            SettingsToggle(title: "Now playing", subtitle: "Apple Music and Spotify.", symbol: "music.note", tint: Theme.Accent.music, isOn: $preferences.musicEnabled)
            SettingsToggle(title: "Album art and beat beside the notch", symbol: "waveform", tint: Theme.Accent.music, isOn: $preferences.musicWings)
            SettingsToggle(title: "Volume and brightness HUD", symbol: "speaker.wave.3.fill", tint: Theme.Accent.volumeHigh, isOn: $preferences.hudEnabled)
            SettingsToggle(
                title: "Replace the system HUD",
                subtitle: levels.keyTapActive ? "Media keys are handled by NotchNull." : "Needs Accessibility so the media keys can be handled here instead.",
                symbol: "keyboard",
                tint: Theme.Accent.volumeHigh,
                isOn: Binding(get: { preferences.replaceSystemHUD }, set: { enabled in
                    preferences.replaceSystemHUD = enabled
                    if enabled && !Permissions.accessibilityGranted { Permissions.requestAccessibility() }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { levels.retryKeyTap() }
                })
            )
        }
        SettingsGroup(title: "System") {
            SettingsToggle(title: "Charging and low battery", symbol: "bolt.fill", tint: Theme.Accent.battery, isOn: $preferences.batteryEnabled)
            SettingsToggle(title: "Devices and connections", symbol: "cable.connector", tint: Color.white, isOn: $preferences.accessoriesEnabled)
            SettingsToggle(title: "Downloads", subtitle: "Progress and speed from ~/Downloads.", symbol: "arrow.down.circle.fill", tint: Theme.Accent.download, isOn: $preferences.downloadsEnabled)
            SettingsToggle(title: "Screenshots", subtitle: "New screenshots wait in the Tray.", symbol: "camera.viewfinder", tint: Theme.Accent.tray, isOn: $preferences.screenshotsEnabled)
            SettingsToggle(title: "Meetings", subtitle: "Countdown and Join five minutes before events with a call link.", symbol: "video.fill", tint: Theme.Accent.calendar, isOn: $preferences.calendarEnabled)
            SettingsToggle(title: "CPU and memory", symbol: "cpu", tint: Theme.Accent.codex, isOn: $preferences.statsEnabled)
            SettingsToggle(title: "Camera mirror", subtitle: "Off by default. Adds a Mirror tab; the camera only runs while that tab is open.", symbol: "web.camera.fill", tint: Theme.Accent.mirror, isOn: $preferences.mirrorEnabled)
        }
    }
}

private struct AgentSettings: View {
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var agents: AgentHub
    @EnvironmentObject private var claudeUsage: ClaudeUsageService

    var body: some View {
        SettingsGroup(title: "Claude Code", footer: "Limits come from the same endpoint as Claude Code's /usage, using the sign-in Claude Code already stored in your keychain. NotchNull never refreshes or copies that token.") {
            SettingsToggle(title: "Show Claude usage limits", symbol: "gauge.with.dots.needle.33percent", tint: Theme.Accent.claude, isOn: $preferences.claudeUsageEnabled)
            SettingsToggle(title: "Show what is left", subtitle: "Limits read like a battery: 59% left instead of 41% used.", symbol: "battery.75percent", tint: Theme.Accent.claude, isOn: $preferences.usageShowsRemaining)
            SettingsToggle(title: "Pace warnings", subtitle: "When your current pace would use a limit up before it resets, show both rates: how fast you are going and how much per day lasts until the reset.", symbol: "speedometer", tint: Theme.Accent.warning, isOn: $preferences.paceWarnings)
            SettingsRow(
                title: "Session hooks",
                subtitle: agents.hooksInstalled
                    ? "Connected. Approvals, finished runs and running time reach the notch."
                    : "Adds a small hook to ~/.claude/settings.json. Your existing hooks stay; a backup is saved next to it.",
                symbol: "link",
                tint: Theme.Accent.claude
            ) {
                if agents.hooksInstalled {
                    Button("Disconnect") { agents.uninstallHooks() }
                } else {
                    Button("Connect") { agents.installHooks() }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Accent.claude)
                }
            }
            if let error = agents.hookError {
                SettingsRow(title: error, symbol: "exclamationmark.triangle.fill", tint: Theme.Accent.danger) { EmptyView() }
            }
        }
        SettingsGroup(title: "Codex", footer: "Codex state is read from ~/.codex/sessions. Your Codex notify command is left untouched.") {
            SettingsToggle(title: "Watch Codex sessions and limits", symbol: "circle.hexagongrid.fill", tint: Theme.Accent.codex, isOn: $preferences.codexEnabled)
        }
        SettingsGroup(title: "Notch") {
            SettingsToggle(title: "Agent sessions", subtitle: "Needs-you alerts, running timers and done banners.", symbol: "bell.badge.fill", tint: Theme.Accent.needsYou, isOn: $preferences.agentsEnabled)
            SettingsToggle(title: "Show running time beside the notch", symbol: "timer", tint: Theme.Accent.claude, isOn: $preferences.agentWings)
        }
    }
}

private struct FileSettings: View {
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var tray: TrayStore
    @EnvironmentObject private var clipboard: ClipboardService

    var body: some View {
        SettingsGroup(title: "Tray") {
            SettingsToggle(title: "File Tray and drop targets", subtitle: "Drag files to the notch to keep, copy or AirDrop them.", symbol: "tray.full.fill", tint: Theme.Accent.tray, isOn: $preferences.trayEnabled)
            SettingsRow(title: "\(tray.items.count) items in the Tray", symbol: "folder.fill", tint: Theme.Accent.tray) {
                Button("Show folder") { NSWorkspace.shared.open(Constants.Paths.tray) }
                Button("Clear") { tray.clear() }.disabled(tray.items.isEmpty)
            }
        }
        SettingsGroup(title: "Clipboard", footer: "History stays on this Mac, sealed with AES-GCM using a key readable only by your user account. Items marked concealed by password managers are never recorded.") {
            SettingsToggle(title: "Clipboard history", symbol: "list.clipboard.fill", tint: Theme.Accent.clipboard, isOn: $preferences.clipboardEnabled)
            SettingsRow(
                title: "Open with shortcut",
                subtitle: "From any app. Type to search, arrows to move, Return to paste, ⌘Return to copy only, Esc to close. Pasting needs Accessibility; without it Return copies.",
                symbol: "command",
                tint: Theme.Accent.clipboard
            ) {
                ShortcutRecorder(shortcut: $preferences.clipboardShortcut)
            }
            .disabled(!preferences.clipboardEnabled)
            SettingsRow(title: "\(clipboard.items.count) items saved", symbol: "lock.fill", tint: Theme.Accent.clipboard) {
                Button("Clear unpinned") { clipboard.clearUnpinned() }.disabled(clipboard.items.isEmpty)
            }
        }
    }
}

private struct PermissionSettings: View {
    @EnvironmentObject private var calendar: CalendarService
    @EnvironmentObject private var mirror: MirrorService
    @State private var accessibility = Permissions.accessibilityGranted
    private let refresh = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        SettingsGroup(footer: "Each permission is optional; the feature that needs it explains itself where it lives.") {
            PermissionRow(title: "Accessibility", detail: "Replace the system volume and brightness HUD, and paste from the Clipboard shortcut.", symbol: "keyboard", granted: accessibility) {
                Permissions.requestAccessibility()
                Permissions.open(.accessibility)
            }
            PermissionRow(title: "Calendars", detail: "Up next and meeting countdowns.", symbol: "calendar", granted: calendar.access == .fullAccess) {
                calendar.access == .notDetermined ? calendar.requestAccess() : Permissions.open(.calendars)
            }
            PermissionRow(title: "Camera", detail: "Mirror tab only, only while visible.", symbol: "web.camera.fill", granted: mirror.authorization == .authorized) {
                Permissions.open(.camera)
            }
            PermissionRow(title: "Automation", detail: "Control Music and Spotify.", symbol: "music.note", granted: nil) {
                Permissions.open(.automation)
            }
            PermissionRow(title: "Bluetooth", detail: "AirPods battery when they connect.", symbol: "airpodspro", granted: nil) {
                Permissions.open(.bluetooth)
            }
        }
        .onReceive(refresh) { _ in accessibility = Permissions.accessibilityGranted }
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let symbol: String
    let granted: Bool?
    let action: () -> Void

    var body: some View {
        SettingsRow(title: title, subtitle: detail, symbol: symbol, tint: granted == true ? Theme.Accent.success : Theme.Accent.warning) {
            if granted == true {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Accent.success)
                    .transition(.scale(scale: 0.25).combined(with: .opacity))
            } else {
                Button(granted == nil ? "Review" : "Allow", action: action)
            }
        }
        .animation(Motion.state, value: granted)
    }
}

private struct AboutSettings: View {
    var body: some View {
        SettingsGroup {
            SettingsRow(title: Constants.appName, subtitle: "Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")", symbol: "rectangle.topthird.inset.filled", tint: .white) {
                EmptyView()
            }
            SettingsRow(title: "Logs", subtitle: "log stream --predicate 'subsystem == \"\(Constants.bundleIdentifier)\"'", symbol: "text.alignleft", tint: Theme.Accent.system) {
                EmptyView()
            }
        }
    }
}
