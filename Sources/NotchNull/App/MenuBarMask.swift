import AppKit
import Combine

/// "Hide the notch": a black band drawn just below the menu bar's window level, so the menu bar
/// reads as solid black and the camera housing disappears into it. Menu items stay on top and
/// clicks pass through. Only screens with a hardware notch get a band.
@MainActor
final class MenuBarMask {
    private var windows: [NSWindow] = []
    private var cancellables: Set<AnyCancellable> = []

    func start() {
        Preferences.shared.$hideNotch
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in self?.rebuild(enabled: enabled) }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.rebuild(enabled: Preferences.shared.hideNotch) }
            .store(in: &cancellables)
    }

    private func rebuild(enabled: Bool) {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        guard enabled else { return }
        for screen in NSScreen.screens where screen.safeAreaInsets.top > 0 {
            let height = max(screen.safeAreaInsets.top, screen.frame.maxY - screen.visibleFrame.maxY)
            let frame = CGRect(x: screen.frame.minX, y: screen.frame.maxY - height, width: screen.frame.width, height: height)
            let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            window.alphaValue = 0
            window.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                window.animator().alphaValue = 1
            }
            windows.append(window)
        }
    }
}
