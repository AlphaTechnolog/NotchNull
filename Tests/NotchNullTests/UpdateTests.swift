import XCTest
@testable import NotchNull

final class UpdateTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent("notchnull-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    // MARK: Versions

    func testVersionsCompareByNumberNotByText() throws {
        XCTAssertGreaterThan(try XCTUnwrap(AppVersion("1.10.0")), try XCTUnwrap(AppVersion("1.9.2")))
        XCTAssertGreaterThan(try XCTUnwrap(AppVersion("v1.4.0")), try XCTUnwrap(AppVersion("1.3.1")))
        XCTAssertEqual(AppVersion("1.4"), AppVersion("1.4.0"))
        XCTAssertFalse(try XCTUnwrap(AppVersion("1.3.1")) > XCTUnwrap(AppVersion("1.3.1")))
    }

    func testTextThatIsNotAVersionIsRejected() {
        XCTAssertNil(AppVersion("dev"))
        XCTAssertNil(AppVersion("1.4.0-beta"))
        XCTAssertNil(AppVersion(""))
        XCTAssertNil(AppVersion("1..2"))
    }

    // MARK: Reading a release

    private func release(asset: String, digest: String? = "sha256:ABCDEF") -> Data {
        var entry: [String: Any] = ["name": "NotchNull.zip", "browser_download_url": asset]
        if let digest { entry["digest"] = digest }
        let json: [String: Any] = [
            "tag_name": "v1.4.0",
            "html_url": "https://github.com/Obed0101/NotchNull/releases/tag/v1.4.0",
            "assets": [["name": "notes.txt", "browser_download_url": "https://example.com/notes.txt"], entry],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    func testReleaseWithItsZipAndChecksumIsRead() throws {
        let parsed = try XCTUnwrap(UpdateService.parseRelease(release(asset: "https://github.com/Obed0101/NotchNull/releases/download/v1.4.0/NotchNull.zip")))
        XCTAssertEqual(parsed.version, AppVersion("1.4.0"))
        XCTAssertEqual(parsed.asset?.lastPathComponent, "NotchNull.zip")
        XCTAssertEqual(parsed.sha256, "abcdef")
    }

    func testZipHostedSomewhereElseIsNotInstallable() throws {
        let parsed = try XCTUnwrap(UpdateService.parseRelease(release(asset: "https://evil.example/Obed0101/NotchNull/releases/download/v1.4.0/NotchNull.zip")))
        XCTAssertNil(parsed.asset)
        XCTAssertNil(parsed.sha256)
    }

    func testAnswerWithoutAVersionIsNotARelease() {
        XCTAssertNil(UpdateService.parseRelease(Data(#"{"message":"API rate limit exceeded"}"#.utf8)))
        XCTAssertNil(UpdateService.parseRelease(Data("not json".utf8)))
    }

    // MARK: Installing

    /// A signed bundle with this app's identifier, zipped the way the release workflow zips it.
    private func makeZippedApp(version: String, identifier: String = Constants.bundleIdentifier, marker: String) throws -> URL {
        let folder = scratch.appendingPathComponent("build-\(UUID().uuidString)", isDirectory: true)
        let app = folder.appendingPathComponent("NotchNull.app", isDirectory: true)
        let macOS = app.appendingPathComponent("Contents/MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: macOS.appendingPathComponent("NotchNull"))
        let info: NSDictionary = [
            "CFBundleIdentifier": identifier, "CFBundleExecutable": "NotchNull",
            "CFBundleShortVersionString": version, "CFBundlePackageType": "APPL", "Marker": marker,
        ]
        XCTAssertTrue(info.write(to: app.appendingPathComponent("Contents/Info.plist"), atomically: true))
        try shell("/usr/bin/codesign", ["--force", "--deep", "--sign", "-", app.path])
        let zip = folder.appendingPathComponent("NotchNull.zip")
        try shell("/usr/bin/ditto", ["-c", "-k", "--keepParent", app.path, zip.path])
        return zip
    }

    private func shell(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "\(tool) \(arguments.joined(separator: " "))")
    }

    private func installedApp(version: String) throws -> URL {
        let applications = scratch.appendingPathComponent("Applications", isDirectory: true)
        try FileManager.default.createDirectory(at: applications, withIntermediateDirectories: true)
        let zip = try makeZippedApp(version: version, marker: "old")
        try shell("/usr/bin/ditto", ["-x", "-k", zip.path, applications.path])
        return applications.appendingPathComponent("NotchNull.app", isDirectory: true)
    }

    private func marker(of app: URL) -> String? {
        NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))?["Marker"] as? String
    }

    private func release(_ version: String, zip: URL, sha256: String? = nil) throws -> UpdateService.Release {
        UpdateService.Release(version: try XCTUnwrap(AppVersion(version)), page: Constants.Links.releases, asset: zip, sha256: sha256)
    }

    func testVerifiedDownloadReplacesTheInstalledApp() throws {
        let target = try installedApp(version: "1.3.1")
        let zip = try makeZippedApp(version: "1.4.0", marker: "new")
        let staged = try UpdateService.stage(zip: zip, expecting: release("1.4.0", zip: zip, sha256: UpdateService.sha256(of: zip)), near: target)
        try UpdateService.swap(staged, into: target)
        XCTAssertEqual(marker(of: target), "new")
        XCTAssertEqual(try UpdateService.installTarget(target), target)
    }

    func testDownloadThatDoesNotMatchItsChecksumIsRefused() throws {
        let target = try installedApp(version: "1.3.1")
        let zip = try makeZippedApp(version: "1.4.0", marker: "new")
        XCTAssertThrowsError(try UpdateService.stage(zip: zip, expecting: release("1.4.0", zip: zip, sha256: String(repeating: "0", count: 64)), near: target))
        XCTAssertEqual(marker(of: target), "old")
    }

    func testAnotherAppOrAnotherVersionIsRefused() throws {
        let target = try installedApp(version: "1.3.1")
        let stranger = try makeZippedApp(version: "1.4.0", identifier: "com.example.other", marker: "new")
        XCTAssertThrowsError(try UpdateService.stage(zip: stranger, expecting: release("1.4.0", zip: stranger), near: target))
        let older = try makeZippedApp(version: "1.2.0", marker: "new")
        XCTAssertThrowsError(try UpdateService.stage(zip: older, expecting: release("1.4.0", zip: older), near: target))
    }

    func testAppWithABrokenSignatureIsRefused() throws {
        let target = try installedApp(version: "1.3.1")
        let zip = try makeZippedApp(version: "1.4.0", marker: "new")
        let tampered = scratch.appendingPathComponent("tampered", isDirectory: true)
        try shell("/usr/bin/ditto", ["-x", "-k", zip.path, tampered.path])
        try Data("changed after signing".utf8).write(to: tampered.appendingPathComponent("NotchNull.app/Contents/MacOS/NotchNull"))
        let again = tampered.appendingPathComponent("NotchNull.zip")
        try shell("/usr/bin/ditto", ["-c", "-k", "--keepParent", tampered.appendingPathComponent("NotchNull.app").path, again.path])
        XCTAssertThrowsError(try UpdateService.stage(zip: again, expecting: release("1.4.0", zip: again), near: target)) { error in
            XCTAssertEqual(error.localizedDescription, UpdateService.UpdateError.signature.localizedDescription)
        }
    }

    /// The whole path against GitHub: opt in with NOTCHNULL_LIVE_UPDATE=1 (it downloads the release).
    func testLatestPublishedReleaseInstallsOverAnOlderApp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["NOTCHNULL_LIVE_UPDATE"] == "1", "set NOTCHNULL_LIVE_UPDATE=1 to download the real release")
        let (answer, _) = try await URLSession.shared.data(from: Constants.Updates.latestRelease)
        let latest = try XCTUnwrap(UpdateService.parseRelease(answer))
        let asset = try XCTUnwrap(latest.asset)
        XCTAssertNotNil(latest.sha256, "GitHub publishes a checksum for the zip")
        let (download, _) = try await URLSession.shared.download(from: asset)

        let target = try installedApp(version: "0.0.1")
        let staged = try UpdateService.stage(zip: download, expecting: latest, near: target)
        try UpdateService.swap(staged, into: target)
        let info = try XCTUnwrap(NSDictionary(contentsOf: target.appendingPathComponent("Contents/Info.plist")))
        XCTAssertEqual((info["CFBundleShortVersionString"] as? String).flatMap(AppVersion.init), latest.version)
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.appendingPathComponent("Contents/Resources/skill/SKILL.md").path))
    }

    func testBinaryOutsideAnAppBundleCannotReplaceItself() {
        XCTAssertThrowsError(try UpdateService.installTarget(scratch))
        XCTAssertThrowsError(try UpdateService.installTarget(URL(fileURLWithPath: "/System/Applications/Calculator.app")))
    }
}
