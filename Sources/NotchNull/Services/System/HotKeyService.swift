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
