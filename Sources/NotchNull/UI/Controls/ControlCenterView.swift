import SwiftUI

/// The Controls tab: toggles, volume and brightness, output picker and, when there is room,
/// the recent feed. A short panel gets one combined slider card.
struct ControlCenterView: View {
    @EnvironmentObject private var controls: ControlCenterService
    @EnvironmentObject private var keepAwake: KeepAwakeService
    @EnvironmentObject private var levels: LevelsService
    @EnvironmentObject private var preferences: Preferences
    @State private var showOutputs = false
    @State private var brightness = Double(DisplayBrightness.brightness() ?? 0.5)

    private var roomy: Bool { preferences.panelHeight >= 200 }
    /// Wide tiles need about 620 pt; narrower panels use the round-button grid.
    private var wide: Bool { preferences.panelWidth >= 620 }

    /// Six round toggles with their names underneath, like a compact Control Center.
    private var compactToggles: some View {
        let columns = Array(repeating: GridItem(.fixed(58), spacing: 6), count: 3)
        let rowSpacing: CGFloat = preferences.panelHeight >= 168 ? 14 : 6
        return LazyVGrid(columns: columns, spacing: rowSpacing) {
            RoundToggle(symbol: controls.wifiOn ? "wifi" : "wifi.slash", title: controls.wifiName ?? "Wi-Fi", isOn: controls.wifiOn, action: controls.toggleWifi)
            RoundToggle(symbol: "wave.3.right", title: "Bluetooth", isOn: controls.bluetoothOn, action: controls.toggleBluetooth)
            RoundToggle(symbol: "cup.and.saucer.fill", title: "Awake", isOn: keepAwake.isActive, action: keepAwake.toggle)
            RoundToggle(symbol: "circle.lefthalf.filled", title: "Dark", isOn: controls.darkMode, action: controls.toggleDarkMode)
            RoundToggle(symbol: "lock.fill", title: "Lock", isOn: false, action: controls.lockScreen)
            RoundToggle(symbol: "moon.zzz.fill", title: "Sleep", isOn: false, action: controls.sleepDisplay)
        }
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity, alignment: .center)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.surface, style: .continuous).fill(Theme.Palette.surface))
        .fixedSize(horizontal: true, vertical: false)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Group {
                if wide {
                    VStack(spacing: 8) {
                        toggles
                        if roomy { RecentFeed().transition(.opacity) }
                    }
                    .frame(width: min(340, (preferences.panelWidth - 2 * Theme.Radius.panelPadding) * 0.56))
                } else {
                    compactToggles
                }
            }
            .condense(delay: Motion.stagger(1))
            Group {
                if roomy {
                    VStack(spacing: 8) {
                        soundCard
                        displayCard
                    }
                } else {
                    slidersCard
                }
            }
            .condense(delay: Motion.stagger(2))
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottom) {
            if let error = controls.lastError {
                Text(error)
                    .font(Theme.Typeface.caption)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.Accent.warning))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 6)
            }
        }
        .onAppear {
            controls.setVisible(true)
            brightness = Double(DisplayBrightness.brightness() ?? Float(brightness))
        }
        .onDisappear { controls.setVisible(false) }
    }

    private var toggles: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ControlTile(
                    symbol: controls.wifiOn ? "wifi" : "wifi.slash", title: "Wi-Fi",
                    subtitle: controls.wifiOn ? (controls.wifiName ?? "On") : "Off",
                    isOn: controls.wifiOn, action: controls.toggleWifi
                )
                .contextMenu { Button("Wi-Fi Settings…") { controls.openSettings("com.apple.wifi-settings-extension") } }
                ControlTile(
                    symbol: "cup.and.saucer.fill", title: "Keep Awake",
                    subtitle: keepAwake.isActive ? (keepAwake.endsAt.map { Formatting.countdown(to: $0) } ?? "On") : "Off",
                    isOn: keepAwake.isActive, action: keepAwake.toggle
                )
                RoundControl(symbol: "lock.fill", label: "Lock screen", action: controls.lockScreen)
            }
            HStack(spacing: 8) {
                ControlTile(
                    symbol: "wave.3.right", title: "Bluetooth",
                    subtitle: controls.bluetoothOn ? "On" : "Off",
                    isOn: controls.bluetoothOn, action: controls.toggleBluetooth
                )
                .contextMenu { Button("Bluetooth Settings…") { controls.openSettings("com.apple.BluetoothSettings") } }
                ControlTile(
                    symbol: "circle.lefthalf.filled", title: "Dark Mode",
                    subtitle: controls.darkMode ? "On" : "Off",
                    isOn: controls.darkMode, action: controls.toggleDarkMode
                )
                RoundControl(symbol: "moon.zzz.fill", label: "Sleep display", action: controls.sleepDisplay)
            }
        }
    }

    /// Volume and brightness together, for short panels. Each section shows its value and, for
    /// sound, the current output; the sections share the card's height so taller panels stay balanced.
    private var slidersCard: some View {
        let sliderHeight: CGFloat = preferences.panelHeight >= 168 ? 30 : 24
        return VStack(alignment: .leading, spacing: 0) {
            sliderHeader(title: "Sound", value: levels.outputVolume, detail: currentOutputName) { outputsMenu }
            BigSlider(
                value: Double(levels.outputVolume),
                symbol: levels.outputVolume <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill",
                tint: preferences.accent,
                label: "Volume",
                height: sliderHeight
            ) { levels.setVolume(Float($0)) }
            Spacer(minLength: 6)
            sliderHeader(title: "Display", value: Float(brightness), detail: nil) {
                IconButton(symbol: "display", size: 10, tint: Theme.Palette.textSecondary, label: "Display settings") {
                    controls.openSettings("com.apple.Displays-Settings.extension")
                }
            }
            BigSlider(value: brightness, symbol: "sun.max.fill", tint: preferences.accent, label: "Brightness", height: sliderHeight) { value in
                brightness = value
                DisplayBrightness.setBrightness(Float(value))
            }
            .disabled(DisplayBrightness.brightness() == nil && !Motion.isSnapshot)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.surface, style: .continuous).fill(Theme.Palette.surface))
    }

    private func sliderHeader<Accessory: View>(title: String, value: Float, detail: String?, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Text(title)
                .font(Theme.Typeface.label)
                .foregroundStyle(Theme.Palette.textSecondary)
            if let detail {
                Text(detail)
                    .font(Theme.Typeface.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
            Text("\(Int((value * 100).rounded()))%")
                .font(Theme.Typeface.caption.monospacedDigit())
                .foregroundStyle(Theme.Palette.textSecondary)
                .contentTransition(.numericText(value: Double(value)))
            accessory()
        }
        .frame(height: 22)
        .padding(.leading, 2)
        .padding(.bottom, 3)
    }

    private var currentOutputName: String? {
        controls.outputs.first { $0.id == controls.currentOutput }?.name
    }

    /// Output device picker as a native menu, so it fits in the compact card.
    @ViewBuilder
    private var outputsMenu: some View {
        if Motion.isSnapshot {
            Image(systemName: "airplayaudio")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(width: 24, height: 24)
        } else {
            menu
        }
    }

    private var menu: some View {
        Menu {
            ForEach(controls.outputs) { device in
                Button {
                    controls.selectOutput(device)
                } label: {
                    Label(device.name, systemImage: device.id == controls.currentOutput ? "checkmark" : device.symbol)
                }
            }
        } label: {
            Image(systemName: "airplayaudio")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Output device")
        .accessibilityLabel("Choose output device")
    }

    private var soundCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Sound")
                    .font(Theme.Typeface.bodyStrong)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Button {
                    withAnimation(Motion.state) { showOutputs.toggle() }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .rotationEffect(.degrees(showOutputs ? 90 : 0))
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Theme.Palette.surfaceHover))
                }
                .buttonStyle(PressableStyle(hoverFill: .clear, cornerRadius: 10, padding: EdgeInsets()))
                .accessibilityLabel(showOutputs ? "Hide outputs" : "Choose output")
            }
            BigSlider(
                value: Double(levels.outputVolume),
                symbol: levels.outputVolume <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill",
                tint: preferences.accent,
                label: "Volume"
            ) { levels.setVolume(Float($0)) }
            if showOutputs {
                VStack(spacing: 2) {
                    ForEach(controls.outputs) { device in
                        Button { controls.selectOutput(device) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: device.symbol)
                                    .font(.system(size: 11, weight: .semibold))
                                    .frame(width: 18)
                                Text(device.name)
                                    .font(Theme.Typeface.body)
                                    .lineLimit(1)
                                Spacer()
                                if device.id == controls.currentOutput {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(preferences.accent)
                                        .transition(.scale(scale: 0.25).combined(with: .opacity))
                                }
                            }
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .padding(.horizontal, 6)
                            .frame(height: 24)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle(cornerRadius: 8, padding: EdgeInsets()))
                    }
                }
                .transition(.opacity.combined(with: .offset(y: -4)))
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.Palette.surface))
    }

    private var displayCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Display")
                    .font(Theme.Typeface.bodyStrong)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Button {
                    controls.openSettings("com.apple.Displays-Settings.extension")
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Theme.Palette.surfaceHover))
                }
                .buttonStyle(PressableStyle(hoverFill: .clear, cornerRadius: 10, padding: EdgeInsets()))
                .accessibilityLabel("Display settings")
            }
            BigSlider(value: brightness, symbol: "sun.max.fill", tint: preferences.accent, label: "Brightness") { value in
                brightness = value
                DisplayBrightness.setBrightness(Float(value))
            }
            .disabled(DisplayBrightness.brightness() == nil && !Motion.isSnapshot)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.Palette.surface))
    }
}

