import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var services: AppServices?

    func configure(services: AppServices) {
        self.services = services
    }

    func show() {
        guard let services else { return }
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView().withServices(services))
            let window = NSWindow(contentViewController: hosting)
            window.title = "\(Constants.appName) Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.setContentSize(NSSize(width: 760, height: 600))
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .darkAqua)
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
