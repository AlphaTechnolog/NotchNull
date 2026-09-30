import SwiftUI

/// What the notch told you about lately: finished agent runs, downloads, screenshots, timers,
/// meetings and devices. One line each, newest first; a row opens what it refers to.
struct RecentTab: View {
    @EnvironmentObject private var log: ActivityLog

    var body: some View {
        Card(padding: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Recent")
                        .font(Theme.Typeface.label)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text("\(log.entries.count)")
                        .font(Theme.Typeface.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .contentTransition(.numericText(value: Double(log.entries.count)))
                    Spacer()
                    if !log.entries.isEmpty {
                        Chip(title: "Clear", tint: Theme.Palette.textSecondary) { log.clear() }
                    }
                }
                if log.entries.isEmpty {
                    emptyState
                } else {
                    NotchScroll {
                        VStack(spacing: 1) {
                            ForEach(Array(log.entries.enumerated()), id: \.element.id) { index, entry in
                                RecentRow(entry: entry) { log.perform(entry) }
                                    .condense(delay: Motion.stagger(index))
                                    .transition(.notchContent)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Palette.textTertiary)
            Text("Nothing yet. Finished agent runs, downloads, screenshots and meetings show up here.")
                .font(Theme.Typeface.body)
                .foregroundStyle(Theme.Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RecentRow: View {
    let entry: ActivityLog.Entry
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: entry.symbol)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(entry.tint)
                    .frame(width: 19, height: 19)
                    .background(Circle().fill(entry.tint.opacity(0.16)))
                Text(entry.title)
                    .font(Theme.Typeface.bodyStrong)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                    .layoutPriority(1)
                if let detail = entry.detail {
                    Text(detail)
                        .font(Theme.Typeface.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 6)
                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    Text(Formatting.relative(entry.date))
                        .font(Theme.Typeface.caption.monospacedDigit())
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .fixedSize()
                }
            }
            .frame(height: 25)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(cornerRadius: 8, padding: EdgeInsets(top: 0, leading: 3, bottom: 0, trailing: 4)))
        .accessibilityLabel([entry.title, entry.detail].compactMap { $0 }.joined(separator: ", "))
    }
}
