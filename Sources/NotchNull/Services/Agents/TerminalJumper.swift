import AppKit

/// Brings the terminal that hosts an agent session to the front, selecting the exact tab by TTY
/// in Terminal and iTerm2.
enum TerminalJumper {
    static func canJump(to session: AgentSession) -> Bool {
        session.terminalBundleID != nil
    }

    /// The name of the app a session runs in ("Ghostty", "Terminal", "Visual Studio Code").
    @MainActor
    static func appName(for session: AgentSession) -> String? {
        guard let bundleID = session.terminalBundleID else { return nil }
        if let cached = appNames[bundleID] { return cached }
        let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
        appNames[bundleID] = name
        return name
    }

    @MainActor private static var appNames: [String: String] = [:]

    static func jump(to session: AgentSession) {
        guard let bundleID = session.terminalBundleID else { return }
        let device = session.tty.map { $0.hasPrefix("/dev/") ? $0 : "/dev/\($0)" }
        DispatchQueue.global(qos: .userInitiated).async {
            var selected = false
            if let device {
                switch bundleID {
                case "com.apple.Terminal": selected = runScript(terminalScript(device))
                case "com.googlecode.iterm2": selected = runScript(itermScript(device))
                default: break
                }
            }
            DispatchQueue.main.async {
                if !selected { activate(bundleID) }
            }
        }
    }

    private static func activate(_ bundleID: String) {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            app.activate()
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private static func runScript(_ source: String) -> Bool {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil && result?.booleanValue == true
    }

    private static func terminalScript(_ tty: String) -> String {
        """
        if application "Terminal" is running then
            tell application "Terminal"
                repeat with w in windows
                    repeat with t in tabs of w
                        if tty of t is "\(tty)" then
                            set selected of t to true
                            set index of w to 1
                            activate
                            return true
                        end if
                    end repeat
                end repeat
            end tell
        end if
        return false
        """
    }

    private static func itermScript(_ tty: String) -> String {
        """
        if application "iTerm2" is running then
            tell application "iTerm2"
                repeat with w in windows
                    repeat with t in tabs of w
                        repeat with s in sessions of t
                            if tty of s is "\(tty)" then
                                select w
                                select t
                                select s
                                activate
                                return true
                            end if
                        end repeat
                    end repeat
                end repeat
            end tell
        end if
        return false
        """
    }
}
