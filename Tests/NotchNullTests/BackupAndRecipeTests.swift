import XCTest
@testable import NotchNull

final class BackupAndRecipeTests: XCTestCase {
    private var home: URL!
    private var backups: URL { home.appendingPathComponent("backups", isDirectory: true) }
    private let fm = FileManager.default

    override func setUpWithError() throws {
        home = fm.temporaryDirectory.appendingPathComponent("notchnull-home-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: home.appendingPathComponent("widgets"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: home)
    }

    private func write(_ text: String, to path: String) throws {
        let file = home.appendingPathComponent(path)
        try fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: file)
    }

    private func read(_ path: String) -> String? {
        try? String(contentsOf: home.appendingPathComponent(path), encoding: .utf8)
    }

    private func date(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: 1_800_000_000 + seconds) }

    // MARK: Backups

    func testBackupThenRestoreBringsBackWhatWasChanged() throws {
        try write(##"{"look":{"accent":"#FF5E8A"}}"##, to: "settings.json")
        try write(#"{"view":{"type":"text","text":"mine"}}"#, to: "widgets/mine.json")
        let backup = try XCTUnwrap(NotchBackup.create(reason: "before-1.4.0", from: home, in: backups, now: date(0)))

        try write(##"{"look":{"accent":"#000000"}}"##, to: "settings.json")
        try write(#"{"view":{"type":"text","text":"overwritten"}}"#, to: "widgets/mine.json")
        try write(#"{"view":{"type":"text","text":"added later"}}"#, to: "widgets/later.json")

        let restored = try NotchBackup.restore(backup.id, to: home, in: backups, now: date(60))
        XCTAssertEqual(restored.id, backup.id)
        XCTAssertEqual(read("settings.json"), ##"{"look":{"accent":"#FF5E8A"}}"##)
        XCTAssertEqual(read("widgets/mine.json"), #"{"view":{"type":"text","text":"mine"}}"#)
        XCTAssertNotNil(read("widgets/later.json"), "a file the backup does not hold is left where it is")
    }

    func testRestoreKeepsACopyOfWhatItReplaces() throws {
        try write("first", to: "settings.json")
        try NotchBackup.create(reason: "manual", from: home, in: backups, now: date(0))
        try write("second", to: "settings.json")
        try NotchBackup.restore(nil, to: home, in: backups, now: date(60))

        let newest = try XCTUnwrap(NotchBackup.list(in: backups).first)
        XCTAssertTrue(newest.id.hasSuffix("before-restore"))
        XCTAssertEqual(try String(contentsOf: newest.url.appendingPathComponent("settings.json"), encoding: .utf8), "second")
    }

    func testEmptyHomeMakesNoBackupAndRestoreSaysSo() throws {
        let empty = fm.temporaryDirectory.appendingPathComponent("notchnull-empty-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: empty, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: empty) }
        XCTAssertNil(try NotchBackup.create(reason: "manual", from: empty, in: empty.appendingPathComponent("backups")))
        XCTAssertThrowsError(try NotchBackup.restore(nil, to: empty, in: empty.appendingPathComponent("backups")))
        XCTAssertThrowsError(try NotchBackup.restore("nope", to: home, in: backups))
    }

    func testTwoBackupsInTheSameSecondGetDifferentNames() throws {
        try write("{}", to: "settings.json")
        let first = try XCTUnwrap(NotchBackup.create(reason: "manual", from: home, in: backups, now: date(0)))
        let second = try XCTUnwrap(NotchBackup.create(reason: "manual", from: home, in: backups, now: date(0)))
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(NotchBackup.list(in: backups).count, 2)
    }

    func testVersionBackupsSurviveARunOfAppliedPresets() throws {
        try write("{}", to: "settings.json")
        let version = try XCTUnwrap(NotchBackup.create(reason: "before-1.4.0", from: home, in: backups, now: date(0)))
        XCTAssertTrue(NotchBackup.isVersionBackup(version.id))
        for index in 1...(Constants.Limits.backups + 4) {
            try NotchBackup.create(reason: "before-ocean", from: home, in: backups, now: date(TimeInterval(index)))
        }
        let ids = NotchBackup.list(in: backups).map(\.id)
        XCTAssertTrue(ids.contains(version.id))
        XCTAssertEqual(ids.filter { !NotchBackup.isVersionBackup($0) }.count, Constants.Limits.backups)
    }

    // MARK: Recipes

    private func recipe(_ json: String) throws -> NotchRecipe {
        try write(json, to: "themes/shared.json")
        return try XCTUnwrap(NotchRecipe(file: home.appendingPathComponent("themes/shared.json"), kind: .theme, isUserMade: true))
    }

    func testRecipeCannotChangeWhatHappensToDownloads() throws {
        let shared = try recipe(##"{"name":"Shared","settings":{"look":{"accent":"#FF5E8A"},"downloads":{"cleanup":true,"useDefaultWhenUnanswered":true}}}"##)
        XCTAssertNotNil(shared.settings["look"])
        XCTAssertNil(shared.settings["downloads"])
    }

    func testFileWithoutSettingsIsNotARecipe() throws {
        try write(#"{"name":"Broken"}"#, to: "themes/broken.json")
        XCTAssertNil(NotchRecipe(file: home.appendingPathComponent("themes/broken.json"), kind: .theme))
    }

    @MainActor
    func testSharedWidgetsNeverOverwriteYoursUnlessAsked() throws {
        let shared = try recipe(#"{"settings":{},"widgets":{"mine":{"view":{"type":"text","text":"theirs"}},"clock":{"command":"date","view":{"type":"text","text":"{{data.text}}"}},"junk":{"title":"no view"}}}"#)
        XCTAssertEqual(Set(shared.widgets.keys), ["mine", "clock"], "an entry without a view is not a widget")
        try write(#"{"view":{"type":"text","text":"mine"}}"#, to: "widgets/mine.json")
        let folder = home.appendingPathComponent("widgets")

        let kept = try Recipes.installWidgets(of: shared, replace: false, into: folder)
        XCTAssertEqual(kept.added, ["clock"])
        XCTAssertEqual(kept.kept, ["mine"])
        XCTAssertEqual(read("widgets/mine.json"), #"{"view":{"type":"text","text":"mine"}}"#)

        let replaced = try Recipes.installWidgets(of: shared, replace: true, into: folder)
        XCTAssertEqual(replaced.added, ["clock", "mine"])
        XCTAssertTrue(read("widgets/mine.json")?.contains("theirs") == true)
    }

    @MainActor
    func testWidgetIdCannotEscapeTheWidgetsFolder() throws {
        let shared = try recipe(#"{"settings":{},"widgets":{"../../escaped":{"view":{"type":"text","text":"x"}}}}"#)
        let folder = home.appendingPathComponent("widgets")
        XCTAssertEqual(try Recipes.installWidgets(of: shared, replace: true, into: folder).added, ["escaped"])
        XCTAssertNotNil(read("widgets/escaped.json"))
        XCTAssertFalse(fm.fileExists(atPath: home.deletingLastPathComponent().appendingPathComponent("escaped.json").path))
    }

    @MainActor
    func testExportCarriesLookAndWidgetsButNotFeaturesOrBehavior() throws {
        try write(##"{"look":{"accent":"#FF5E8A"},"tabs":{"hidden":["mirror"]},"features":{"clipboard":true},"behavior":{"sounds":false},"downloads":{"cleanup":true}}"##, to: "settings.json")
        try write(#"{"view":{"type":"text","text":"mine"}}"#, to: "widgets/mine.json")
        let data = try XCTUnwrap(Recipes.export(name: "Mine", summary: "", settings: home.appendingPathComponent("settings.json"), widgets: home.appendingPathComponent("widgets")))
        let json = try XCTUnwrap(JSONValue.parse(data))
        XCTAssertEqual(Set(json["settings"]?.object?.keys.map { $0 } ?? []), ["look", "tabs"])
        XCTAssertNotNil(json["widgets"]?["mine"])

        let exported = try recipe(String(decoding: data, as: UTF8.self))
        XCTAssertEqual(exported.name, "Mine")
        XCTAssertEqual(Array(exported.widgets.keys), ["mine"], "an exported file applies like any other recipe")
    }
}
