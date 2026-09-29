import Foundation
import Security

/// Installs (on explicit user action) the Claude Code hooks that forward session events to the
/// notch. Existing hooks are preserved; a timestamped backup of settings.json is written first.
enum ClaudeHookInstaller {
    enum InstallError: LocalizedError {
        case unreadableSettings
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .unreadableSettings: "~/.claude/settings.json is not valid JSON, so it was left untouched."
            case .writeFailed(let reason): "Could not write the hook: \(reason)"
            }
        }
    }

    /// Per-install shared secret the hook script sends and the event server checks.
    static func token() -> String {
        let url = Constants.Paths.hookToken
        if let existing = try? String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           existing.count >= 32 {
            return existing
        }
        var bytes = [UInt8](repeating: 0, count: 24)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let token = bytes.map { String(format: "%02x", $0) }.joined()
        try? token.write(to: url, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return token
    }

    static var scriptContents: String {
        """
        #!/bin/sh
        # \(Constants.Agents.hookMarker): forwards Claude Code hook events to NotchNull.
        # Prints nothing and always exits 0 so it can never block or alter Claude Code.
        TTY_NAME=$(ps -o tty= -p "$PPID" 2>/dev/null | tr -d ' ')
        curl -s -m 1 -X POST \\
          -H "Content-Type: application/json" \\
          -H "X-NotchNull-Token: \(token())" \\
          -H "X-Term-Bundle: ${__CFBundleIdentifier:-}" \\
          -H "X-Term-Program: ${TERM_PROGRAM:-}" \\
          -H "X-TTY: $TTY_NAME" \\
          --data-binary @- "http://127.0.0.1:\(Constants.Agents.eventServerPort)/claude" >/dev/null 2>&1
        exit 0

        """
    }

    static var isInstalled: Bool {
        guard let settings = readSettings(), let hooks = settings["hooks"] as? [String: Any] else { return false }
        return Constants.Agents.hookEvents.allSatisfy { event in
            ((hooks[event] as? [[String: Any]]) ?? []).contains(where: isOurs)
        }
    }

    static func install() throws {
        let script = Constants.Paths.hookScript
        do {
            try scriptContents.write(to: script, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        } catch {
            throw InstallError.writeFailed(error.localizedDescription)
        }

        var settings = try settingsForWriting()
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for event in Constants.Agents.hookEvents {
            var entries = (hooks[event] as? [[String: Any]] ?? []).filter { !isOurs($0) }
            entries.append([
                "hooks": [["type": "command", "command": "\"\(script.path)\"", "timeout": 5]],
            ])
            hooks[event] = entries
        }
        settings["hooks"] = hooks
        try write(settings)
    }

    static func uninstall() throws {
        var settings = try settingsForWriting()
        guard var hooks = settings["hooks"] as? [String: Any] else { return }
        for event in Constants.Agents.hookEvents {
            let remaining = (hooks[event] as? [[String: Any]] ?? []).filter { !isOurs($0) }
            hooks[event] = remaining.isEmpty ? nil : remaining
        }
        settings["hooks"] = hooks
        try write(settings)
        try? FileManager.default.removeItem(at: Constants.Paths.hookScript)
    }

    private static func isOurs(_ entry: [String: Any]) -> Bool {
        let marker = "\(Constants.appName)/\(Constants.Paths.hookScript.lastPathComponent)"
        return ((entry["hooks"] as? [[String: Any]]) ?? []).contains {
            ($0["command"] as? String)?.contains(marker) == true
        }
    }

    private static func readSettings() -> [String: Any]? {
        guard let data = try? Data(contentsOf: Constants.Paths.claudeSettings) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func settingsForWriting() throws -> [String: Any] {
        let url = Constants.Paths.claudeSettings
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        guard let settings = readSettings() else { throw InstallError.unreadableSettings }
        return settings
    }

    private static func write(_ settings: [String: Any]) throws {
        let url = Constants.Paths.claudeSettings
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: url.path) {
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let backup = url.deletingLastPathComponent().appendingPathComponent("settings.json.notchnull-\(stamp).bak")
            try? fm.copyItem(at: url, to: backup)
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .withoutEscapingSlashes])
            try data.write(to: url, options: .atomic)
        } catch {
            throw InstallError.writeFailed(error.localizedDescription)
        }
    }
}
