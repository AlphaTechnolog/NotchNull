import SwiftUI

/// Draggable level control (output volume). The track thickens on hover; the glyph follows the level.
struct LevelSlider: View {
    var value: Double
    var tint: Color = .white
    var symbol: String = "speaker.wave.3.fill"
    var label: String
    let onChange: (Double) -> Void
    @State private var hovering = false
    @State private var dragValue: Double?

    var body: some View {
        let shown = dragValue ?? value
        HStack(spacing: 8) {
            Image(systemName: shown <= 0.001 ? "speaker.slash.fill" : symbol, variableValue: shown)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 18)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.track)
                    Capsule()
                        .fill(hovering || dragValue != nil ? tint : Color.white.opacity(0.8))
                        .frame(width: max(hovering ? 6 : 4, proxy.size.width * shown))
                }
                .frame(height: hovering || dragValue != nil ? 6 : 4)
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
            .frame(height: 12)
        }
        .animation(Motion.feedback, value: hovering)
        .animation(Motion.value, value: value)
        .onHover { hovering = $0 }
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
