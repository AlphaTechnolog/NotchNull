import AppKit
import Combine

/// Optional menu bar item: open the notch, settings, quit.
@MainActor
final class MenuBarController: NSObject {
    private var item: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []
    private let openNotch: () -> Void

    init(openNotch: @escaping () -> Void) {
        self.openNotch = openNotch
        super.init()
        Preferences.shared.$showMenuBarIcon
            .receive(on: RunLoop.main)
            .sink { [weak self] show in self?.setVisible(show) }
            .store(in: &cancellables)
    }

    private func setVisible(_ visible: Bool) {
        if !visible {
            if let item { NSStatusBar.system.removeStatusItem(item) }
            item = nil
            return
        }
        guard item == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: Constants.appName)
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Notch", action: #selector(open), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings…", action: #selector(settings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit \(Constants.appName)", action: #selector(quit), keyEquivalent: "q").target = self
        item.menu = menu
        self.item = item
    }

    @objc private func open() { openNotch() }
    @objc private func settings() { SettingsWindowController.shared.show() }
    @objc private func quit() { NSApp.terminate(nil) }
}
