import Foundation

/// A preset or theme from the skill's `presets/` and `themes/` folders: a name, a line about it and
/// a partial settings.json that applying it merges in. They are plain files so an agent can read
/// them, copy one and make its own.
struct NotchRecipe: Identifiable, Equatable {
    enum Kind: String { case preset = "presets", theme = "themes" }

    let id: String
    let kind: Kind
    let name: String
    let summary: String
    let settings: JSONValue
    let order: Int
    /// A render of the recipe next to its file (`minimal.png`), when one ships.
    let preview: URL?

    init?(file: URL, kind: Kind) {
        guard let data = try? Data(contentsOf: file), let json = JSONValue.parse(data),
              let settings = json["settings"], settings.object != nil else { return nil }
        id = file.deletingPathExtension().lastPathComponent
        self.kind = kind
        name = json["name"]?.string ?? id.capitalized
        summary = json["summary"]?.string ?? ""
        self.settings = settings
        order = Int(json["order"]?.double ?? 0)
        let image = file.deletingPathExtension().appendingPathExtension("png")
        preview = FileManager.default.fileExists(atPath: image.path) ? image : nil
    }

    /// Two colors that stand for the recipe in a swatch: its body and its accent.
    var swatch: (body: JSONValue?, accent: JSONValue?) {
        let look = settings["look"]
        let body: JSONValue? = look?["body"]?.string == "tinted" ? look?["tint"] : .string("#000000")
        return (body, look?["accentFollowsMac"]?.bool == true ? .string("accent") : look?["accent"])
    }
}

/// An example widget from the skill's `examples/`, with whether it is already in your widgets.
struct ExampleWidget: Identifiable, Equatable {
    let id: String
    let file: URL
    let title: String
    let summary: String
    let symbol: String?
    let tint: JSONValue?

    var destination: URL { NotchHome.widgets.appendingPathComponent(file.lastPathComponent) }
    var isInstalled: Bool { FileManager.default.fileExists(atPath: destination.path) }

    init?(file: URL) {
        guard let data = try? Data(contentsOf: file), let json = JSONValue.parse(data), json["view"] != nil else { return nil }
        id = file.deletingPathExtension().lastPathComponent
        self.file = file
        title = json["title"]?.string ?? id
        summary = json["description"]?.string ?? ""
        symbol = json["symbol"]?.string
        tint = json["tint"]
    }
}

/// Reads recipes and examples from the skill that shipped with this build, and applies them.
@MainActor
enum Recipes {
    /// The skill inside the app (or the repo when run from source), falling back to ~/.notchnull/skill.
    static var source: URL { NotchHome.bundledSkill ?? NotchHome.skill }

    static func load(_ kind: NotchRecipe.Kind) -> [NotchRecipe] {
        files(in: source.appendingPathComponent(kind.rawValue))
            .compactMap { NotchRecipe(file: $0, kind: kind) }
            .sorted { ($0.order, $0.name) < ($1.order, $1.name) }
    }

    static func examples() -> [ExampleWidget] {
        files(in: source.appendingPathComponent("examples"))
            .compactMap(ExampleWidget.init(file:))
            .sorted { $0.title < $1.title }
    }

    /// Merges the recipe into the current settings; settings.json follows on its own.
    @discardableResult
    static func apply(_ recipe: NotchRecipe) -> [String] {
        guard let data = try? JSONSerialization.data(withJSONObject: recipe.settings.any) else { return ["Could not read \(recipe.name)."] }
        let problems = SettingsFile.shared.apply(data, isPatch: true)
        if recipe.kind == .preset { Preferences.shared.appliedPreset = recipe.id }
        Log.app.info("Applied \(recipe.kind.rawValue, privacy: .public) \(recipe.id, privacy: .public)")
        return problems
    }

    /// Copies an example into ~/.notchnull/widgets. An existing file with that name is kept.
    static func install(_ example: ExampleWidget) throws {
        guard !example.isInstalled else { return }
        try FileManager.default.createDirectory(at: NotchHome.widgets, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: example.file, to: example.destination)
    }

    private static func files(in folder: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "json" }
    }
}
