import AppKit
import Combine
import CoreImage
import SwiftUI

struct NowPlaying: Equatable {
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var position: Double
    var sampledAt: Date
    var isPlaying: Bool
    var trackID: String
    /// App that owns playback (the browser for web media).
    var bundleID: String?
    var sourceName: String

    func elapsed(at date: Date) -> Double {
        guard isPlaying else { return position }
        return min(duration > 0 ? duration : .greatestFiniteMagnitude, position + date.timeIntervalSince(sampledAt))
    }
}

/// System-wide Now Playing. Primary source is the MediaRemote bridge (any player, including
/// browsers). If the bridge cannot run, Apple Music and Spotify are read through Apple Events.
@MainActor
final class NowPlayingService: ObservableObject {
    @Published private(set) var nowPlaying: NowPlaying?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var tint: Color = Theme.Accent.music
    @Published private(set) var automationDenied = false

    private var bridge: MediaRemoteBridge?
    private var usingBridge = false
    private let scriptQueue = DispatchQueue(label: "dev.notchnull.nowplaying", qos: .userInitiated)
    private var pollTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var cancellables: Set<AnyCancellable> = []
    private let preferences = Preferences.shared
    private var lastArtworkTrack: String?

    func start() {
        preferences.$musicWings
            .combineLatest(preferences.$musicEnabled)
            .sink { [weak self] _ in self?.updateActivity() }
            .store(in: &cancellables)
        preferences.$musicEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in enabled ? self?.startSources() : self?.stopSources() }
            .store(in: &cancellables)
    }

    /// Fixture entry point for snapshot rendering.
    func preview(_ state: NowPlaying?, artwork: NSImage?, tint: Color) {
        nowPlaying = state
        self.artwork = artwork
        self.tint = tint
    }

    private func startSources() {
        let bridge = MediaRemoteBridge(
            onUpdate: { [weak self] update in MainActor.assumeIsolated { self?.apply(update) } },
            onFailure: { [weak self] in MainActor.assumeIsolated { self?.fallBackToScripting() } }
        )
        self.bridge = bridge
        if bridge.isAvailable {
            usingBridge = true
            bridge.start()
        } else {
            fallBackToScripting()
        }
    }

    private func stopSources() {
        bridge?.stop()
        bridge = nil
        pollTimer?.invalidate()
        pollTimer = nil
        observers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        observers.removeAll()
        setState(nil)
    }

    // MARK: Controls

    func togglePlayPause() {
        guard var current = nowPlaying else { return }
        current.position = current.elapsed(at: Date())
        current.sampledAt = Date()
        current.isPlaying.toggle()
        withAnimation(Motion.state) { nowPlaying = current }
        updateActivity()
        if usingBridge { bridge?.send(.togglePlayPause) } else { script("playpause") }
    }

    func next() { usingBridge ? bridge?.send(.next) : script("next track") }
    func previous() { usingBridge ? bridge?.send(.previous) : script("previous track") }

    func seek(to fraction: Double) {
        guard var current = nowPlaying, current.duration > 0 else { return }
        let seconds = max(0, min(current.duration, current.duration * fraction))
        current.position = seconds
        current.sampledAt = Date()
        nowPlaying = current
        if usingBridge { bridge?.seek(to: seconds) } else { script("set player position to \(seconds)") }
    }

    func openPlayer() {
        guard let bundleID = nowPlaying?.bundleID else { return }
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            app.activate()
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    // MARK: Bridge updates

    private func apply(_ update: MediaRemoteBridge.Update) {
        guard preferences.musicEnabled else { return }
        guard !update.empty, !update.title.isEmpty else {
            setState(nil)
            return
        }
        let trackID = "\(update.bundleID ?? "")|\(update.title)|\(update.artist)"
        // MediaRemote reports elapsed time as of `timestamp`; project it to now while playing.
        var position = update.elapsed
        if update.playing, let stamp = update.timestamp {
            position += max(0, Date().timeIntervalSince(stamp))
        }
        let state = NowPlaying(
            title: update.title,
            artist: update.artist,
            album: update.album,
            duration: update.duration,
            position: position,
            sampledAt: Date(),
            isPlaying: update.playing,
            trackID: trackID,
            bundleID: update.bundleID,
            sourceName: Self.appName(for: update.bundleID)
        )
        setState(state)
        if let data = update.artwork, let image = NSImage(data: data) {
            setArtwork(image, for: trackID)
        } else if update.artworkCleared, lastArtworkTrack != trackID {
            setArtwork(nil, for: trackID)
        }
    }

    private func setState(_ state: NowPlaying?) {
        let changedTrack = state?.trackID != nowPlaying?.trackID
        if state != nowPlaying {
            withAnimation(changedTrack ? Motion.state : nil) { nowPlaying = state }
        }
        if state == nil, artwork != nil { setArtwork(nil, for: nil) }
        updateActivity()
    }

    private func setArtwork(_ image: NSImage?, for trackID: String?) {
        lastArtworkTrack = trackID
        let color = image.flatMap(Self.averageColor)
        withAnimation(.easeOut(duration: 0.35)) {
            artwork = image
            tint = color ?? Theme.Accent.music
        }
    }

    private func updateActivity() {
        let active = preferences.musicEnabled && preferences.musicWings && (nowPlaying?.isPlaying ?? false)
        ActivityCenter.shared.setPersistent(.music, active: active)
    }

    static func appName(for bundleID: String?) -> String {
        guard let bundleID else { return "Now Playing" }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let name = Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }
        if bundleID.hasPrefix("com.apple.WebKit") { return "Safari" }
        return bundleID.components(separatedBy: ".").last?.capitalized ?? bundleID
    }

    // MARK: Apple Events fallback (Music and Spotify only)

    private enum ScriptedPlayer: String, CaseIterable {
        case spotify = "Spotify", music = "Music"
        var bundleID: String { self == .music ? "com.apple.Music" : "com.spotify.client" }
    }

    private var scriptedPlayer: ScriptedPlayer?

    private func fallBackToScripting() {
        guard usingBridge || pollTimer == nil else { return }
        usingBridge = false
        Log.media.notice("Now Playing bridge unavailable; using Apple Events for Music and Spotify")
        let center = DistributedNotificationCenter.default()
        for name in ["com.apple.Music.playerInfo", "com.spotify.client.PlaybackStateChanged"] {
            observers.append(center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.poll() }
            })
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: Constants.Intervals.mediaPoll * 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        poll()
    }

    private func poll() {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let players = ScriptedPlayer.allCases.filter { running.contains($0.bundleID) }
        guard !players.isEmpty else {
            setState(nil)
            return
        }
        scriptQueue.async {
            var best: (NowPlaying, ScriptedPlayer)?
            var denied = false
            for player in players {
                switch Self.readState(player) {
                case .success(let state?):
                    if best == nil || (state.isPlaying && best?.0.isPlaying == false) { best = (state, player) }
                case .success(nil):
                    break
                case .failure(let error):
                    if error.code == -1743 { denied = true }
                }
            }
            let artworkData = best.flatMap { $0.1 == .music ? Self.musicArtworkData() : nil }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.automationDenied = denied
                    self.scriptedPlayer = best?.1
                    self.setState(best?.0)
                    if let best, self.lastArtworkTrack != best.0.trackID {
                        self.setArtwork(artworkData.flatMap(NSImage.init(data:)), for: best.0.trackID)
                    }
                }
            }
        }
    }

    private func script(_ command: String) {
        guard let player = scriptedPlayer else { return }
        let source = "if application \"\(player.rawValue)\" is running then tell application \"\(player.rawValue)\" to \(command)"
        scriptQueue.async {
            _ = Self.run(source)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { MainActor.assumeIsolated { self.poll() } }
        }
    }

    private struct ScriptError: Error { let code: Int }

    private nonisolated static func run(_ source: String) -> Result<NSAppleEventDescriptor, ScriptError> {
        guard let script = NSAppleScript(source: source) else { return .failure(ScriptError(code: -1)) }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error { return .failure(ScriptError(code: (error[NSAppleScript.errorNumber] as? Int) ?? -1)) }
        return .success(result)
    }

    private nonisolated static func readState(_ player: ScriptedPlayer) -> Result<NowPlaying?, ScriptError> {
        let separator = "‖"
        let durationExpression = player == .spotify ? "((duration of t) / 1000)" : "(duration of t)"
        let idExpression = player == .spotify ? "(id of t)" : "(persistent ID of t)"
        let body = """
        tell application "\(player.rawValue)"
            set st to player state as string
            if st is "stopped" then return "stopped"
            set t to current track
            return st & "\(separator)" & (name of t) & "\(separator)" & (artist of t) & "\(separator)" & (album of t) & "\(separator)" & \(durationExpression) & "\(separator)" & (player position) & "\(separator)" & \(idExpression)
        end tell
        """
        let script = "if application \"\(player.rawValue)\" is running then\n\(body)\nend if\nreturn \"none\""
        return run(script).map { descriptor in
            guard let text = descriptor.stringValue, text != "none", text != "stopped" else { return nil }
            let parts = text.components(separatedBy: separator)
            guard parts.count >= 7 else { return nil }
            return NowPlaying(
                title: parts[1], artist: parts[2], album: parts[3],
                duration: Double(parts[4].replacingOccurrences(of: ",", with: ".")) ?? 0,
                position: Double(parts[5].replacingOccurrences(of: ",", with: ".")) ?? 0,
                sampledAt: Date(), isPlaying: parts[0] == "playing",
                trackID: parts[6], bundleID: player.bundleID, sourceName: player.rawValue
            )
        }
    }

    private nonisolated static func musicArtworkData() -> Data? {
        let script = "if application \"Music\" is running then tell application \"Music\" to return raw data of artwork 1 of current track"
        guard case .success(let descriptor) = run(script) else { return nil }
        return descriptor.data
    }

    // MARK: Color

    /// Average artwork color, lifted so it reads as light on the black notch.
    private static func averageColor(of image: NSImage) -> Color? {
        guard let tiff = image.tiffRepresentation, let input = CIImage(data: tiff) else { return nil }
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: input,
            kCIInputExtentKey: CIVector(cgRect: input.extent),
        ])
        guard let output = filter?.outputImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()]).render(
            output, toBitmap: &pixel, rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil
        )
        let base = NSColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255, blue: CGFloat(pixel[2]) / 255, alpha: 1)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        base.usingColorSpace(.deviceRGB)?.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let lifted = NSColor(hue: hue, saturation: min(1, max(0.45, saturation * 1.3)), brightness: max(0.85, brightness), alpha: 1)
        return Color(nsColor: lifted)
    }
}
