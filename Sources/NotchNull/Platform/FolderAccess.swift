import Foundation

/// Opens a protected folder to watch it without ever making the main thread wait.
///
/// The first access to ~/Downloads after an install or update waits on a macOS permission prompt,
/// and `open` does not return until it is answered. Done on the main thread, that froze launch
/// before any window existed, so no notch appeared until the prompt was dealt with.
enum FolderAccess {
    /// Calls `completion` on the main thread with a descriptor for change events, or -1 when the
    /// folder cannot be read (access denied or missing).
    static func openForEvents(_ folder: URL, completion: @escaping @MainActor (Int32) -> Void) {
        let path = folder.path
        DispatchQueue.global(qos: .utility).async {
            let descriptor = open(path, O_EVTONLY)
            DispatchQueue.main.async { MainActor.assumeIsolated { completion(descriptor) } }
        }
    }
}
