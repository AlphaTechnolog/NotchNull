import SwiftUI

/// Appears when a file is dragged toward the notch: park it, copy it or AirDrop it.
struct DropPanel: View {
    @EnvironmentObject private var tray: TrayStore
    @EnvironmentObject private var model: NotchViewModel
    @Environment(\.wingContext) private var context
    @State private var names: [String] = DropSupport.draggedNames()
    @State private var completed: DropTarget.Action?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: names.count > 1 ? "doc.on.doc.fill" : "doc.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text(title)
                        .font(Theme.Typeface.bodyStrong)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Color.clear.frame(width: model.headerGap)
                Text(completed.map { $0.doneLabel } ?? "Drop on a tile")
                    .font(Theme.Typeface.caption)
                    .foregroundStyle(completed == nil ? Theme.Palette.textTertiary : Theme.Accent.success)
                    .contentTransition(.opacity)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: context.rowHeight)
            .padding(.horizontal, Theme.Radius.panelPadding + 4 + model.headerInset)
            .condense()

            HStack(spacing: 8) {
                ForEach(Array(DropTarget.Action.allCases.enumerated()), id: \.element) { index, action in
                    DropTarget(action: action) { urls in perform(action, urls) }
                        .condense(delay: Motion.stagger(index + 1))
                }
            }
            .padding(.horizontal, Theme.Radius.panelPadding)
            .padding(.bottom, Theme.Radius.panelPadding)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var title: String {
        switch names.count {
        case 0: "Drop files"
        case 1: names[0]
        default: "\(names.count) items"
        }
    }

    private func perform(_ action: DropTarget.Action, _ urls: [URL]) {
        guard !urls.isEmpty else { return }
        switch action {
        case .tray: tray.add(urls: urls)
        case .copy: TrayStore.copyToPasteboard(urls)
        case .airdrop: TrayStore.airDrop(urls)
        }
        withAnimation(Motion.state) { completed = action }
    }
}

struct DropTarget: View {
    enum Action: CaseIterable {
        case tray, copy, airdrop

        var title: String {
            switch self {
            case .tray: "Tray"
            case .copy: "Copy"
            case .airdrop: "AirDrop"
            }
        }
        var subtitle: String {
            switch self {
            case .tray: "Keep for later"
            case .copy: "Onto the clipboard"
            case .airdrop: "Send to a device"
            }
        }
        var targetedSubtitle: String {
            switch self {
            case .tray: "Release to keep"
            case .copy: "Release to copy"
            case .airdrop: "Release to share"
            }
        }
        var doneLabel: String {
            switch self {
            case .tray: "Saved to Tray"
            case .copy: "Copied"
            case .airdrop: "Opening AirDrop"
            }
        }
        var symbol: String {
            switch self {
            case .tray: "tray.and.arrow.down.fill"
            case .copy: "doc.on.clipboard.fill"
            case .airdrop: "airplayaudio"
            }
        }
        var tint: Color {
            switch self {
            case .tray: Theme.Accent.tray
            case .copy: Theme.Accent.copy
            case .airdrop: Theme.Accent.airdrop
            }
        }
    }

    let action: Action
    let onDrop: ([URL]) -> Void
    @EnvironmentObject private var tray: TrayStore
    @State private var targeted = false
    @State private var dropped = 0

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: action.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(action.tint.opacity(targeted ? 1 : 0.75)))
                .scaleEffect(targeted ? 1.12 : 1)
                .symbolEffect(.bounce, value: dropped)
            Text(action.title)
                .font(Theme.Typeface.bodyStrong)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(targeted ? action.targetedSubtitle : action.subtitle)
                .font(Theme.Typeface.caption)
                .foregroundStyle(targeted ? action.tint : Theme.Palette.textTertiary)
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.surface - 4, style: .continuous)
                .fill(targeted ? action.tint.opacity(0.14) : Theme.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.surface - 4, style: .continuous)
                .strokeBorder(
                    targeted ? action.tint : Theme.Palette.hairline.opacity(1.6),
                    style: StrokeStyle(lineWidth: targeted ? 1.5 : 1, dash: targeted ? [] : [4, 3])
                )
        )
        .scaleEffect(targeted ? 1.03 : 1)
        .animation(Motion.state, value: targeted)
        .notchDrop(isTargeted: $targeted) { providers in
            DropSupport.resolve(providers, tray: tray) { urls in
                dropped += 1
                onDrop(urls)
            }
            return true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(action.title): \(action.subtitle)")
    }
}
