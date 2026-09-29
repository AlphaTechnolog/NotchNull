import AppKit
import SwiftUI

@main
enum NotchNullMain {
    static func main() {
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--snapshots"), arguments.count > index + 1 {
            MainActor.assumeIsolated {
                SnapshotRenderer.renderAll(to: URL(fileURLWithPath: arguments[index + 1]), transparent: arguments.contains("--transparent"))
            }
            return
        }
        if let index = arguments.firstIndex(of: "--icon"), arguments.count > index + 1 {
            MainActor.assumeIsolated {
                AppIconArt.export(to: URL(fileURLWithPath: arguments[index + 1]))
            }
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let services = AppServices()
    private var coordinator: NotchCoordinator?
    private var menuBar: MenuBarController?
    private let menuBarMask = MenuBarMask()

    func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsWindowController.shared.configure(services: services)
        services.start()
        menuBarMask.start()
        let coordinator = NotchCoordinator(services: services)
        coordinator.start()
        self.coordinator = coordinator
        menuBar = MenuBarController { [weak coordinator] in coordinator?.primaryModel?.open() }
        Log.app.info("NotchNull launched")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        services.keepAwake.stop()
    }
}
