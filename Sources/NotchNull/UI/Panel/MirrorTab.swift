import AVFoundation
import SwiftUI

/// Full-bleed camera preview. The camera only runs while this tab is visible.
struct MirrorTab: View {
    @EnvironmentObject private var mirror: MirrorService
    @EnvironmentObject private var preferences: Preferences
    @State private var zoom: CGFloat = 1

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.surface, style: .continuous)
        ZStack {
            shape.fill(Theme.Palette.surface)
            switch mirror.authorization {
            case .authorized:
                CameraPreview(session: mirror.session)
                    .scaleEffect(zoom)
                    .clipShape(shape)
                    .opacity(mirror.isRunning ? 1 : 0)
                    .blur(radius: mirror.isRunning ? 0 : 16)
                    .animation(.easeOut(duration: 0.45), value: mirror.isRunning)
                if !mirror.isRunning {
                    ProgressView().controlSize(.small).transition(.opacity)
                }
            case .notDetermined:
                ProgressView().controlSize(.small)
            default:
                VStack(spacing: 10) {
                    Image(systemName: "web.camera")
                        .font(.system(size: 26, weight: .regular))
                        .foregroundStyle(Theme.Palette.textTertiary)
                    Chip(title: "Allow camera access", tint: preferences.accent) { Permissions.open(.camera) }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if mirror.isRunning {
                HStack(spacing: 4) {
                    ForEach([1.0, 1.4, 2.0], id: \.self) { value in
                        Chip(title: "\(value == 1 ? "1" : String(format: "%.1f", value))×", selected: zoom == value, tint: .white) {
                            withAnimation(Motion.state) { zoom = value }
                        }
                    }
                }
                .padding(4)
                .background(Capsule().fill(.black.opacity(0.45)))
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .offset(y: 6)))
            }
        }
        .overlay(alignment: .topLeading) {
            if mirror.isRunning {
                Circle()
                    .fill(Theme.Accent.success)
                    .frame(width: 7, height: 7)
                    .modifier(PulseDot())
                    .padding(12)
                    .accessibilityLabel("Camera on")
            }
        }
        .condense(delay: Motion.stagger(1))
        .onAppear { mirror.start() }
        .onDisappear { mirror.stop() }
    }
}

private struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer = layer
        view.wantsLayer = true
        mirror(layer)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let layer = nsView.layer as? AVCaptureVideoPreviewLayer { mirror(layer) }
    }

    private func mirror(_ layer: AVCaptureVideoPreviewLayer) {
        guard let connection = layer.connection, connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = true
    }
}
