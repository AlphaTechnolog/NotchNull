import SwiftUI

/// Time text that keeps a fixed slot: the widest expected value is laid out invisibly behind the
/// live value, so `9s` → `10s` and `59s` → `1m 0s` never resize the wing or the notch body.
///
/// It deliberately has no content transition or animation: the value changes once per clock tick,
/// and one redraw per tick is the whole budget.
struct TimeText: View {
    var value: String
    /// The widest string this slot must fit, for example `59m 59s` or `99:59:59`.
    var widest: String

    var body: some View {
        ZStack(alignment: .trailing) {
            Text(widest)
                .hidden()
                .accessibilityHidden(true)
            Text(value)
        }
        .monospacedDigit()
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value)
    }
}

/// Reads the shared clock inside a leaf view, so a tick invalidates only that leaf instead of the
/// whole activity or notch body.
struct ClockText<Content: View>: View {
    @EnvironmentObject private var clock: NotchClock
    @State private var label = UUID()

    private let content: (Date) -> Content

    init(@ViewBuilder content: @escaping (Date) -> Content) {
        self.content = content
    }

    var body: some View {
        content(clock.now)
            .onAppear { clock.setShowing(true, label: label) }
            .onDisappear { clock.setShowing(false, label: label) }
    }
}
