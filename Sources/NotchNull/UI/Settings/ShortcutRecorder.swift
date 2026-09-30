import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Click, then press a key combination. Escape cancels; Delete clears the shortcut.
struct ShortcutRecorder: View {
    @Binding var shortcut: KeyShortcut?
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button(action: toggleRecording) {
                Text(label)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(recording || shortcut == nil ? Theme.Palette.textSecondary : Theme.Palette.textPrimary)
                    .frame(minWidth: 96)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(recording ? "Recording shortcut" : "Clipboard shortcut \(shortcut?.display ?? "off")")
            if shortcut != nil, !recording {
                Button {
                    shortcut = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                .buttonStyle(.borderless)
                .help("Turn the shortcut off")
                .accessibilityLabel("Turn the shortcut off")
            }
        }
        .onDisappear(perform: stop)
    }

    private var label: String {
        if recording { return "Type shortcut…" }
        return shortcut?.display ?? "Record shortcut"
    }

    private func toggleRecording() {
        recording ? stop() : start()
    }

    private func start() {
        recording = true
        HotKeyService.shared.setSuspended(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let code = Int(event.keyCode)
            let plain = event.modifierFlags.intersection(KeyShortcut.relevantModifiers).isEmpty
            if code == kVK_Escape {
                stop()
            } else if plain, code == kVK_Delete || code == kVK_ForwardDelete {
                shortcut = nil
                stop()
            } else if let recorded = KeyShortcut(event: event) {
                shortcut = recorded
                stop()
            }
            // Plain keys are swallowed without recording: a shortcut needs ⌘, ⌃ or ⌥.
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording { HotKeyService.shared.setSuspended(false) }
        recording = false
    }
}
