import SwiftUI

extension View {
    /// `onDrop` backed by AppKit; skipped while rendering snapshots, which cannot draw it.
    @ViewBuilder
    func notchDrop(isTargeted: Binding<Bool>, perform: @escaping ([NSItemProvider]) -> Bool) -> some View {
        if Motion.isSnapshot {
            self
        } else {
            onDrop(of: DropSupport.acceptedTypes, isTargeted: isTargeted, perform: perform)
        }
    }
}

/// Search field that renders as static text in snapshots.
struct NotchSearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        if Motion.isSnapshot {
            Text(placeholder)
                .font(Theme.Typeface.body)
                .foregroundStyle(Theme.Palette.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(Theme.Typeface.body)
                .foregroundStyle(Theme.Palette.textPrimary)
        }
    }
}

/// ScrollView without indicators. Snapshot rendering cannot draw AppKit-backed scroll views,
/// so there the content is laid out directly.
struct NotchScroll<Content: View>: View {
    var axis: Axis.Set = .vertical
    @ViewBuilder var content: Content

    /// Height of the soft fade at the bottom edge, so a partly visible row reads as "more below".
    var fade: CGFloat = 10

    var body: some View {
        if axis == .vertical {
            // Content that fits is laid out as is; only overflowing content scrolls and fades out.
            ViewThatFits(in: .vertical) {
                content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                scrolling.mask(bottomFade)
            }
        } else {
            scrolling
        }
    }

    @ViewBuilder
    private var scrolling: some View {
        if Motion.isSnapshot {
            // Overflow runs off the trailing edge, as a scroll view at rest would show it.
            Color.clear
                .overlay(alignment: .topLeading) {
                    content.fixedSize(horizontal: axis == .horizontal, vertical: false)
                }
                .clipped()
        } else {
            ScrollView(axis, showsIndicators: false) { content }
        }
    }

    private var bottomFade: some View {
        VStack(spacing: 0) {
            Color.black
            LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: fade)
        }
    }
}
