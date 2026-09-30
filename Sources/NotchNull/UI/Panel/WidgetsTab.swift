import SwiftUI

/// The widgets from ~/.notchnull/widgets, side by side. Empty, it says how to make one.
struct WidgetsTab: View {
    @EnvironmentObject private var store: WidgetStore

    var body: some View {
        if store.widgets.isEmpty {
            Card(padding: 10) { emptyState }
        } else {
            NotchScroll(axis: .horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(Array(store.widgets.enumerated()), id: \.element.id) { index, widget in
                        WidgetCard(widget: widget)
                            .condense(delay: Motion.stagger(index))
                            .transition(.notchContent)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Theme.Palette.textTertiary)
            Text("Ask your agent for a widget")
                .font(Theme.Typeface.bodyStrong)
                .foregroundStyle(Theme.Palette.textSecondary)
            Text("“Use the notchnull skill to add a widget with my open pull requests.” Files in ~/.notchnull/widgets appear here as you save them.")
                .font(Theme.Typeface.caption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Chip(title: "Open folder", tint: Theme.Palette.textSecondary) { NSWorkspace.shared.open(NotchHome.widgets) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.surface - 8, style: .continuous)
                .strokeBorder(Theme.Palette.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }
}
