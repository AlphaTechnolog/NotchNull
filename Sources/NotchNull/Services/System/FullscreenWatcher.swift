import AppKit
import Combine

/// A window as far as fullscreen detection cares: who owns it, its layer and its size.
struct FullscreenWindow: Equatable {
    var owner: String
    var pid: Int32
    var layer: Int
    var width: CGFloat
    var height: CGFloat
}

/// A display as far as fullscreen detection cares: its ID and its size.
struct FullscreenScreen: Equatable {
    var id: CGDirectDisplayID
    var width: CGFloat
    var height: CGFloat
}

/// Publishes which displays currently have a fullscreen app covering them. A window counts
/// as fullscreen when it sits on the normal window layer and its size matches the display
/// size; each display is evaluated independently, so a fullscreen app on display 1 hides
/// only that display's notch.
///
/// The check is event-driven first (app activation, Space change, display change) with a
/// slow timer as a backstop for transitions that post no notification (e.g. in-app video
/// fullscreen). The window-list query only reads bounds/owner/layer, which needs no
/// Screen Recording permission, and the timer stops while the setting is off.
@MainActor
final class FullscreenWatcher: ObservableObject {
    @Published private(set) var fullscreenDisplayIDs: Set<CGDirectDisplayID> = []

    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var settingCancellable: AnyCancellable?
    private var lastPublished: Set<CGDirectDisplayID>?

    /// Window owners that cover the screen but are not apps (menu bar, wallpaper, overlays).
    static let excludedOwners: Set<String> = [
        "Dock", "Window Server", "Control Center", "Notification Center",
        "Wallpaper", "ScreenSaverEngine", "loginwindow",
    ]

    /// Size slop in points: fullscreen windows should match the display exactly, but allow
    /// rounding differences between Quartz and Cocoa coordinates.
    static let sizeTolerance: CGFloat = 1

    func start() {
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        observers = [
            center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            },
            workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            },
            workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            },
        ]
        settingCancellable = Preferences.shared.$hideOnFullscreen
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateTimer() }
        updateTimer()
        refresh()
    }

    private func updateTimer() {
        timer?.invalidate()
        timer = nil
        guard Preferences.shared.hideOnFullscreen else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Constants.Intervals.fullscreenPoll, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    /// Re-reads the on-screen window list and publishes the fullscreen display set.
    func refresh() {
        guard Preferences.shared.hideOnFullscreen else {
            if fullscreenDisplayIDs.isEmpty == false { fullscreenDisplayIDs = [] }
            lastPublished = []
            return
        }
        let windows = Self.currentWindows()
        let screens = Self.currentScreens()
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let next = Self.fullscreenDisplayIDs(windows: windows, screens: screens, ownPID: ownPID)
        guard next != lastPublished else { return }
        lastPublished = next
        fullscreenDisplayIDs = next
    }

    private static func currentScreens() -> [FullscreenScreen] {
        NSScreen.screens.map { screen in
            FullscreenScreen(
                id: NotchGeometry.screenID(screen),
                width: screen.frame.width,
                height: screen.frame.height
            )
        }
    }

    private static func currentWindows() -> [FullscreenWindow] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        var result: [FullscreenWindow] = []
        result.reserveCapacity(list.count)
        for entry in list {
            guard let bounds = entry[kCGWindowBounds as String] as? [String: Any],
                  let width = (bounds["Width"] as? NSNumber)?.doubleValue,
                  let height = (bounds["Height"] as? NSNumber)?.doubleValue
            else { continue }
            let layer = (entry[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            let owner = entry[kCGWindowOwnerName as String] as? String ?? ""
            let pid = (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? 0
            result.append(FullscreenWindow(owner: owner, pid: pid, layer: layer, width: CGFloat(width), height: CGFloat(height)))
        }
        return result
    }

    /// Pure matcher, unit-tested: which screens have a normal-layer window covering them.
    static func fullscreenDisplayIDs(
        windows: [FullscreenWindow],
        screens: [FullscreenScreen],
        ownPID: Int32
    ) -> Set<CGDirectDisplayID> {
        var result: Set<CGDirectDisplayID> = []
        for screen in screens {
            for window in windows {
                guard window.layer == 0,
                      window.pid != ownPID,
                      !excludedOwners.contains(window.owner),
                      abs(window.width - screen.width) <= sizeTolerance,
                      abs(window.height - screen.height) <= sizeTolerance
                else { continue }
                result.insert(screen.id)
                break
            }
        }
        return result
    }
}
