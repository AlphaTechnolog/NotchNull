import SwiftUI

/// The island's right satellite, grown into a small Control Center: four toggle tiles,
/// a battery module and two full-height sliders whose fill is clipped to their shape.
struct IslandControlsCard: View {
    @EnvironmentObject private var controls: ControlCenterService
    @EnvironmentObject private var keepAwake: KeepAwakeService
    @EnvironmentObject private var levels: LevelsService
    @EnvironmentObject private var battery: BatteryService
    @EnvironmentObject private var preferences: Preferences
    @State private var brightness = Double(DisplayBrightness.brightness() ?? 0.5)

    private let spacing: CGFloat = 8

    var body: some View {
        HStack(spacing: spacing) {
            Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                GridRow {
                    ToggleTile(symbol: controls.wifiOn ? "wifi" : "wifi.slash", title: "Wi-Fi",
                               detail: controls.wifiOn ? (controls.wifiName ?? "On") : "Off",
                               isOn: controls.wifiOn, tint: preferences.accent, action: controls.toggleWifi)
                    ToggleTile(symbol: "wave.3.right", title: "Bluetooth", detail: controls.bluetoothOn ? "On" : "Off",
                               isOn: controls.bluetoothOn, tint: preferences.accent, action: controls.toggleBluetooth)
                }
                GridRow {
                    ToggleTile(symbol: "cup.and.saucer.fill", title: "Awake",
                               detail: keepAwake.isActive ? (keepAwake.endsAt.map { Formatting.countdown(to: $0) } ?? "On") : "Off",
                               isOn: keepAwake.isActive, tint: Theme.Accent.awake, action: keepAwake.toggle)
                    ToggleTile(symbol: "circle.lefthalf.filled", title: "Dark", detail: controls.darkMode ? "On" : "Off",
                               isOn: controls.darkMode, tint: preferences.accent, action: controls.toggleDarkMode)
                }
            }
            .frame(width: 196)
            BatteryModule(state: battery.state)
                .frame(width: 100)
            VerticalSlider(
                value: Double(levels.outputVolume),
                symbol: levels.outputVolume <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill",
                tint: preferences.accent, label: "Volume"
            ) { levels.setVolume(Float($0)) }
            .contextMenu {
                ForEach(controls.outputs) { device in
                    Button {
                        controls.selectOutput(device)
                    } label: {
                        Label(device.name, systemImage: device.id == controls.currentOutput ? "checkmark" : device.symbol)
                    }
                }
            }
            VerticalSlider(value: brightness, symbol: "sun.max.fill", tint: Theme.Accent.brightness, label: "Brightness") { value in
                brightness = value
                DisplayBrightness.setBrightness(Float(value))
            }
            .disabled(DisplayBrightness.brightness() == nil && !Motion.isSnapshot)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            controls.setVisible(true)
            brightness = Double(DisplayBrightness.brightness() ?? Float(brightness))
        }
        .onDisappear { controls.setVisible(false) }
    }
}

private struct ToggleTile: View {
    let symbol: String
    let title: String
    let detail: String
    let isOn: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isOn ? Color.black : Theme.Palette.textPrimary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(isOn ? tint : Theme.Palette.surfaceActive))
                    .contentTransition(.symbolEffect(.replace))
                Spacer(minLength: 2)
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.Palette.surface))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(Motion.state, value: isOn)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

private struct BatteryModule: View {
    let state: BatteryState

    private var status: String {
        if !state.hasBattery { return "No battery" }
        if state.isCharged { return "Charged" }
        if state.isCharging { return state.minutesToFull.map { "\(Formatting.minutes($0)) to full" } ?? "Charging" }
        if state.isPluggedIn { return "On power" }
        return state.minutesToEmpty.map { "\(Formatting.minutes($0)) left" } ?? "On battery"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: state.isPluggedIn ? "bolt.fill" : "battery.75percent")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(state.chargeTint)
                Text("Battery")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer(minLength: 4)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(state.percent)")
                    .font(.system(size: 30, weight: .light, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText(value: Double(state.percent)))
                Text("%")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .foregroundStyle(Theme.Palette.textPrimary)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.track)
                    Capsule().fill(state.chargeTint)
                        .frame(width: max(4, proxy.size.width * CGFloat(state.percent) / 100))
                }
            }
            .frame(height: 5)
            .padding(.vertical, 6)
            Text(status)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.Palette.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.Palette.surface))
        .accessibilityElement(children: .combine)
    }
}

/// A tall slider like Control Center's: the fill rises from the bottom, clipped to the rounded shape,
/// so any value reads as a level instead of a blob.
private struct VerticalSlider: View {
    var value: Double
    var symbol: String
    var tint: Color
    var label: String
    let onChange: (Double) -> Void
    @State private var dragValue: Double?
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let shown = dragValue ?? value
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        GeometryReader { proxy in
            let height: CGFloat = proxy.size.height
            ZStack(alignment: .bottom) {
                shape.fill(Theme.Palette.surface)
                Rectangle()
                    .fill(tint.opacity(0.9))
                    .frame(height: height * CGFloat(shown))
                VStack(spacing: 0) {
                    Text("\(Int((shown * 100).rounded()))")
                        .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(shown > 0.88 ? Color.black.opacity(0.7) : Theme.Palette.textSecondary)
                        .contentTransition(.numericText(value: shown))
                        .padding(.top, 9)
                    Spacer()
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(shown > 0.14 ? Color.black.opacity(0.75) : Theme.Palette.textPrimary)
                        .contentTransition(.symbolEffect(.replace))
                        .padding(.bottom, 11)
                }
            }
            .clipShape(shape)
            .contentShape(shape)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let next = max(0, min(1, 1 - drag.location.y / max(1, height)))
                        dragValue = next
                        onChange(next)
                    }
                    .onEnded { _ in dragValue = nil }
            )
        }
        .frame(width: 50)
        .opacity(isEnabled ? 1 : 0.4)
        .animation(dragValue == nil ? Motion.value : nil, value: shown)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int((shown * 100).rounded())) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(min(1, value + 0.0625))
            case .decrement: onChange(max(0, value - 0.0625))
            @unknown default: break
            }
        }
    }
}
