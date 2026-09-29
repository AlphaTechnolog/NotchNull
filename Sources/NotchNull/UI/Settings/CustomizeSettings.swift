import AppKit
import SwiftUI

// MARK: Style

struct StyleSettings: View {
    @EnvironmentObject private var preferences: Preferences

    private static let accentSwatches: [Int] = [0x3DDBB0, 0x5AC8FA, 0xA78BFA, 0xFF5E8A, 0xFF9F0A, 0xFFD60A, 0x30D158, 0xFFFFFF]
    private static let tintSwatches: [Int] = [0x1C1B22, 0x10213A, 0x2A1433, 0x1E2A1F, 0x2B1A12, 0x2A2A2E]

    var body: some View {
        SettingsGroup(title: "Size", footer: "The closed notch can only grow: nothing can be drawn over the camera housing, so its smallest width is the hardware notch.") {
            SizePreview()
                .frame(height: 118)
                .padding(12)
            SliderRow(title: "Notch width", symbol: "rectangle.topthird.inset.filled", tint: Theme.Accent.codex, value: $preferences.closedExtraWidth, range: Preferences.Limits.closedExtraWidth, step: 2, format: { $0 < 1 ? "Hardware" : "+\(Int($0)) pt" })
            SliderRow(title: "Wings and banners", symbol: "arrow.left.and.right.square", tint: Theme.Accent.codex, value: $preferences.activityWidthScale, range: Preferences.Limits.activityWidthScale, format: { "\(Int($0 * 100))%" })
            SliderRow(title: "Open panel width", symbol: "arrow.left.and.right", tint: Theme.Accent.codex, value: $preferences.panelWidth, range: Preferences.Limits.panelWidth, step: 10, format: { "\(Int($0)) pt" })
            SliderRow(title: "Open panel height", symbol: "arrow.up.and.down", tint: Theme.Accent.codex, value: $preferences.panelHeight, range: Preferences.Limits.panelHeight, step: 4, format: { "\(Int($0)) pt" })
            SliderRow(title: "Roundness", symbol: "app", tint: Theme.Accent.codex, value: $preferences.cornerScale, range: 0.6...1.3, format: { "\(Int($0 * 100))%" })
        }

        SettingsGroup(title: "Body", footer: "Glass uses Liquid Glass on macOS 26 and later, vibrancy before that. The top edge always stays black so it blends with the camera housing.") {
            SettingsRow(title: "Material", symbol: "square.fill.on.square.fill", tint: Theme.Accent.airdrop) {
                Picker("", selection: $preferences.bodyStyle.animation(Motion.state)) {
                    ForEach(Preferences.BodyStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 210)
            }
            if preferences.bodyStyle == .tinted {
                SettingsRow(title: "Tint", symbol: "drop.fill", tint: preferences.tint == .black ? .white : preferences.tint) {
                    SwatchRow(values: Self.tintSwatches, selection: $preferences.tintHex)
                    ColorPicker("", selection: hexBinding(\.tintHex), supportsOpacity: false).labelsHidden()
                }
                .transition(.opacity.combined(with: .offset(y: -4)))
            }
            SliderRow(title: "Opacity", symbol: "circle.dotted", tint: Theme.Accent.system, value: $preferences.bodyOpacity, range: 0.55...1, format: { "\(Int($0 * 100))%" })
            SettingsToggle(title: "Shadow when open", symbol: "shadow", tint: Theme.Accent.system, isOn: $preferences.shadow)
            SettingsToggle(title: "Emission edge", subtitle: "Soft light along the edge tinted by what is playing or happening.", symbol: "light.max", tint: Theme.Accent.warning, isOn: $preferences.emissionEdge)
            if preferences.emissionEdge {
                SliderRow(title: "Edge intensity", symbol: "sun.min.fill", tint: Theme.Accent.warning, value: $preferences.emissionIntensity, range: 0.2...1, format: { "\(Int($0 * 100))%" })
                    .transition(.opacity.combined(with: .offset(y: -4)))
            }
            SettingsToggle(title: "Glow when an agent needs you", subtitle: "A light runs around the outline until you answer.", symbol: "sparkles", tint: Theme.Accent.needsYou, isOn: $preferences.glowNeedsYou)
            SettingsToggle(title: "Hide the hardware notch", subtitle: "Paints the menu bar black so the camera housing disappears into it.", symbol: "menubar.rectangle", tint: .white, isOn: $preferences.hideNotch)
        }

        SettingsGroup(title: "Accent", footer: "Used for the selected tab, toggles and sliders.") {
            SettingsRow(title: "Accent color", symbol: "paintpalette.fill", tint: preferences.accent) {
                SwatchRow(values: Self.accentSwatches, selection: $preferences.accentHex)
                ColorPicker("", selection: hexBinding(\.accentHex), supportsOpacity: false).labelsHidden()
            }
        }

        HStack {
            Spacer()
            Button("Reset look, size and motion") { preferences.resetCustomization() }
        }
    }

    private func hexBinding(_ keyPath: ReferenceWritableKeyPath<Preferences, Int>) -> Binding<Color> {
        Binding(
            get: { Color(hex: UInt32(preferences[keyPath: keyPath])) },
            set: { color in
                guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
                let value = (Int(rgb.redComponent * 255) << 16) | (Int(rgb.greenComponent * 255) << 8) | Int(rgb.blueComponent * 255)
                preferences[keyPath: keyPath] = value
            }
        )
    }
}

/// To-scale sketch of the closed notch and the open panel, updating as the sliders move.
private struct SizePreview: View {
    @EnvironmentObject private var preferences: Preferences
    private let hardware = CGSize(width: 185, height: 32)

