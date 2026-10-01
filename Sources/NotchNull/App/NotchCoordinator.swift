import AppKit
import Combine

/// Keeps one notch window per eligible screen, following display changes and the display preference.
@MainActor
final class NotchCoordinator {
    private let services: AppServices
    private var controllers: [CGDirectDisplayID: NotchWindowController] = [:]
    private var cancellables: Set<AnyCancellable> = []

    init(services: AppServices) {
        self.services = services
    }

    func start() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.rebuild() }
            .store(in: &cancellables)
        Preferences.shared.$displayMode
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in DispatchQueue.main.async { self?.rebuild() } }
            .store(in: &cancellables)
        services.fullscreen.$fullscreenDisplayIDs
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyFullscreenHiding() }
            .store(in: &cancellables)
        Preferences.shared.$hideOnFullscreen
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyFullscreenHiding() }
            .store(in: &cancellables)
        rebuild()
    }

    var primaryModel: NotchViewModel? { primaryController?.model }

    private var primaryController: NotchWindowController? {
        controllers.values.first { $0.model.geometry.hasHardwareNotch } ?? controllers.values.first
    }

    /// Clipboard shortcut handler.
    func toggleClipboard() {
        guard Preferences.shared.clipboardEnabled, !Preferences.shared.hiddenTabs.contains(NotchTab.clipboard.rawValue) else { return }
        primaryController?.toggleClipboardFromKeyboard()
    }

    private func eligibleScreens() -> [NSScreen] {
        let screens = NSScreen.screens
        switch Preferences.shared.displayMode {
        case .all:
            return screens
        case .main:
            return NSScreen.main.map { [$0] } ?? Array(screens.prefix(1))
        case .builtIn:
            if let builtIn = screens.first(where: NotchGeometry.isBuiltIn) { return [builtIn] }
            return NSScreen.main.map { [$0] } ?? Array(screens.prefix(1))
        }
    }

    private func rebuild() {
        let screens = eligibleScreens()
        let wanted = Dictionary(uniqueKeysWithValues: screens.map { (NotchGeometry.screenID($0), $0) })
        for (id, controller) in controllers {
            let current = wanted[id].map(NotchGeometry.init(screen:))
            if current == nil || current != controller.model.geometry {
                controller.tearDown()
                controllers[id] = nil
            }
        }
        for (id, screen) in wanted where controllers[id] == nil {
            controllers[id] = NotchWindowController(screen: screen, services: services)
        }
        applyFullscreenHiding()
    }

    /// Hides each display's notch independently while a fullscreen app covers that display.
    private func applyFullscreenHiding() {
        let enabled = Preferences.shared.hideOnFullscreen
        let fullscreen = services.fullscreen.fullscreenDisplayIDs
        for (id, controller) in controllers {
            controller.setFullscreenHidden(enabled && fullscreen.contains(id))
        }
    }
}
