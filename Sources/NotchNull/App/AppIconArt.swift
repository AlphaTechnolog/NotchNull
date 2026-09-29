import AppKit
import SwiftUI

/// The app icon, drawn in SwiftUI and exported with `NotchNull --icon <file.png>` at build time:
/// a black notch hanging from the top edge of a graphite tile, its rim lit pink to cyan, with the
/// null mark inside. The tile follows the macOS icon grid (824 px body on a 1024 px canvas).
struct AppIconArt: View {
    private static let body: CGFloat = 824
    private static let corner: CGFloat = 185

    var body: some View {
        ZStack {
            tile
                .frame(width: Self.body, height: Self.body)
                .shadow(color: .black.opacity(0.35), radius: 14, y: 10)
        }
        .frame(width: 1024, height: 1024)
    }

    private var tile: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: Self.corner, style: .continuous)
                .fill(LinearGradient(colors: [Brand.graphiteTop, Brand.graphiteBottom], startPoint: .top, endPoint: .bottom))
            ZStack(alignment: .top) {
                NotchShape(topRadius: 48, bottomRadius: 120, edgeOnly: true)
                    .stroke(Brand.glow, lineWidth: 22)
                    .blur(radius: 30)
                    .opacity(0.85)
                NotchShape(topRadius: 48, bottomRadius: 120)
                    .fill(Color.black)
                NotchShape(topRadius: 48, bottomRadius: 120, edgeOnly: true)
                    .stroke(Brand.glow, lineWidth: 4.5)
                    .mask(LinearGradient(colors: [.clear, .black, .black], startPoint: .top, endPoint: .bottom))
                NullMark(size: 150, weight: 0.12)
                    .padding(.top, 112)
            }
            .frame(width: 612, height: 306)
            .padding(.top, 56)
            RoundedRectangle(cornerRadius: Self.corner, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.03)], startPoint: .top, endPoint: .bottom), lineWidth: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: Self.corner, style: .continuous))
    }

    @MainActor
    static func export(to url: URL) {
        let renderer = ImageRenderer(content: AppIconArt())
        renderer.scale = 1
        guard let tiff = renderer.nsImage?.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }
}
