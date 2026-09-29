import SwiftUI

/// Every download NotchNull is looking after: what is still waiting for an answer and what goes
/// to the Trash next, with the time left and a way to change your mind.
struct DownloadsTab: View {
    @EnvironmentObject private var cleanup: DownloadCleanup

    var body: some View {
        Card(padding: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Cleaning up")
                        .font(Theme.Typeface.label)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text("\(cleanup.expiring.count)")
                        .font(Theme.Typeface.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .contentTransition(.numericText(value: Double(cleanup.expiring.count)))
                    Spacer()
                    if let record = cleanup.lastTrashed {
                        Chip(title: "Undo \(record.name)", tint: Theme.Palette.textSecondary) { cleanup.undoTrash() }
                            .lineLimit(1)
                            .frame(maxWidth: 200)
                    }
                    Chip(title: "Open Downloads", tint: Theme.Palette.textSecondary) {
                        NSWorkspace.shared.open(Constants.Paths.downloads)
                    }
                }
                if cleanup.expiring.isEmpty && cleanup.pending.isEmpty {
                    emptyState
                } else {
                    NotchScroll {
                        VStack(spacing: 6) {
                            ForEach(Array((cleanup.pending + cleanup.expiring).enumerated()), id: \.element.id) { index, file in
                                DownloadRow(file: file, waiting: file.expiresAt == nil, asking: file.id == cleanup.pending.first?.id)
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
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Theme.Palette.textTertiary)
            Text("Nothing is set to expire")
                .font(Theme.Typeface.bodyStrong)
                .foregroundStyle(Theme.Palette.textSecondary)
            Text("New downloads ask how long to stay. When time is up they go to the Trash, and you can put them back.")
                .font(Theme.Typeface.caption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.surface - 8, style: .continuous)
                .strokeBorder(Theme.Palette.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }
}

private struct DownloadRow: View {
    let file: TrackedDownload
    let waiting: Bool
    var asking = false
    @EnvironmentObject private var cleanup: DownloadCleanup
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            DownloadGlyph(kind: file.kind, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .font(Theme.Typeface.bodyStrong)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text([file.source, Formatting.bytes(Double(file.size))].compactMap { $0 }.joined(separator: " · "))
                    .font(Theme.Typeface.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if waiting {
                Text(asking ? "Asking in the notch" : "Next")
                    .font(Theme.Typeface.caption)
                    .foregroundStyle(asking ? Theme.Accent.download : Theme.Palette.textTertiary)
            } else if let deadline = file.expiresAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Formatting.remaining(until: deadline, now: context.date))
                            .font(Theme.Typeface.metric)
                            .foregroundStyle(deadline.timeIntervalSince(context.date) < 3600 ? Theme.Accent.warning : Theme.Palette.textPrimary)
                            .contentTransition(.numericText(countsDown: true))
                        Text(Formatting.deadline(deadline, now: context.date))
                            .font(Theme.Typeface.caption)
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                }
                Menu {
                    ForEach(KeepChoice.timed) { choice in
                        Button("\(choice.title) from now") { cleanup.change(file, to: choice) }
                    }
                    Divider()
                    Button("Keep forever") { cleanup.change(file, to: .forever) }
                    Button("Move to Trash now", role: .destructive) { withAnimation(Motion.state) { cleanup.trashNow(file) } }
                    Divider()
                    Button("Show in Finder") {
                        if let url = DownloadCleanup.resolve(file) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    }
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Change when it goes")
                .accessibilityLabel("Change when \(file.name) goes to the Trash")
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(hovering ? Theme.Palette.surfaceHover : Theme.Palette.surface)
        )
        .onHover { hovering = $0 }
        .animation(Motion.feedback, value: hovering)
    }
}
