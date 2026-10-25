import Foundation

struct AgentAvailabilityRefreshThrottle {
    let interval: TimeInterval
    private(set) var lastRefresh: Date?

    init(interval: TimeInterval = 2, lastRefresh: Date? = nil) {
        self.interval = interval
        self.lastRefresh = lastRefresh
    }

    mutating func shouldRefresh(at date: Date) -> Bool {
        if let lastRefresh, date.timeIntervalSince(lastRefresh) < interval { return false }
        lastRefresh = date
        return true
    }
}

/// Detects agent installations from executable locations or the local data NotchNull watches.
/// The injected filesystem inputs keep the rules independent of the host for tests and snapshots.
struct AgentInstallation {
    let homeDirectory: URL
    let executableDirectories: [URL]
    let fileManager: FileManager

    init(homeDirectory: URL, executableDirectories: [URL] = [], fileManager: FileManager = .default) {
        self.homeDirectory = homeDirectory
        self.executableDirectories = executableDirectories
        self.fileManager = fileManager
    }

    static func live(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default,
        systemDirectories: [URL]? = nil
    ) -> AgentInstallation {
        let homeDirectories = [
            ".local/bin", ".claude/local", ".opencode/bin", ".bun/bin", ".npm-global/bin", ".volta/bin",
            "Library/pnpm", ".local/share/pnpm", ".asdf/shims", ".local/share/mise/shims",
        ].map { homeDirectory.appendingPathComponent($0, isDirectory: true) }

        let managedDirectories = [
            (".local/share/fnm/node-versions", "installation/bin"),
            (".nvm/versions/node", "bin"),
        ].flatMap { root, suffix -> [URL] in
            let rootURL = homeDirectory.appendingPathComponent(root, isDirectory: true)
            guard let versions = try? fileManager.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }
            return versions.map { $0.appendingPathComponent(suffix, isDirectory: true) }
        }

        let pathDirectories = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0), isDirectory: true) }
        let systemSearchDirectories = systemDirectories ?? ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
        let directories = pathDirectories + homeDirectories + managedDirectories + systemSearchDirectories

        return AgentInstallation(
            homeDirectory: homeDirectory,
            executableDirectories: deduplicated(directories),
            fileManager: fileManager
        )
    }

    private static func deduplicated(_ directories: [URL]) -> [URL] {
        var seen = Set<String>()
        return directories.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    func installedProviders() -> Set<AgentProvider> {
        Set(AgentProvider.allCases.filter { provider in
            hasExecutable(for: provider) || hasWatchableData(for: provider)
        })
    }

    private func hasExecutable(for provider: AgentProvider) -> Bool {
        executableDirectories.contains { directory in
            fileManager.isExecutableFile(atPath: directory.appendingPathComponent(provider.executableName).path)
        }
    }

    private func hasWatchableData(for provider: AgentProvider) -> Bool {
        provider.watchablePaths(relativeTo: homeDirectory).contains { path in
            fileManager.fileExists(atPath: path.path)
        }
    }
}

private extension AgentProvider {
    var executableName: String {
        switch self {
        case .claude: "claude"
        case .codex: "codex"
        case .opencode: "opencode"
        }
    }

    func watchablePaths(relativeTo home: URL) -> [URL] {
        switch self {
        case .claude:
            [home.appendingPathComponent(".claude/projects", isDirectory: true)]
        case .codex:
            [
                home.appendingPathComponent(".codex/sessions", isDirectory: true),
                home.appendingPathComponent(".codex/config.toml"),
                home.appendingPathComponent(".codex/auth.json"),
            ]
        case .opencode:
            [home.appendingPathComponent(".local/share/opencode/opencode.db")]
        }
    }
}