/// Wide toggle: a circular icon that fills with the accent when on, title and state beside it.
struct ControlTile: View {
    let symbol: String
    let title: String
    let subtitle: String
    let isOn: Bool
    let action: () -> Void
    @EnvironmentObject private var preferences: Preferences

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isOn ? Color.black.opacity(0.85) : Theme.Palette.textPrimary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(isOn ? preferences.accent : Theme.Palette.surfaceActive))
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(Theme.Typeface.bodyStrong)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(Theme.Typeface.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                }
                Spacer(minLength: 0)
            }
            .padding(4)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Theme.Palette.surface))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle(hoverFill: .clear, cornerRadius: 20, padding: EdgeInsets()))
        .animation(Motion.state, value: isOn)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle)
    }
}

/// Circular toggle with its name below, for the compact controls grid.
struct RoundToggle: View {
    let symbol: String
    let title: String
    let isOn: Bool
    let action: () -> Void
    @EnvironmentObject private var preferences: Preferences

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isOn ? Color.black.opacity(0.85) : Theme.Palette.textPrimary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(isOn ? preferences.accent : Theme.Palette.surfaceActive))
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isOn ? Theme.Palette.textPrimary : Theme.Palette.textTertiary)
                    .lineLimit(1)
                    .frame(width: 58)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(hoverFill: .clear, cornerRadius: 10, padding: EdgeInsets()))
        .animation(Motion.state, value: isOn)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