    var body: some View {
        GeometryReader { proxy in
            let scale = min(1, (proxy.size.width - 24) / 780)
            let closed = CGSize(width: (hardware.width + preferences.closedExtraWidth) * scale, height: hardware.height * scale)
            let open = CGSize(width: max(preferences.panelWidth, hardware.width + preferences.closedExtraWidth + 120) * scale,
                              height: (hardware.height + preferences.panelHeight) * scale)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0x2B3A55), Color(hex: 0x4A2C4F)], startPoint: .topLeading, endPoint: .bottomTrailing))
                NotchShape(topRadius: 8 * scale, bottomRadius: 32 * scale * preferences.cornerScale)
                    .fill(Color.black.opacity(0.35))
                    .overlay(NotchShape(topRadius: 8 * scale, bottomRadius: 32 * scale * preferences.cornerScale).stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                    .frame(width: open.width, height: open.height)
                NotchShape(topRadius: 4 * scale, bottomRadius: 12 * scale)
                    .fill(Color.black)
                    .frame(width: closed.width, height: closed.height)
                RoundedRectangle(cornerRadius: 3 * scale, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .frame(width: hardware.width * scale, height: hardware.height * scale)
                    .help("Camera housing")
            }
            .animation(Motion.value, value: preferences.panelWidth)
            .animation(Motion.value, value: preferences.panelHeight)
            .animation(Motion.value, value: preferences.closedExtraWidth)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityLabel("Size preview")
    }
}

private struct SwatchRow: View {
    let values: [Int]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(values, id: \.self) { value in
                Button {
                    withAnimation(Motion.state) { selection = value }
                } label: {
                    Circle()
                        .fill(Color(hex: UInt32(value)))
                        .frame(width: 16, height: 16)
                        .overlay(Circle().strokeBorder(.white.opacity(selection == value ? 0.9 : 0.15), lineWidth: selection == value ? 2 : 1))
                        .scaleEffect(selection == value ? 1.12 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(format: "#%06X", value))
            }
        }
    }
}

// MARK: Motion

struct MotionSettings: View {
    @EnvironmentObject private var preferences: Preferences

