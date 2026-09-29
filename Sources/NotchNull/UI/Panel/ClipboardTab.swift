import SwiftUI

struct ClipboardTab: View {
    @EnvironmentObject private var clipboard: ClipboardService
    @State private var query = ""

    var body: some View {
        Card(padding: 8) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.Palette.textTertiary)
                        NotchSearchField(placeholder: "Search clipboard", text: $query)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Capsule().fill(Theme.Palette.surfaceHover))
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .help("History is encrypted on this Mac. Password managers are skipped.")
                    if clipboard.items.contains(where: { !$0.pinned }) {
                        Chip(title: "Clear", tint: Theme.Palette.textSecondary) { clipboard.clearUnpinned() }
                    }
                }
                let filtered = clipboard.items.filter { $0.matches(query) }
                if filtered.isEmpty {
                    Text(clipboard.items.isEmpty ? "Copy something and it appears here." : "No matches")
                        .font(Theme.Typeface.body)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    NotchScroll {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                            ForEach(Array(filtered.prefix(40).enumerated()), id: \.element.id) { index, item in
                                ClipTile(item: item)
                                    .condense(delay: Motion.stagger(index))
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ClipTile: View {
    let item: ClipItem
    @EnvironmentObject private var clipboard: ClipboardService
    @State private var hovering = false

    var body: some View {
        let copied = clipboard.lastCopiedID == item.id
        Button { clipboard.copy(item) } label: {
            HStack(spacing: 8) {
                leading
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(item.kind == .text ? Theme.Typeface.body : Theme.Typeface.bodyStrong)
                        .foregroundStyle(item.kind == .link ? Theme.Accent.airdrop : Theme.Palette.textPrimary)
                        .lineLimit(item.kind == .text ? 2 : 1)
                        .truncationMode(item.kind == .file ? .middle : .tail)
                        .multilineTextAlignment(.leading)
                    Text([item.sourceApp, Formatting.relative(item.date)].compactMap { $0 }.joined(separator: " · "))
                        .font(Theme.Typeface.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                ZStack {
                    if copied {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.Accent.success)
                            .transition(.scale(scale: 0.25).combined(with: .opacity))
                    } else if hovering || item.pinned {
                        HStack(spacing: 0) {
                            IconButton(symbol: item.pinned ? "pin.fill" : "pin", size: 9, tint: item.pinned ? Theme.Accent.warning : Theme.Palette.textSecondary, label: item.pinned ? "Unpin" : "Pin") {
                                clipboard.togglePin(item)
                            }
                            if hovering {
                                IconButton(symbol: "trash", size: 9, tint: Theme.Palette.textSecondary, label: "Delete") { clipboard.delete(item) }
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .animation(Motion.state, value: copied)
            }
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(copied ? Theme.Accent.success.opacity(0.14) : (hovering ? Theme.Palette.surfaceHover : Theme.Palette.surface))
            )
        }
        .buttonStyle(PressableStyle(hoverFill: .clear, cornerRadius: 10, padding: EdgeInsets()))
        .onHover { hovering = $0 }
        .animation(Motion.feedback, value: hovering)
        .accessibilityLabel("Copy \(item.preview)")
    }

    private static let previewSize: CGFloat = 36

    @ViewBuilder
    private var leading: some View {
        let side = Self.previewSize
        switch item.kind {
        case .image:
            if let data = item.imagePNG, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.white.opacity(0.08)))
            }
        case .file:
            if let urls = item.fileURLs, let first = urls.first {
                FileThumbnail(url: first, size: side)
                    .overlay(alignment: .bottomTrailing) {
                        if urls.count > 1 {
                            Text("\(urls.count)")
                                .font(.system(size: 8, weight: .bold).monospacedDigit())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .frame(height: 12)
                                .background(Capsule().fill(Theme.Accent.clipboard))
                                .offset(x: 3, y: 3)
                        }
                    }
            }
        case .color:
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(hex: UInt32(item.text?.trimmingCharacters(in: CharacterSet(charactersIn: "# \n")).prefix(6) ?? "", radix: 16) ?? 0))
                .frame(width: side, height: side)
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.white.opacity(0.1)))
        default:
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Accent.clipboard)
                .frame(width: side, height: side)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.Accent.clipboard.opacity(0.14)))
        }
    }

    private var symbol: String {
        switch item.kind {
        case .link: "link"
        default: "text.alignleft"
        }
    }

    /// File names keep their extension visible; images describe their pixel size.
    private var title: String {
        switch item.kind {
        case .image:
            if let data = item.imagePNG, let rep = NSImage(data: data)?.representations.first {
                return "Image \(rep.pixelsWide)×\(rep.pixelsHigh)"
            }
            return "Image"
        default:
            return item.preview.isEmpty ? " " : item.preview
        }
    }
}
