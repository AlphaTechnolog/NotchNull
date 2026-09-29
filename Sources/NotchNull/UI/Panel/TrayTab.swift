import SwiftUI

struct TrayTab: View {
    @EnvironmentObject private var tray: TrayStore
    @State private var targeted = false

    var body: some View {
        Card(padding: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Tray")
                        .font(Theme.Typeface.label)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text("\(tray.items.count)")
                        .font(Theme.Typeface.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .contentTransition(.numericText(value: Double(tray.items.count)))
                    Spacer()
                    if !tray.items.isEmpty {
                        Chip(title: "AirDrop all", tint: Theme.Accent.airdrop) { tray.airDrop(tray.items) }
                        Chip(title: "Clear", tint: Theme.Palette.textSecondary) { tray.clear() }
                    }
                }
                if tray.items.isEmpty {
                    emptyState
                } else {
                    NotchScroll(axis: .horizontal) {
                        HStack(spacing: 8) {
                            ForEach(Array(tray.items.enumerated()), id: \.element.id) { index, item in
                                TrayTile(item: item)
                                    .condense(delay: Motion.stagger(index))
                                    .transition(.notchContent)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.surface, style: .continuous)
                .strokeBorder(Theme.Accent.tray, lineWidth: targeted ? 1.5 : 0)
                .animation(Motion.feedback, value: targeted)
        )
        .notchDrop(isTargeted: $targeted) { providers in
            DropSupport.resolve(providers, tray: tray) { tray.add(urls: $0) }
            return true
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(targeted ? Theme.Accent.tray : Theme.Palette.textTertiary)
                .symbolEffect(.bounce, value: targeted)
            Text("Drag files onto the notch to park them here")
                .font(Theme.Typeface.bodyStrong)
                .foregroundStyle(Theme.Palette.textSecondary)
            Text("Screenshots land here too. Drag anything back out when you need it.")
                .font(Theme.Typeface.caption)
                .foregroundStyle(Theme.Palette.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.surface - 8, style: .continuous)
                .strokeBorder(Theme.Palette.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }
}

private struct TrayTile: View {
    let item: TrayItem
    @EnvironmentObject private var tray: TrayStore
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let thumbnail = tray.thumbnails[item.id] {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .transition(.opacity)
                    } else {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
                .frame(width: 70, height: 62)
                .scaleEffect(hovering ? 1.04 : 1)

                if hovering {
                    Button { tray.remove(item) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Color.black.opacity(0.75)))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.2)))
                    }
                    .buttonStyle(PressableStyle(hoverFill: .clear, cornerRadius: 8, padding: EdgeInsets()))
                    .offset(x: 4, y: -4)
                    .transition(.scale(scale: 0.25).combined(with: .opacity))
                    .accessibilityLabel("Remove \(item.name)")
                }
            }
            Text(item.name)
                .font(Theme.Typeface.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 78)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(hovering ? Theme.Palette.surfaceHover : .clear)
        )
        .animation(Motion.feedback, value: hovering)
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { tray.open(item) }
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
        .contextMenu {
            Button("Open") { tray.open(item) }
            Button("Show in Finder") { tray.reveal(item) }
            Button("Copy") { tray.copy(item) }
            Button("AirDrop") { tray.airDrop([item]) }
            Divider()
            Button("Remove from Tray") { tray.remove(item) }
        }
        .help(item.name)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.name)
    }
}