struct RoundControl: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.Palette.surface))
        }
        .buttonStyle(PressableStyle(hoverFill: .clear, cornerRadius: 20, padding: EdgeInsets()))
        .accessibilityLabel(label)
        .help(label)
    }
}

/// Thick slider in the Control Center style: glyph inside the fill, drag anywhere.
struct BigSlider: View {
    var value: Double
    var symbol: String
    var tint: Color
    var label: String
    var height: CGFloat = 24
    let onChange: (Double) -> Void
    @State private var dragValue: Double?
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let shown = dragValue ?? value
        // Icon beside the bar, not inside it, so a low value is a short line instead of a blob.
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 16)
            GeometryReader { proxy in
                let width: CGFloat = proxy.size.width
                let bar: CGFloat = min(proxy.size.height, dragValue == nil ? 6 : 8)
                let knob: CGFloat = bar + 6
                let fill: CGFloat = width * CGFloat(shown)
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.track).frame(height: bar)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(0, fill), height: bar)
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                        .frame(width: knob, height: knob)
                        .offset(x: max(0, min(width - knob, fill - knob / 2)))
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let next = max(0, min(1, drag.location.x / max(1, proxy.size.width)))
                        dragValue = next
                        onChange(next)
                    }
                    .onEnded { _ in dragValue = nil }
                )
            }
        }
        .frame(height: height)
        .opacity(isEnabled ? 1 : 0.4)
        .animation(dragValue == nil ? Motion.value : nil, value: shown)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(shown * 100)) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(min(1, value + 0.0625))
            case .decrement: onChange(max(0, value - 0.0625))
            @unknown default: break
            }
        }
    }
}

/// NotchNull's own recent-events feed.
struct RecentFeed: View {
    @EnvironmentObject private var log: ActivityLog

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Recent")
                    .font(Theme.Typeface.label)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                if !log.entries.isEmpty {
                    Button("Clear") { log.clear() }
                        .buttonStyle(PressableStyle())
                        .font(Theme.Typeface.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            if log.entries.isEmpty {
                Text("Nothing yet. Finished agent runs, downloads and screenshots show up here.")
                    .font(Theme.Typeface.body)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                NotchScroll {
                    VStack(spacing: 2) {
                        ForEach(log.entries.prefix(12)) { entry in
                            Button { log.perform(entry) } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: entry.symbol)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(entry.tint)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(entry.tint.opacity(0.16)))
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(entry.title)
                                            .font(Theme.Typeface.bodyStrong)
                                            .foregroundStyle(Theme.Palette.textPrimary)
                                            .lineLimit(1)
                                        if let detail = entry.detail {
                                            Text(detail)
                                                .font(Theme.Typeface.caption)
                                                .foregroundStyle(Theme.Palette.textTertiary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer(minLength: 4)
                                    Text(Formatting.relative(entry.date))
                                        .font(Theme.Typeface.caption)
                                        .foregroundStyle(Theme.Palette.textTertiary)
                                }
                                .frame(height: 30)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PressableStyle(cornerRadius: 8, padding: EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)))
                            .transition(.notchContent)
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.Palette.surface))
    }
}

/// The Controls tab of the panel.
struct ControlsTab: View {
    var body: some View {
        ControlCenterView()
    }
}
