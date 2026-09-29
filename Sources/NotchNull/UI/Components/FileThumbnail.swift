import AppKit
import QuickLookThumbnailing
import SwiftUI

/// QuickLook preview of a file on disk (screenshots, PDFs, videos…), falling back to its Finder icon.
struct FileThumbnail: View {
    let url: URL
    var size: CGFloat = 36
    var cornerRadius: CGFloat = 7
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(2)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(.white.opacity(image == nil ? 0 : 0.08)))
        .task(id: url) { await load() }
    }

    private func load() async {
        if let cached = ThumbnailCache.shared.image(for: url) {
            image = cached
            return
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: size * 2, height: size * 2),
            scale: scale,
            representationTypes: .thumbnail
        )
        guard let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else { return }
        let loaded = representation.nsImage
        ThumbnailCache.shared.store(loaded, for: url)
        withAnimation(Motion.feedback) { image = loaded }
    }
}

/// Keeps generated thumbnails so scrolling the history does not regenerate them.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSURL, NSImage>()

    private init() { cache.countLimit = 120 }

    func image(for url: URL) -> NSImage? { cache.object(forKey: url as NSURL) }
    func store(_ image: NSImage, for url: URL) { cache.setObject(image, forKey: url as NSURL) }
}
