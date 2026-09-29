import SwiftUI

/// Scale-on-press with a hover surface. Every tappable control in the notch uses this.
struct PressableStyle: ButtonStyle {
    var hoverFill: Color = Theme.Palette.surfaceHover
    var cornerRadius: CGFloat = Theme.Radius.control
    var padding: EdgeInsets = EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)

    func makeBody(configuration: Configuration) -> some View {
        PressableBody(configuration: configuration, hoverFill: hoverFill, cornerRadius: cornerRadius, padding: padding)
    }

    private struct PressableBody: View {
        let configuration: Configuration
        let hoverFill: Color
        let cornerRadius: CGFloat
        let padding: EdgeInsets
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(hovering && isEnabled ? hoverFill : .clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .scaleEffect(configuration.isPressed ? Motion.pressScale : 1)
                .opacity(isEnabled ? 1 : 0.4)
                .animation(Motion.feedback, value: configuration.isPressed)
                .animation(Motion.feedback, value: hovering)
                .onHover { hovering = $0 }
        }
    }
}

/// Round icon button (transport controls, row actions).
struct IconButton: View {
    let symbol: String
    var size: CGFloat = 13
    var weight: Font.Weight = .semibold
    var tint: Color = Theme.Palette.textPrimary
    var label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: weight))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace.downUp))
                .frame(width: size + 14, height: size + 14)
        }
        .buttonStyle(PressableStyle(cornerRadius: (size + 14) / 2, padding: EdgeInsets()))
        .accessibilityLabel(label)
        .help(label)
    }
}

extension View {
    /// Content arriving from blur: the notch's standard entrance for any sub-view.
    func condense(delay: Double = 0) -> some View {
        modifier(CondenseModifier(delay: delay))
    }
}

private struct CondenseModifier: ViewModifier {
    let delay: Double
    @State private var shown = Motion.isSnapshot

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .blur(radius: shown || Motion.reduceMotion ? 0 : Motion.contentBlur)
            .scaleEffect(shown || Motion.reduceMotion ? 1 : 0.96, anchor: .top)
            .onAppear {
                withAnimation(Motion.content.delay(delay)) { shown = true }
            }
    }
}

extension AnyTransition {
    /// Blur + scale + fade, used for content swaps inside the notch body.
    static var notchContent: AnyTransition {
        if Motion.reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .modifier(
                active: BlurScale(blur: Motion.contentBlur, scale: 0.94, opacity: 0),
                identity: BlurScale(blur: 0, scale: 1, opacity: 1)
            ),
            removal: .modifier(
                active: BlurScale(blur: Motion.contentBlur, scale: 0.98, opacity: 0),
                identity: BlurScale(blur: 0, scale: 1, opacity: 1)
            )
        )
    }
}

struct BlurScale: ViewModifier {
    let blur: CGFloat
    let scale: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content.blur(radius: blur).scaleEffect(scale, anchor: .top).opacity(opacity)
    }
}
