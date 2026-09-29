import AppKit
import Carbon.HIToolbox
import Combine

/// A key plus modifiers, stored the way Carbon registers global hot keys.
struct KeyShortcut: Equatable {
    let keyCode: UInt32
    let modifiers: NSEvent.ModifierFlags
    /// What the key prints, captured when the shortcut is recorded (layout aware).
    let key: String

    static let clipboardDefault = KeyShortcut(keyCode: UInt32(kVK_ANSI_V), modifiers: [.control, .command], key: "V")

    static let relevantModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.relevantModifiers)
        self.key = key
    }

    /// Builds a shortcut from a key press; plain keys and Shift-only combinations are rejected
    /// because they would swallow ordinary typing everywhere.
    init?(event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(Self.relevantModifiers)
        guard !modifiers.subtracting(.shift).isEmpty else { return nil }
        self.init(keyCode: UInt32(event.keyCode), modifiers: modifiers, key: Self.label(for: event))
    }

    init?(dictionary: [String: Any]) {
        guard let code = dictionary["keyCode"] as? Int,
              let flags = dictionary["modifiers"] as? Int,
              let key = dictionary["key"] as? String else { return nil }
        self.init(keyCode: UInt32(code), modifiers: NSEvent.ModifierFlags(rawValue: UInt(flags)), key: key)
    }

    var dictionary: [String: Any] {
        ["keyCode": Int(keyCode), "modifiers": Int(modifiers.rawValue), "key": key]
    }

    /// "⌃⌥⇧⌘V", in the order macOS menus use.
    var display: String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text + key
    }

    /// Text form used in settings.json: "ctrl+cmd+v", "opt+shift+space", "cmd+f5".
    var string: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("ctrl") }
        if modifiers.contains(.option) { parts.append("opt") }
        if modifiers.contains(.shift) { parts.append("shift") }
        if modifiers.contains(.command) { parts.append("cmd") }
        let name = Self.textKeys.first { $0.value == Int(keyCode) }?.key ?? key.lowercased()
        return (parts + [name]).joined(separator: "+")
    }

    init?(string: String) {
        let parts = string.lowercased().split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let keyName = parts.last, let code = Self.textKeys[keyName] else { return nil }
        var modifiers: NSEvent.ModifierFlags = []
        for part in parts.dropLast() {
            switch part {
            case "ctrl", "control", "⌃": modifiers.insert(.control)
            case "opt", "option", "alt", "⌥": modifiers.insert(.option)
            case "shift", "⇧": modifiers.insert(.shift)
            case "cmd", "command", "⌘": modifiers.insert(.command)
            default: return nil
            }
        }
        guard !modifiers.subtracting(.shift).isEmpty else { return nil }
        let label = Self.namedKeys[code] ?? keyName.uppercased()
        self.init(keyCode: UInt32(code), modifiers: modifiers, key: label)
    }

    /// Key names for the text form, on the ANSI layout.
    private static let textKeys: [String: Int] = {
        var keys: [String: Int] = [
            "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D, "e": kVK_ANSI_E, "f": kVK_ANSI_F,
            "g": kVK_ANSI_G, "h": kVK_ANSI_H, "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
            "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P, "q": kVK_ANSI_Q, "r": kVK_ANSI_R,
            "s": kVK_ANSI_S, "t": kVK_ANSI_T, "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
            "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
            "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3, "4": kVK_ANSI_4,
            "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8, "9": kVK_ANSI_9,
            "space": kVK_Space, "return": kVK_Return, "tab": kVK_Tab, "delete": kVK_Delete,
            "left": kVK_LeftArrow, "right": kVK_RightArrow, "up": kVK_UpArrow, "down": kVK_DownArrow,
        ]
        let functionKeys = [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12]
        for (index, code) in functionKeys.enumerated() { keys["f\(index + 1)"] = code }
        return keys
    }()

    var carbonModifiers: UInt32 {
        var flags: UInt32 = 0
        if modifiers.contains(.control) { flags |= UInt32(controlKey) }
        if modifiers.contains(.option) { flags |= UInt32(optionKey) }
        if modifiers.contains(.shift) { flags |= UInt32(shiftKey) }
        if modifiers.contains(.command) { flags |= UInt32(cmdKey) }
        return flags
    }

    private static let namedKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    private static func label(for event: NSEvent) -> String {
        if let name = namedKeys[Int(event.keyCode)] { return name }
        let characters = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return characters.isEmpty ? "#\(event.keyCode)" : characters.uppercased()
    }
}

/// Registers the Clipboard shortcut system-wide with Carbon, which needs no Accessibility access.
@MainActor
final class HotKeyService {
    static let shared = HotKeyService()

    /// Called on the main thread when the registered shortcut is pressed.
    var onClipboardShortcut: (() -> Void)?

    private static let signature: OSType = 0x4E4E_4B59 // "NNKY"
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var suspended = false
    private var cancellables: Set<AnyCancellable> = []

    func start() {
        installHandler()
        Preferences.shared.$clipboardShortcut
            .receive(on: RunLoop.main)
            .sink { [weak self] shortcut in self?.register(shortcut) }
            .store(in: &cancellables)
    }

    /// Releases the shortcut while Settings records a new one, so the old combination reaches the recorder.
    func setSuspended(_ suspended: Bool) {
        self.suspended = suspended
        register(Preferences.shared.clipboardShortcut)
    }

    private func register(_ shortcut: KeyShortcut?) {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        guard let shortcut, !suspended else { return }
        let id = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, id, GetApplicationEventTarget(), 0, &hotKey)
        if status != noErr {
            Log.system.error("Clipboard shortcut \(shortcut.display, privacy: .public) could not be registered: \(status)")
        } else {
            Log.system.info("Clipboard shortcut \(shortcut.display, privacy: .public) registered")
        }
    }

    private func installHandler() {
        guard handler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { HotKeyService.shared.onClipboardShortcut?() }
            }
            return noErr
        }, 1, &eventType, nil, &handler)
    }
}
