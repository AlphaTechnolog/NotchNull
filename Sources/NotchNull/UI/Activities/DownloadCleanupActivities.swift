import SwiftUI

/// "How long should this stay?" — a new download asks from the notch.
struct DownloadKeepActivity: View {
    @EnvironmentObject private var cleanup: DownloadCleanup
    @State private var remember = false

    var body: some View {
        let file = cleanup.pending.first
        WingsLayout {
            Image(systemName: file?.kind.symbol ?? "arrow.down.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(file?.kind.tint ?? Theme.Accent.download)
        } trailing: {
            HStack(spacing: 5) {
                Text("Keep for")
                    .font(Theme.Typeface.label)
                    .foregroundStyle(Theme.Palette.textSecondary)
                if cleanup.pending.count > 1 {
                    Text("+\(cleanup.pending.count - 1)")
                        .font(Theme.Typeface.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .contentTransition(.numericText(value: Double(cleanup.pending.count)))
                }
            }
        } bottom: {
            if let file {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        DownloadGlyph(kind: file.kind, size: 30)
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
                        if !file.fileExtension.isEmpty {
                            RememberChip(fileExtension: file.fileExtension, isOn: $remember)
                        }
                        Chip(title: "Keep", tint: Theme.Palette.textPrimary) { finish(.forever) }
                            .help("Keep it; never trash it")
                        Chip(title: "Done", selected: true) { finish(cleanup.draft) }
                            .help("Trash it \(Formatting.deadline(Date().addingTimeInterval(cleanup.draft.duration ?? 0)))")
                    }
                    KeepTimeline(selection: $cleanup.draft)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
                .id(file.id)
                .transition(.notchContent)
            }
        }
        .onHover { if $0 { cleanup.hold() } }
        .onChange(of: cleanup.pending.first?.id) { _, _ in remember = false }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("New download: how long to keep \(file?.name ?? "it")")
    }

    private func finish(_ choice: KeepChoice) {
        withAnimation(Motion.state) { cleanup.answer(choice, remember: remember) }
    }
}

/// Stops from ten minutes to thirty days. The exact deletion time sits above the chosen stop,
/// so there is never a surprise.
struct KeepTimeline: View {
    @Binding var selection: KeepChoice
    var tint: Color = Theme.Accent.download
    @Namespace private var namespace

    var body: some View {
        let stops = KeepChoice.timed
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(spacing: 0) {
                ForEach(Array(stops.enumerated()), id: \.element) { index, stop in
                    let selected = stop == selection
                    Button {
                        withAnimation(Motion.state) { selection = stop }
                    } label: {
                        VStack(spacing: 5) {
                            Text(Formatting.deadline(context.date.addingTimeInterval(stop.duration ?? 0), now: context.date))
                                .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
                                .foregroundStyle(tint)
                                .lineLimit(1)
                                .fixedSize()
                                .padding(.horizontal, 6)
                                .frame(height: 16)
                                .background(Capsule().fill(tint.opacity(0.16)))
                                .opacity(selected ? 1 : 0)
                            ZStack {
                                track(index: index, count: stops.count)
                                Circle()
                                    .strokeBorder(selected ? tint : Theme.Palette.textTertiary, lineWidth: 1.5)
                                    .background(Circle().fill(Theme.Palette.body))
                                    .frame(width: 12, height: 12)
                                if selected {
                                    Circle()
                                        .fill(tint)
                                        .frame(width: 6, height: 6)
                                        .matchedGeometryEffect(id: "stop", in: namespace)
                                }
                            }
                            .frame(height: 12)
                            Text(stop.short)
                                .font(.system(size: 10, weight: selected ? .semibold : .medium).monospacedDigit())
                                .foregroundStyle(selected ? Theme.Palette.textPrimary : Theme.Palette.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(stop.title)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    /// The line between stops: half a segment on each side, none past the ends.
    private func track(index: Int, count: Int) -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(index == 0 ? .clear : Theme.Palette.track)
            Rectangle().fill(index == count - 1 ? .clear : Theme.Palette.track)
        }
        .frame(height: 1.5)
    }
}

/// "Always for .dmg": the answer becomes the rule for this file type.
private struct RememberChip: View {
    let fileExtension: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(Motion.feedback) { isOn.toggle() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isOn ? Theme.Accent.download : Theme.Palette.textTertiary)
                Text("Always .\(fileExtension)")
                    .font(Theme.Typeface.caption)
                    .foregroundStyle(isOn ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 7)
            .frame(height: 20)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle(hoverFill: Theme.Palette.surfaceHover, cornerRadius: 10, padding: EdgeInsets()))
        .help("Use this answer for every .\(fileExtension) from now on")
        .accessibilityLabel("Always use this for .\(fileExtension) files")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// The file-type tile: glyph on a soft tint of its family color.
struct DownloadGlyph: View {
    let kind: DownloadKind
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: kind.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(kind.tint)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous).fill(kind.tint.opacity(0.16)))
    }
}

struct DownloadTrashedActivity: View {
    @EnvironmentObject private var cleanup: DownloadCleanup

    var body: some View {
        let record = cleanup.lastTrashed
        WingsLayout {
            Image(systemName: "trash.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Accent.warning)
        } trailing: {
            Text("Cleaned up")
                .font(Theme.Typeface.label)
                .foregroundStyle(Theme.Palette.textSecondary)
        } bottom: {
            if let record {
                HStack(spacing: 10) {
                    DownloadGlyph(kind: DownloadKind(fileExtension: record.original.pathExtension.lowercased()), size: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(record.name)
                            .font(Theme.Typeface.bodyStrong)
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text("Moved to the Trash")
                            .font(Theme.Typeface.caption)
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                    Spacer(minLength: 8)
                    Chip(title: "Undo", selected: true) { cleanup.undoTrash() }
                        .help("Put it back in Downloads")
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(record?.name ?? "A download") moved to the Trash")
    }
}

/// The last seconds before a download goes, counted down beside the notch.
struct DownloadExpiringActivity: View {
    @EnvironmentObject private var cleanup: DownloadCleanup

    var body: some View {
        let soonest = cleanup.expiring.first
        let imminent = cleanup.expiring.filter { ($0.expiresAt?.timeIntervalSinceNow ?? .infinity) <= Constants.Durations.downloadCountdown }.count
        WingsLayout {
            HStack(spacing: 5) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Accent.warning)
                if imminent > 1 {
                    Text("\(imminent)")
                        .font(Theme.Typeface.metric)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        } trailing: {
            if let deadline = soonest?.expiresAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Formatting.remaining(until: deadline, now: context.date))
                        .font(Theme.Typeface.wing)
                        .foregroundStyle(Theme.Accent.warning)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(Motion.value, value: Int(deadline.timeIntervalSince(context.date)))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(soonest?.name ?? "A download") goes to the Trash soon")
    }
}
