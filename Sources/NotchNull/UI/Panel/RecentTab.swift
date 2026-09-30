import SwiftUI

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