    var body: some View {
        SettingsGroup(title: "Preview", footer: "Hover the preview to open it with your current settings.") {
            MotionPreview()
                .frame(height: 150)
                .padding(12)
        }
        SettingsGroup(title: "Presets") {
            HStack(spacing: 8) {
                ForEach(Preferences.MotionPreset.allCases) { preset in
                    let active = abs(preferences.animationSpeed - preset.values.speed) < 0.01 && abs(preferences.bounce - preset.values.bounce) < 0.01
                    Button(preset.title) { preferences.apply(preset) }
                        .buttonStyle(.bordered)
                        .tint(active ? preferences.accent : nil)
                }
                Spacer()
            }
            .padding(12)
        }
        SettingsGroup(title: "Tuning", footer: "Closing is always a little faster than opening and never overshoots. Reduce Motion in System Settings replaces movement with fades.") {
            SliderRow(title: "Speed", symbol: "hare.fill", tint: Theme.Accent.awake, value: $preferences.animationSpeed, range: 0.5...2, format: { $0 >= 1.99 ? "Instant" : String(format: "%.2g×", $0) })
            SliderRow(title: "Bounce", symbol: "arrow.up.and.down.and.sparkles", tint: Theme.Accent.awake, value: $preferences.bounce, range: 0...0.4, format: { "\(Int($0 * 100))%" })
            SliderRow(title: "Hover delay", symbol: "cursorarrow.and.square.on.square.dashed", tint: Theme.Accent.awake, value: $preferences.hoverDelay, range: 0...0.5, step: 0.01, format: { "\(Int($0 * 1000)) ms" })
            SliderRow(title: "Close delay", symbol: "clock.arrow.circlepath", tint: Theme.Accent.awake, value: $preferences.closeDelay, range: 0.05...1.2, step: 0.05, format: { "\(Int($0 * 1000)) ms" })
            SettingsToggle(title: "Cascade content", subtitle: "Rows arrive one after another instead of all at once.", symbol: "text.line.first.and.arrowtriangle.forward", tint: Theme.Accent.awake, isOn: $preferences.staggerContent)
            SettingsRow(title: "Open the notch on", symbol: "cursorarrow.motionlines", tint: Theme.Accent.airdrop) {
                Picker("", selection: $preferences.openTrigger) {
                    ForEach(Preferences.OpenTrigger.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 150)
            }
        }
    }
}

/// A miniature notch that opens on hover with the live motion settings.
private struct MotionPreview: View {
    @EnvironmentObject private var preferences: Preferences
    @State private var open = false
    @State private var closeWork: DispatchWorkItem?

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x2B3A55), Color(hex: 0x4A2C4F)], startPoint: .topLeading, endPoint: .bottomTrailing))
            BodyFill(shape: AnyShape(NotchShape(topRadius: open ? 10 : 4, bottomRadius: open ? 22 : 8)), expanded: open)
                .frame(width: open ? 300 : 110, height: open ? 104 : 18)
                .overlay(alignment: .top) { previewContent.padding(.top, 22) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering in
            closeWork?.cancel()
            let work = DispatchWorkItem {
                withAnimation(hovering ? Motion.open : Motion.close) { open = hovering }
            }
            closeWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + (hovering ? Motion.hoverOpenDelay : Motion.hoverCloseDelay), execute: work)
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        if open {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(index == 0 ? preferences.accent.opacity(0.8) : Theme.Palette.surfaceHover)
                        .frame(width: 80, height: 58)
                        .condense(delay: Motion.stagger(index + 1))
                }
            }
            .transition(.notchContent)
        }
    }
}

// MARK: Tabs & wings

struct LayoutSettings: View {
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var activities: ActivityCenter

    var body: some View {
        SettingsGroup(title: "Panel tabs", footer: "Order and visibility of the tabs in the open panel.") {
            ForEach(Array(preferences.allTabsOrdered.enumerated()), id: \.element) { index, tab in
                SettingsRow(title: tab.title, subtitle: preferences.isFeatureEnabled(tab) ? nil : "Feature is off", symbol: tab.symbol, tint: preferences.accent) {
                    Button { preferences.moveTab(tab, by: -1) } label: { Image(systemName: "chevron.up") }
                        .buttonStyle(.borderless)
                        .disabled(index == 0)
                        .accessibilityLabel("Move \(tab.title) up")
                    Button { preferences.moveTab(tab, by: 1) } label: { Image(systemName: "chevron.down") }
                        .buttonStyle(.borderless)
                        .disabled(index == preferences.allTabsOrdered.count - 1)
                        .accessibilityLabel("Move \(tab.title) down")
                    Toggle("", isOn: Binding(
                        get: { !preferences.hiddenTabs.contains(tab.rawValue) },
                        set: { visible in
                            withAnimation(Motion.state) {
                                if visible { preferences.hiddenTabs.remove(tab.rawValue) } else if tab != .home { preferences.hiddenTabs.insert(tab.rawValue) }
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .disabled(tab == .home)
                }
            }
        }
        SettingsGroup(title: "Home rows", footer: "The quick list beside the music player. Fewer rows fit a shorter panel.") {
            ForEach(Preferences.HomeRow.allCases) { row in
                SettingsToggle(
                    title: row.title,
                    isOn: Binding(
                        get: { preferences.homeRows.contains(row.rawValue) },
                        set: { preferences.setHomeRow(row, visible: $0) }
                    )
                )
            }
        }
        SettingsGroup(title: "What slides out", footer: "Turn off any live activity you do not want to see beside the notch.") {
            ForEach(ActivityKind.allCases, id: \.self) { kind in
                SettingsToggle(
                    title: kind.title,
                    isOn: Binding(
                        get: { preferences.isActivityEnabled(kind) },
                        set: { enabled in
                            preferences.setActivity(kind, enabled: enabled)
                            activities.refresh()
                        }
                    )
                )
            }
        }
    }
}

// MARK: Shared rows

struct SliderRow: View {
    let title: String
    var symbol: String?
    var tint: Color = Theme.Accent.system
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double?
    let format: (Double) -> String

    var body: some View {
        SettingsRow(title: title, symbol: symbol, tint: tint) {
            Group {
                if let step {
                    Slider(value: $value, in: range, step: step)
                } else {
                    Slider(value: $value, in: range)
                }
            }
            .controlSize(.small)
            .frame(width: 180)
            .tint(tint)
            Text(format(value))
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(width: 64, alignment: .trailing)
        }
    }
}
