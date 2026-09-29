import AppKit
import ApplicationServices

/// Deep links into System Settings and permission checks used by inline "Allow" controls.
enum Permissions {
    enum Pane: String {
        case accessibility = "Privacy_Accessibility"
        case automation = "Privacy_Automation"
        case calendars = "Privacy_Calendars"
        case camera = "Privacy_Camera"
        case bluetooth = "Privacy_Bluetooth"
        case filesAndFolders = "Privacy_FilesAndFolders"
        case screenRecording = "Privacy_ScreenCapture"
    }

    static var accessibilityGranted: Bool { AXIsProcessTrusted() }

    /// Shows the system Accessibility prompt (which also adds the app to the list).
    static func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func open(_ pane: Pane) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane.rawValue)") else { return }
        NSWorkspace.shared.open(url)
    }
}
