import XCTest
@testable import NotchNull

final class AgentInstallationTests: XCTestCase {
    private var temporaryHome: URL!

    override func setUpWithError() throws {
        temporaryHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentInstallationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryHome, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryHome)
    }

    func testEmptyHomeHasNoInstalledProviders() {
        XCTAssertTrue(installation().installedProviders().isEmpty)
    }

    func testExecutableInInjectedDirectoryDetectsEachProvider() throws {
        let bin = temporaryHome.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        for name in ["claude", "codex", "opencode"] {
            let executable = bin.appendingPathComponent(name)
            XCTAssertTrue(FileManager.default.createFile(atPath: executable.path, contents: Data()))
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        }

        XCTAssertEqual(installation(executableDirectories: [bin]).installedProviders(), Set(AgentProvider.allCases))
    }

    func testLiveSearchIncludesPathAndCommonInstallDirectories() throws {
        let pathBin = temporaryHome.appendingPathComponent("path-bin", isDirectory: true)
        try FileManager.default.createDirectory(at: pathBin, withIntermediateDirectories: true)
        let executable = pathBin.appendingPathComponent("claude")
        XCTAssertTrue(FileManager.default.createFile(atPath: executable.path, contents: Data()))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let systemDirectories = ["/opt/homebrew/bin", "/usr/local/bin"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        let live = AgentInstallation.live(
            environment: ["PATH": pathBin.path],
            homeDirectory: temporaryHome,
            systemDirectories: systemDirectories
        )
        XCTAssertTrue(live.installedProviders().contains(.claude))
        XCTAssertTrue(live.executableDirectories.contains { $0.path == "/opt/homebrew/bin" })
        XCTAssertTrue(live.executableDirectories.contains { $0.path == "/usr/local/bin" })
    }

    func testLiveSearchIncludesLegacyClaudeInstallDirectory() throws {
        let claudeDirectory = temporaryHome.appendingPathComponent(".claude/local", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeDirectory, withIntermediateDirectories: true)
        let executable = claudeDirectory.appendingPathComponent("claude")
        XCTAssertTrue(FileManager.default.createFile(atPath: executable.path, contents: Data()))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let live = AgentInstallation.live(environment: [:], homeDirectory: temporaryHome, systemDirectories: [])
        XCTAssertEqual(live.installedProviders(), [.claude])
    }

    func testLiveSearchIncludesNodeVersionManagerBins() throws {
        let fnmBin = temporaryHome.appendingPathComponent(".local/share/fnm/node-versions/v24/installation/bin", isDirectory: true)
        let nvmBin = temporaryHome.appendingPathComponent(".nvm/versions/node/v22/bin", isDirectory: true)
        try FileManager.default.createDirectory(at: fnmBin, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nvmBin, withIntermediateDirectories: true)
        let codex = fnmBin.appendingPathComponent("codex")
        let opencode = nvmBin.appendingPathComponent("opencode")
        for executable in [codex, opencode] {
            XCTAssertTrue(FileManager.default.createFile(atPath: executable.path, contents: Data()))
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        }

        let live = AgentInstallation.live(environment: [:], homeDirectory: temporaryHome, systemDirectories: [])
        XCTAssertEqual(live.installedProviders(), [.codex, .opencode])
    }

    func testWatchableDataDetectsProvidersWithoutExecutables() throws {
        let markers: [(String, AgentProvider)] = [
            (".claude/projects", .claude),
            (".codex/sessions", .codex),
            (".codex/config.toml", .codex),
            (".codex/auth.json", .codex),
            (".local/share/opencode/opencode.db", .opencode),
        ]

        for (relativePath, provider) in markers {
            let marker = temporaryHome.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(
                at: marker.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if relativePath.hasSuffix("/") || relativePath == ".claude/projects" || relativePath == ".codex/sessions" {
                try FileManager.default.createDirectory(at: marker, withIntermediateDirectories: true)
            } else {
                XCTAssertTrue(FileManager.default.createFile(atPath: marker.path, contents: Data()))
            }

            XCTAssertEqual(installation().installedProviders(), [provider], "Expected \(relativePath) to detect \(provider)")
            try FileManager.default.removeItem(at: marker)
        }
    }

    func testNotchNullConfigurationAloneDoesNotDetectClaudeOrCodex() throws {
        for relativePath in [".claude/settings.json", ".codex/hooks.json"] {
            let marker = temporaryHome.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(
                at: marker.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            XCTAssertTrue(FileManager.default.createFile(atPath: marker.path, contents: Data("{}".utf8)))
        }

        XCTAssertTrue(installation().installedProviders().isEmpty)
    }

    private func installation(executableDirectories: [URL] = []) -> AgentInstallation {
        AgentInstallation(homeDirectory: temporaryHome, executableDirectories: executableDirectories)
    }
}
