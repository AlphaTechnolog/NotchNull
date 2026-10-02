import Foundation

/// Files arriving by AirDrop. They land in ~/Downloads carrying a quarantine record written by
/// sharingd, which is how they are told apart from browser downloads.
@MainActor
final class AirDropWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var known: Set<String> = []

    func start() {
        let folder = Constants.Paths.downloads
        FolderAccess.openForEvents(folder) { [weak self] descriptor in
            guard descriptor >= 0 else { return }
            guard let self, self.source == nil else {
                close(descriptor)
                return
            }
            self.known = Set(Self.names(in: folder))
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename], queue: .main)
            source.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.scan() } }
            source.setCancelHandler { close(descriptor) }
            source.resume()
            self.source = source
        }
    }

    private func scan() {
        let folder = Constants.Paths.downloads
        let names = Set(Self.names(in: folder))
        let added = names.subtracting(known)
        known = names
        for name in added {
            let url = folder.appendingPathComponent(name)
            guard Self.isAirDrop(url) else { continue }
            DeviceEvents.shared.announce(DeviceEvent(change: .received, name: "AirDrop", symbol: "square.and.arrow.down.on.square.fill", detail: name, action: .reveal(url)))
        }
    }

    private static func names(in folder: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
    }

    /// Quarantine records look like `0083;66f1a2b3;sharingd;UUID`; the third field is the agent.
    nonisolated static func isAirDrop(_ url: URL) -> Bool {
        let name = "com.apple.quarantine"
        let length = getxattr(url.path, name, nil, 0, 0, 0)
        guard length > 0 else { return false }
        var buffer = [UInt8](repeating: 0, count: length)
        guard getxattr(url.path, name, &buffer, length, 0, 0) == length else { return false }
        return isAirDropQuarantine(String(decoding: buffer, as: UTF8.self))
    }

    nonisolated static func isAirDropQuarantine(_ record: String) -> Bool {
        let fields = record.split(separator: ";", omittingEmptySubsequences: false)
        guard fields.count >= 3 else { return false }
        let agent = fields[2].lowercased()
        return agent == "sharingd" || agent == "airdrop"
    }
}
