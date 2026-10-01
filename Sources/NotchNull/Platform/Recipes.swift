import Foundation

/// A preset, a look or a whole shared notch: a name, a line about it, a partial settings.json
/// that applying it merges in and, optionally, the widgets that go with it. The ones that ship
/// live in the skill's `presets/` and `themes/`; yours live in `~/.notchnull/presets` and
/// `~/.notchnull/themes`, which no update touches. They are plain files so an agent can read
/// them, copy one and make its own.
struct NotchRecipe: Identifiable, Equatable {
    enum Kind: String, CaseIterable { case preset = "presets", theme = "themes" }

    let id: String
    let kind: Kind
    let name: String
    let summary: String
    let settings: JSONValue
    /// Widget files carried along, by id. Never installed without being asked for: they can run commands.
    let widgets: [String: JSONValue]
    let order: Int
    /// A render of the recipe next to its file (`minimal.png`), when one ships.
    let preview: URL?
    /// From ~/.notchnull rather than the app.
    let isUserMade: Bool

    /// Sections a recipe may not set: what happens to files in Downloads is the user's call alone.
    static let withheldSections: Set<String> = ["downloads"]

    init?(file: URL, kind: Kind, isUserMade: Bool = false) {
        guard let data = try? Data(contentsOf: file), let json = JSONValue.parse(data),
              let sections = json["settings"]?.object else { return nil }
        id = file.deletingPathExtension().lastPathComponent
        self.kind = kind
        self.isUserMade = isUserMade
        name = json["name"]?.string ?? id.capitalized
        summary = json["summary"]?.string ?? ""
        settings = .object(sections.filter { !Self.withheldSections.contains($0.key) })
        widgets = (json["widgets"]?.object ?? [:]).filter { $0.value["view"]?.object != nil }
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

/// Reads recipes and examples from the skill that shipped with this build and from ~/.notchnull,
/// and applies them.
@MainActor
enum Recipes {
    /// The skill inside the app (or the repo when run from source), falling back to ~/.notchnull/skill.
    static var source: URL { NotchHome.bundledSkill ?? NotchHome.skill }

    /// What `notchnull export` carries: how the notch looks and is laid out, not which features
    /// are on or how this Mac behaves.
    static let exportedSections = ["look", "size", "island", "motion", "tabs", "home", "activities"]

    static func userFolder(_ kind: NotchRecipe.Kind) -> URL {
        kind == .preset ? NotchHome.presets : NotchHome.themes
    }

    /// The shipped recipes plus yours; a file of yours with the same name replaces the shipped one.
    static func load(_ kind: NotchRecipe.Kind) -> [NotchRecipe] {
        var byID: [String: NotchRecipe] = [:]
        for file in files(in: source.appendingPathComponent(kind.rawValue)) {
            if let recipe = NotchRecipe(file: file, kind: kind) { byID[recipe.id] = recipe }
        }
        for file in files(in: userFolder(kind)) {
            if let recipe = NotchRecipe(file: file, kind: kind, isUserMade: true) { byID[recipe.id] = recipe }
        }
        return byID.values.sorted { ($0.order, $0.name) < ($1.order, $1.name) }
    }

    /// A recipe by name (presets first, then looks) or by the path of a file.
    static func find(_ nameOrPath: String) -> NotchRecipe? {
        let path = (nameOrPath as NSString).expandingTildeInPath
        if nameOrPath.contains("/") || nameOrPath.hasSuffix(".json") {
            return NotchRecipe(file: URL(fileURLWithPath: path), kind: .theme, isUserMade: true)
        }
        for kind in NotchRecipe.Kind.allCases {
            if let recipe = load(kind).first(where: { $0.id.lowercased() == nameOrPath.lowercased() }) { return recipe }
        }
        return nil
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

    /// Writes the recipe's widgets into `folder`. A widget you already have keeps its file unless
    /// `replace` is set.
    static func installWidgets(of recipe: NotchRecipe, replace: Bool, into folder: URL = NotchHome.widgets) throws -> (added: [String], kept: [String]) {
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        var added: [String] = [], kept: [String] = []
        for (id, widget) in recipe.widgets.sorted(by: { $0.key < $1.key }) {
            let name = URL(fileURLWithPath: id).lastPathComponent
            let file = folder.appendingPathComponent(name).appendingPathExtension("json")
            if fm.fileExists(atPath: file.path), !replace {
                kept.append(name)
                continue
            }
            try JSONSerialization.data(withJSONObject: widget.any, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]).write(to: file, options: .atomic)
            added.append(name)
        }
        return (added, kept)
    }

    /// The current look and layout plus every widget, as one recipe file someone else can apply.
    static func export(name: String, summary: String, settings: URL = NotchHome.settings, widgets folder: URL = NotchHome.widgets) -> Data? {
        let current = (try? Data(contentsOf: settings)).flatMap(JSONValue.parse)?.object ?? [:]
        var widgets: [String: JSONValue] = [:]
        for file in files(in: folder) {
            if let json = (try? Data(contentsOf: file)).flatMap(JSONValue.parse), json["view"]?.object != nil {
                widgets[file.deletingPathExtension().lastPathComponent] = json
            }
        }
        let recipe: JSONValue = .object([
            "name": .string(name),
            "summary": .string(summary),
            "madeWith": .string("\(Constants.appName) \(AppVersion.current)"),
            "settings": .object(current.filter { exportedSections.contains($0.key) }),
            "widgets": .object(widgets),
        ])
        return try? JSONSerialization.data(withJSONObject: recipe.any, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    private static func files(in folder: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "json" }
    }
}
