import AppKit

/// Hardware notch measurements for a screen, with a virtual notch for displays without one.
struct NotchGeometry: Equatable {
    let screenFrame: CGRect
    let notchSize: CGSize
    let hasHardwareNotch: Bool

    init(screen: NSScreen) {
        screenFrame = screen.frame
        let topInset = screen.safeAreaInsets.top
        if topInset > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let width = screen.frame.width - left.width - right.width
            notchSize = CGSize(width: width, height: topInset)
            hasHardwareNotch = true
        } else {
            let menuBar = max(NSStatusBar.system.thickness, screen.frame.maxY - screen.visibleFrame.maxY)
            notchSize = CGSize(width: Theme.Size.virtualNotch.width, height: max(menuBar, 24))
            hasHardwareNotch = false
        }
    }

    init(screenFrame: CGRect, notchSize: CGSize, hasHardwareNotch: Bool) {
        self.screenFrame = screenFrame
        self.notchSize = notchSize
        self.hasHardwareNotch = hasHardwareNotch
    }

    /// Window frame reserving the whole animation canvas, pinned to the top center of the screen.
    var windowFrame: CGRect {
        let size = Theme.Size.canvas
        return CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    /// Screen-space rect of a body of the given size at the top center, `top` points below the
    /// screen's top edge (0 for the notch, the island's gap otherwise).
    func bodyRect(for size: CGSize, top: CGFloat = 0) -> CGRect {
        CGRect(x: screenFrame.midX - size.width / 2, y: screenFrame.maxY - top - size.height, width: size.width, height: size.height)
    }

    static func screenID(_ screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
    }

    static func isBuiltIn(_ screen: NSScreen) -> Bool {
        CGDisplayIsBuiltin(screenID(screen)) != 0
    }
}
