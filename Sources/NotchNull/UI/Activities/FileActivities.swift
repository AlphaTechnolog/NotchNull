import SwiftUI

struct TrayAddedActivity: View {
    @EnvironmentObject private var tray: TrayStore

    var body: some View {
        WingsLayout {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Accent.tray)
                .symbolEffect(.bounce, value: tray.items.count)
        } trailing: {
            Text("\(tray.items.count)")
                .font(Theme.Typeface.wing)
                .foregroundStyle(Theme.Palette.textPrimary)
                .contentTransition(.numericText(value: Double(tray.items.count)))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tray.items.count) items in Tray")
    }
}

struct ScreenshotActivity: View {
    @EnvironmentObject private var screenshots: ScreenshotWatcher
    @EnvironmentObject private var tray: TrayStore

    var body: some View {
        WingsLayout {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Accent.tray)
        } trailing: {
            Text("In Tray")
                .font(Theme.Typeface.label)
                .foregroundStyle(Theme.Palette.textSecondary)
        } bottom: {
            HStack(spacing: 12) {
                if let image = screenshots.latestImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 68, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.white.opacity(0.1)))
                        .onDrag { NSItemProvider(contentsOf: screenshots.latest) ?? NSItemProvider() }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Screenshot")
                        .font(Theme.Typeface.title)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(screenshots.latest?.lastPathComponent ?? "")
                        .font(Theme.Typeface.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 6)
                if let url = screenshots.latest {
                    IconButton(symbol: "doc.on.doc", label: "Copy") { TrayStore.copyToPasteboard([url]) }
                    IconButton(symbol: "airplayaudio", label: "AirDrop") { TrayStore.airDrop([url]) }
                    IconButton(symbol: "folder", label: "Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 10)
        }
    }
}

struct DownloadActivity: View {
    @EnvironmentObject private var downloads: DownloadWatcher

    var body: some View {
        let download = downloads.primary
        WingsLayout {
            HStack(spacing: 5) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.Accent.download)
                    .symbolEffect(.pulse, options: .repeating)
                if let fraction = download?.fraction {
                    Text("\(Int(fraction * 100))%")
                        .font(Theme.Typeface.wing)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .contentTransition(.numericText(value: fraction))
                } else if let download {
                    Text(Formatting.bytes(Double(download.bytes)))
                        .font(Theme.Typeface.metric)
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
            }
        } trailing: {
            Text(Formatting.rate(download?.bytesPerSecond ?? 0))
                .font(Theme.Typeface.metric)
                .foregroundStyle(Theme.Palette.textSecondary)
                .contentTransition(.numericText())
        } bottom: {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.track)
                    if let fraction = download?.fraction {
                        Capsule()
                            .fill(Theme.Accent.download)
                            .frame(width: max(3, proxy.size.width * fraction))
                            .animation(Motion.value, value: fraction)
                    } else {
                        IndeterminateSweep(tint: Theme.Accent.download)
                    }
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 20)
            .padding(.bottom, 5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Downloading \(download?.name ?? "")")
    }
}

/// Indeterminate progress: a short highlight sweeping along the track.
struct IndeterminateSweep: View {
    var tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: Motion.reduceMotion)) { context in
            GeometryReader { proxy in
                let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
                let width = proxy.size.width * 0.3
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0), tint, tint.opacity(0)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: width)
                    .offset(x: -width + (proxy.size.width + width) * phase)
            }
        }
        .clipShape(Capsule())
    }
}

struct DownloadDoneActivity: View {
    @EnvironmentObject private var downloads: DownloadWatcher
    @EnvironmentObject private var cleanup: DownloadCleanup
    @EnvironmentObject private var tray: TrayStore
    @State private var pop = false

    var body: some View {
        // A file kept by a rule says when it goes, so the rule is never a surprise.
        let deadline = downloads.finished.flatMap { url in cleanup.expiring.first { $0.name == url.lastPathComponent }?.expiresAt }
        WingsLayout {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Accent.download)
                .symbolEffect(.bounce, value: pop)
        } trailing: {
            Text(deadline.map { "Trash \(Formatting.deadline($0))" } ?? "Downloaded")
                .font(Theme.Typeface.label)
                .foregroundStyle(deadline == nil ? Theme.Palette.textSecondary : Theme.Accent.warning)
        } bottom: {
            if let url = downloads.finished {
                HStack(spacing: 10) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .frame(width: 26, height: 26)
                    Text(url.lastPathComponent)
                        .font(Theme.Typeface.bodyStrong)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 6)
                    IconButton(symbol: "tray.and.arrow.down", label: "Keep in Tray") { tray.add(urls: [url]) }
                    IconButton(symbol: "folder", label: "Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
            }
        }
        .onAppear { pop.toggle() }
    }
}
