import Foundation

/// Runs NowPlayingBridge.dylib inside `/usr/bin/perl`, the one process macOS still lets read the
/// system-wide Now Playing state on macOS 15.4+. Streams updates for any player: Music, Spotify,
/// Safari, Chrome, YouTube, Podcasts…
final class MediaRemoteBridge {
    struct Update {
        var empty = false
        var title = ""
        var artist = ""
        var album = ""
        var duration: Double = 0
        var elapsed: Double = 0
        var timestamp: Date?
        var playing = false
        var bundleID: String?
        var artwork: Data?
        var artworkCleared = false
    }

    enum Command: Int {
        case play = 0, pause = 1, togglePlayPause = 2, next = 4, previous = 5
    }

    private var process: Process?
    private var buffer = Data()
    private let queue = DispatchQueue(label: "dev.notchnull.media-bridge")
    private let onUpdate: (Update) -> Void
    private let onFailure: () -> Void
    private var restarts = 0

    init(onUpdate: @escaping (Update) -> Void, onFailure: @escaping () -> Void) {
        self.onUpdate = onUpdate
        self.onFailure = onFailure
    }

    static var resources: (library: URL, script: URL)? {
        let candidates = [
            Bundle.main.resourceURL,
            URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("build/bridge"),
        ].compactMap { $0 }
        for base in candidates {
            let library = base.appendingPathComponent("NowPlayingBridge.dylib")
            let script = base.appendingPathComponent("now-playing.pl")
            if FileManager.default.fileExists(atPath: library.path), FileManager.default.fileExists(atPath: script.path) {
                return (library, script)
            }
        }
        return nil
    }

    var isAvailable: Bool { Self.resources != nil }

    func start() {
        guard let resources = Self.resources else {
            onFailure()
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [resources.script.path, resources.library.path, "notchnull_stream"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        // stdin stays open for the bridge's lifetime; when NotchNull exits it closes and the bridge quits.
        process.standardInput = Pipe()
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let self, !data.isEmpty else { return }
            self.queue.async { self.consume(data) }
        }
        process.terminationHandler = { [weak self] finished in
            guard let self else { return }
            Log.media.notice("Now Playing bridge exited with \(finished.terminationStatus)")
            DispatchQueue.main.async {
                self.restarts += 1
                if self.restarts <= 3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.start() }
                } else {
                    self.onFailure()
                }
            }
        }
        do {
            try process.run()
            self.process = process
            Log.media.info("Now Playing bridge started")
        } catch {
            Log.media.error("Now Playing bridge failed to start: \(error.localizedDescription, privacy: .public)")
            onFailure()
        }
    }

    func stop() {
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
    }

    func send(_ command: Command) {
        run(environment: ["NOTCHNULL_MR_COMMAND": String(command.rawValue)])
    }

    func seek(to seconds: Double) {
        run(environment: ["NOTCHNULL_MR_SEEK": String(seconds)])
    }

    private func run(environment: [String: String]) {
        guard let resources = Self.resources else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [resources.script.path, resources.library.path, "notchnull_command"]
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { $1 }
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            guard let json = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            if json["error"] != nil {
                DispatchQueue.main.async { self.onFailure() }
                continue
            }
            var update = Update()
            update.empty = json["empty"] as? Bool ?? false
            update.title = json["title"] as? String ?? ""
            update.artist = json["artist"] as? String ?? ""
            update.album = json["album"] as? String ?? ""
            update.duration = (json["duration"] as? NSNumber)?.doubleValue ?? 0
            update.elapsed = (json["elapsed"] as? NSNumber)?.doubleValue ?? 0
            update.timestamp = (json["timestamp"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
            update.playing = (json["playing"] as? NSNumber)?.boolValue ?? false
            update.bundleID = json["bundle"] as? String
            update.artwork = (json["artwork"] as? String).flatMap { Data(base64Encoded: $0) }
            update.artworkCleared = json["noArtwork"] as? Bool ?? false
            DispatchQueue.main.async {
                // A bridge that delivers data is healthy again; only back-to-back crashes count.
                self.restarts = 0
                self.onUpdate(update)
            }
        }
    }
}
