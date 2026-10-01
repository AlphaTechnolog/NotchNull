import AppKit
import CryptoKit
import Foundation

/// Finds new releases on GitHub and installs them in place. Only the app bundle is replaced:
/// ~/.notchnull, Application Support and the stored settings are never touched, and the first
/// launch of the new version backs up ~/.notchnull before it rewrites anything there.
@MainActor
final class UpdateService: ObservableObject {
    static let shared = UpdateService()

    struct Release: Equatable {
        let version: AppVersion
        let page: URL
        /// The app's zip, when the release has one in the expected place.
        let asset: URL?
        /// GitHub's SHA-256 of that zip, lowercase hex.
        let sha256: String?
    }

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(Release)
        case downloading(Release)
        case installing(Release)
        case failed(String)
    }

    enum UpdateError: LocalizedError {
        case http(Int)
        case unreadable
        case noAsset
        case notAnApp
        case checksum
        case wrongApp(String)
        case signature
        case tool(String)

        var errorDescription: String? {
            switch self {
            case .http(403), .http(429): "GitHub is limiting requests from this network right now. Try again in a while."
            case .http(let code): "GitHub answered \(code)."
            case .unreadable: "Could not read the release from GitHub."
            case .noAsset: "That release has no \(Constants.Updates.assetName) to install. Get it from the Releases page."
            case .notAnApp: "This copy is not an app NotchNull can replace (it runs from a build folder or a read-only place). Get the new version from the Releases page."
            case .checksum: "The download does not match the checksum GitHub published, so it was not installed."
            case .wrongApp(let found): "The download is not the expected NotchNull release (\(found)), so it was not installed."
            case .signature: "The downloaded app's signature is broken, so it was not installed."
            case .tool(let detail): "Could not install the update: \(detail)"
            }
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastChecked: Date?

    private var timer: Timer?
    private let defaults = UserDefaults.standard
    private static let lastCheckedKey = "updateLastChecked", announcedKey = "updateAnnouncedVersion"

    var current: AppVersion { AppVersion.current }

    /// The release waiting to be installed, in any of the states that have one.
    var pending: Release? {
        switch state {
        case .available(let release), .downloading(let release), .installing(let release): release
        default: nil
        }
    }

    var isBusy: Bool {
        switch state {
        case .checking, .downloading, .installing: true
        default: false
        }
    }

    func start() {
        lastChecked = defaults.object(forKey: Self.lastCheckedKey) as? Date
        timer = Timer.scheduledTimer(withTimeInterval: Constants.Updates.schedulerTick, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Updates.launchDelay) { [weak self] in
            self?.checkIfDue()
        }
    }

    /// Fixture entry point for snapshot rendering.
    func preview(_ state: State) {
        self.state = state
    }

    private func checkIfDue() {
        guard Preferences.shared.checkForUpdates, !isBusy, pending == nil else { return }
        if let lastChecked, Date().timeIntervalSince(lastChecked) < Constants.Updates.checkEvery { return }
        Task { await check() }
    }

    /// Asks GitHub for the latest release. Sends nothing but the request itself.
    func check() async {
        guard !isBusy else { return }
        state = .checking
        do {
            var request = URLRequest(url: Constants.Updates.latestRelease, timeoutInterval: Constants.Updates.requestTimeout)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await Self.session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else { throw UpdateError.http(status) }
            guard let release = Self.parseRelease(data) else { throw UpdateError.unreadable }
            lastChecked = Date()
            defaults.set(lastChecked, forKey: Self.lastCheckedKey)
            if release.version > current {
                state = .available(release)
                announce(release)
            } else {
                state = .upToDate
            }
        } catch {
            state = .failed(error.localizedDescription)
            Log.app.error("Update check failed: \(error.localizedDescription, privacy: .public)")
        }
        NotchStatus.write()
    }

    /// Downloads the pending release, checks it, puts it where this app is and relaunches.
    func install() async {
        guard case .available(let release) = state else { return }
        do {
            guard let asset = release.asset else { throw UpdateError.noAsset }
            let target = try Self.installTarget()
            state = .downloading(release)
            let (download, response) = try await Self.session.download(from: asset)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else { throw UpdateError.http(status) }
            state = .installing(release)
            try await Task.detached(priority: .userInitiated) {
                let staged = try Self.stage(zip: download, expecting: release, near: target)
                try Self.swap(staged, into: target)
            }.value
            Log.app.info("Updated to \(release.version.description, privacy: .public); relaunching")
            Self.relaunch(target)
        } catch {
            state = .failed(error.localizedDescription)
            Log.app.error("Update failed: \(error.localizedDescription, privacy: .public)")
            NotchStatus.write()
        }
    }

    /// One banner per new version, so a release never nags.
    private func announce(_ release: Release) {
        let version = release.version.description
        guard defaults.string(forKey: Self.announcedKey) != version else { return }
        defaults.set(version, forKey: Self.announcedKey)
        let payload: JSONValue = .object([
            "id": .string("notchnull-update"),
            "symbol": .string("arrow.down.circle.fill"),
            "tint": .string("accent"),
            "title": .string("\(Constants.appName) \(version) is available"),
            "subtitle": .string("Update in Settings › About"),
            "duration": .number(Constants.Updates.availableBanner),
        ])
        if let activity = CustomActivity(payload: payload) { CustomActivityStore.shared.set(activity) }
    }

    /// What `GET /v1/update`, status.json and `notchnull update` report.
    var summary: JSONValue {
        var entry: [String: JSONValue] = ["current": .string(current.description), "automatic": .bool(Preferences.shared.checkForUpdates)]
        if let lastChecked { entry["checkedAt"] = .string(ISO8601DateFormatter().string(from: lastChecked)) }
        if let pending {
            entry["latest"] = .string(pending.version.description)
            entry["page"] = .string(pending.page.absoluteString)
        }
        switch state {
        case .idle: entry["state"] = .string("unknown")
        case .checking: entry["state"] = .string("checking")
        case .upToDate: entry["state"] = .string("upToDate")
        case .available: entry["state"] = .string("available")
        case .downloading: entry["state"] = .string("downloading")
        case .installing: entry["state"] = .string("installing")
        case .failed(let message):
            entry["state"] = .string("failed")
            entry["error"] = .string(message)
        }
        return .object(entry)
    }

    // MARK: Pieces (no shared state; tested on their own)

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = Constants.Updates.requestTimeout
        return URLSession(configuration: configuration)
    }()

    /// Reads GitHub's "latest release" answer. The zip only counts when it is this repository's
    /// own release download; anything else leaves `asset` empty and the update manual.
    nonisolated static func parseRelease(_ data: Data) -> Release? {
        guard let json = JSONValue.parse(data),
              let version = json["tag_name"]?.string.flatMap(AppVersion.init),
              let page = json["html_url"]?.string.flatMap(URL.init(string:)) else { return nil }
        let asset = json["assets"]?.array?.first { $0["name"]?.string == Constants.Updates.assetName }
        let link = asset?["browser_download_url"]?.string
        let trusted = link.flatMap { $0.hasPrefix(Constants.Updates.assetPrefix) ? URL(string: $0) : nil }
        let digest = asset?["digest"]?.string.flatMap { $0.hasPrefix("sha256:") ? String($0.dropFirst(7)).lowercased() : nil }
        return Release(version: version, page: page, asset: trusted, sha256: trusted == nil ? nil : digest)
    }

    /// The bundle this process runs from, when it is an app the user can replace.
    nonisolated static func installTarget(_ bundle: URL = Bundle.main.bundleURL) throws -> URL {
        let fm = FileManager.default
        guard bundle.pathExtension == "app", fm.isWritableFile(atPath: bundle.path),
              fm.isWritableFile(atPath: bundle.deletingLastPathComponent().path) else { throw UpdateError.notAnApp }
        return bundle
    }

    /// Unpacks the zip beside the app it will replace and refuses it unless it is the release it
    /// claims to be: GitHub's checksum, this app's identifier, the announced version and an
    /// intact signature.
    nonisolated static func stage(zip: URL, expecting release: Release, near target: URL) throws -> URL {
        if let expected = release.sha256 {
            guard try sha256(of: zip) == expected else { throw UpdateError.checksum }
        }
        let folder = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: target, create: true)
        try run("/usr/bin/ditto", ["-x", "-k", zip.path, folder.path])
        let app = folder.appendingPathComponent("\(Constants.appName).app", isDirectory: true)
        guard let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")) else {
            throw UpdateError.wrongApp("no app inside")
        }
        let identifier = info["CFBundleIdentifier"] as? String ?? "no identifier"
        let version = (info["CFBundleShortVersionString"] as? String).flatMap(AppVersion.init)
        guard identifier == Constants.bundleIdentifier, version == release.version else {
            throw UpdateError.wrongApp("\(identifier) \(version?.description ?? "no version")")
        }
        guard (try? run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])) != nil else { throw UpdateError.signature }
        return app
    }

    /// Moves the running bundle aside and the new one into its place; the old one goes back if
    /// that fails. The bundle that was replaced stays in the temporary folder, which macOS clears.
    nonisolated static func swap(_ staged: URL, into target: URL) throws {
        let fm = FileManager.default
        let previous = staged.deletingLastPathComponent().appendingPathComponent("Previous.app", isDirectory: true)
        try fm.moveItem(at: target, to: previous)
        do {
            try fm.moveItem(at: staged, to: target)
        } catch {
            try? fm.moveItem(at: previous, to: target)
            throw error
        }
        _ = try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", target.path])
    }

    nonisolated static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    @discardableResult
    private nonisolated static func run(_ tool: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateError.tool("\(URL(fileURLWithPath: tool).lastPathComponent): \(text.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        return text
    }

    /// Opens the new bundle once this process is gone, then quits.
    private static func relaunch(_ app: URL) {
        let waiter = Process()
        waiter.executableURL = URL(fileURLWithPath: "/bin/sh")
        waiter.arguments = ["-c", "while kill -0 \"$1\" 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$2\"", "sh", "\(ProcessInfo.processInfo.processIdentifier)", app.path]
        try? waiter.run()
        NSApp.terminate(nil)
    }
}
