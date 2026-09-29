@preconcurrency import AVFoundation
import Combine
import SwiftUI

/// Front camera preview for the Mirror tab. The session runs only while the tab is visible.
@MainActor
final class MirrorService: ObservableObject {
    @Published private(set) var authorization = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var isRunning = false

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "dev.notchnull.mirror")
    private var configured = false

    func start() {
        authorization = AVCaptureDevice.authorizationStatus(for: .video)
        switch authorization {
        case .authorized:
            run()
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                authorization = granted ? .authorized : .denied
                if granted { run() }
            }
        default:
            break
        }
    }

    func stop() {
        let session = session
        queue.async { if session.isRunning { session.stopRunning() } }
        withAnimation(Motion.state) { isRunning = false }
    }

    private func run() {
        let session = session
        let needsConfig = !configured
        configured = true
        queue.async {
            if needsConfig {
                session.beginConfiguration()
                session.sessionPreset = .medium
                if let device = AVCaptureDevice.default(for: .video),
                   let input = try? AVCaptureDeviceInput(device: device),
                   session.canAddInput(input) {
                    session.addInput(input)
                }
                session.commitConfiguration()
            }
            if !session.isRunning { session.startRunning() }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { withAnimation(Motion.state) { self.isRunning = session.isRunning } }
            }
        }
    }
}
