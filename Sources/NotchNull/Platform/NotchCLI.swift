import AppKit
import Foundation

/// `notchnull …` (~/.notchnull/bin/notchnull runs `NotchNull cli …`). Talks to the running app
/// over the local API, except `render`, which draws in-process and needs no running app.
@MainActor
enum NotchCLI {
    static let help = """
    notchnull: drive your notch from any script or agent.

      notchnull show TITLE [--subtitle S] [--symbol SF] [--tint COLOR] [--leading T] [--trailing T]
                           [--progress 0..1] [--for SECONDS] [--persistent] [--id ID] [--open URL]
      notchnull wing  [--symbol SF] [--leading T] [--trailing T] [--tint COLOR] [--for S] [--id ID]
      notchnull hide [ID]                 hide one custom activity, or all of them
      notchnull open [TAB] | close        tabs: \(NotchTab.allCases.map(\.rawValue).joined(separator: ", "))
      notchnull widget ID run             run a widget's command now
      notchnull widget ID data JSON       push data into a widget
      notchnull reload                    reload ~/.notchnull/widgets
      notchnull settings                  print settings.json as the app sees it
      notchnull settings set JSON         apply part of it, e.g. '{"look":{"accent":"#FF5E8A"}}'
      notchnull recipes                   presets and looks you can apply (the shipped ones and yours)
      notchnull apply NAME|FILE [--widgets] [--replace]
                                          apply a preset, a look or a shared notch file; your files
                                          are backed up first. --widgets also installs the widgets
                                          the file carries (read their commands first)
      notchnull export OUT.json [--name N] [--summary S]
                                          your look, layout and widgets as one file to share
      notchnull backup [NAME]             copy settings.json, widgets, presets and themes to backups/
      notchnull backups                   list them, newest first
      notchnull restore [ID]              put a backup back (the newest without an ID)
      notchnull update [install]          check for a new version; install replaces the app and relaunches
      notchnull status                    widgets, errors, activities (also ~/.notchnull/status.json)
      notchnull render OUT.png [--tab TAB | --closed | --wing | --activity JSON] [--demo] [--full] [--transparent]
                                          draw the notch to a PNG with your current files;
                                          --wing shows the widget wing that is up, if any
      notchnull path                      print the folder you edit (~/.notchnull)

    Colors: accent, green, red, orange, yellow, blue, sky, purple, pink, teal, claude, codex, gray or #RRGGBB.
    Docs: ~/.notchnull/skill/SKILL.md
    """

    static func run(_ arguments: [String]) -> Int32 {
        guard let command = arguments.first else {
            print(help)
            return 0
        }
        let rest = Array(arguments.dropFirst())
        let options = Options(rest)
        switch command {
        case "help", "-h", "--help":
            print(help)
            return 0
        case "path":
            print(NotchHome.root.path)
            return 0
        case "show", "wing":
            var payload: [String: JSONValue] = ["id": .string(options["id"] ?? "cli")]
            if command == "show", let title = options.positional.first { payload["title"] = .string(title) }
            for key in ["subtitle", "symbol", "tint", "leading", "trailing"] {
                if let value = options[key] { payload[key] = .string(value) }
            }
            if let progress = options["progress"].flatMap(Double.init) { payload["progress"] = .number(progress) }
            if let seconds = options["for"].flatMap(Double.init) { payload["duration"] = .number(seconds) }
            if options.flags.contains("persistent") { payload["persistent"] = .bool(true) }
            if let url = options["open"] { payload["action"] = .object(["open": .string(url)]) }
            if payload["symbol"] == nil, command == "show" { payload["symbol"] = .string("bell.fill") }
            return request("POST", "activity", body: .object(payload))
        case "hide":
            return request("POST", "activity/hide", body: .object(options.positional.first.map { ["id": .string($0)] } ?? [:]))
        case "open":
            return request("POST", "open", body: .object(options.positional.first.map { ["tab": .string($0)] } ?? [:]))
        case "close":
            return request("POST", "close")
        case "reload":
            return request("POST", "widgets/reload")
        case "status":
            return request("GET", "status")
        case "widget":
            guard options.positional.count >= 2 else { return fail("usage: notchnull widget ID run | notchnull widget ID data JSON") }
            let id = options.positional[0]
            if options.positional[1] == "run" { return request("POST", "widgets/\(id)/run") }
            guard options.positional[1] == "data", options.positional.count >= 3, let data = JSONValue.parse(Data(options.positional[2].utf8)) else {
                return fail("usage: notchnull widget ID data '{\"count\": 3}'")
            }
            return request("POST", "widgets/\(id)/data", body: data)
        case "settings":
            if options.positional.first == "set" {
                guard options.positional.count >= 2, let patch = JSONValue.parse(Data(options.positional[1].utf8)) else {
                    return fail("usage: notchnull settings set '{\"look\": {\"accent\": \"#FF5E8A\"}}'")
                }
                return request("POST", "settings", body: patch)
            }
            return request("GET", "settings")
        case "render":
            return render(options)
        case "recipes":
            for kind in NotchRecipe.Kind.allCases {
                for recipe in Recipes.load(kind) {
                    print("\(kind == .preset ? "preset" : "look")\t\(recipe.id)\t\(recipe.isUserMade ? "yours" : "shipped")\t\(recipe.summary)")
                }
            }
            return 0
        case "apply":
            return apply(options)
        case "export":
            return export(options)
        case "backup":
            do {
                guard let entry = try NotchBackup.create(reason: options.positional.first ?? "manual") else {
                    return fail("Nothing to back up yet: ~/.notchnull has no settings or widgets.")
                }
                print(entry.url.path)
                return 0
            } catch {
                return fail("Could not back up: \(error.localizedDescription)")
            }
        case "backups":
            NotchBackup.list().forEach { print($0.id) }
            return 0
        case "restore":
            do {
                let entry = try NotchBackup.restore(options.positional.first)
                print("Restored \(entry.id). The running app picks the files up as they change.")
                return 0
            } catch {
                return fail(error.localizedDescription)
            }
        case "update":
            return update(install: options.positional.first == "install")
        default:
            return fail("Unknown command \(command). Try: notchnull help")
        }
    }

    // MARK: Render

    private static func render(_ options: Options) -> Int32 {
        guard let path = options.positional.first else { return fail("usage: notchnull render OUT.png [--tab widgets]") }
        let output = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        let phase: NotchViewModel.Phase
        var tab = NotchTab.widgets
        if options.flags.contains("closed") {
            phase = .closed
        } else if options.flags.contains("wing") {
            // Widget wings come up in renderLive once commands have run.
            phase = .activity(.custom)
        } else if let json = options["activity"] {
            guard let payload = JSONValue.parse(Data(json.utf8)), let activity = CustomActivity(payload: payload) else {
                return fail("--activity needs JSON like '{\"symbol\": \"hammer.fill\", \"title\": \"Build passed\"}'")
            }
            CustomActivityStore.shared.set(activity)
            phase = .activity(.custom)
        } else {
            if let name = options["tab"] {
                guard let chosen = NotchTab(rawValue: name) else { return fail("Unknown tab \(name).") }
                tab = chosen
            }
            phase = .open
        }
        do {
            try SnapshotRenderer.renderLive(to: output, phase: phase, tab: tab, demo: options.flags.contains("demo"), fullCanvas: options.flags.contains("full"), transparent: options.flags.contains("transparent"))
            print(output.path)
            return 0
        } catch {
            return fail("Could not render: \(error.localizedDescription)")
        }
    }

    // MARK: Recipes

    private static func apply(_ options: Options) -> Int32 {
        guard let name = options.positional.first else { return fail("usage: notchnull apply NAME|FILE [--widgets] [--replace]") }
        guard let recipe = Recipes.find(name) else {
            return fail("No preset, look or recipe file \(name). `notchnull recipes` lists the names; a file needs a \"settings\" object.")
        }
        do {
            if let backup = try NotchBackup.create(reason: "before-\(recipe.id)") { print("Backed up to \(backup.url.path)") }
            if options.flags.contains("widgets") {
                let result = try Recipes.installWidgets(of: recipe, replace: options.flags.contains("replace"))
                if !result.added.isEmpty { print("Widgets installed: \(result.added.joined(separator: ", "))") }
                if !result.kept.isEmpty { print("Widgets you already have, left as they are (--replace overwrites): \(result.kept.joined(separator: ", "))") }
            } else if !recipe.widgets.isEmpty {
                print("\(recipe.name) also carries \(recipe.widgets.count) widget(s), not installed. Widgets run shell commands; read them, then add --widgets:")
                for (id, widget) in recipe.widgets.sorted(by: { $0.key < $1.key }) {
                    print("  \(id): \(widget["command"]?.string ?? "no command")")
                }
            }
        } catch {
            return fail("Could not apply \(recipe.name): \(error.localizedDescription)")
        }
        return request("POST", "settings", body: recipe.settings)
    }

    private static func export(_ options: Options) -> Int32 {
        guard let path = options.positional.first else { return fail("usage: notchnull export OUT.json [--name NAME] [--summary TEXT]") }
        let output = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        let name = options["name"] ?? output.deletingPathExtension().lastPathComponent.capitalized
        guard let data = Recipes.export(name: name, summary: options["summary"] ?? "") else {
            return fail("Could not read ~/.notchnull/settings.json. Open NotchNull once so it writes the file.")
        }
        do {
            try data.write(to: output, options: .atomic)
            print(output.path)
            return 0
        } catch {
            return fail("Could not write \(output.path): \(error.localizedDescription)")
        }
    }

    // MARK: Update

    /// Asks the running app to check, waits for the answer, and optionally installs.
    private static func update(install: Bool) -> Int32 {
        guard send("POST", "update/check") != nil else { return 1 }
        var summary: JSONValue?
        for _ in 0..<60 {
            Thread.sleep(forTimeInterval: 0.5)
            guard let answer = send("GET", "update") else { return 1 }
            summary = JSONValue.parse(Data(answer.utf8))
            if summary?["state"]?.string != "checking" { break }
        }
        let state = summary?["state"]?.string ?? "unknown"
        let current = summary?["current"]?.string ?? "?"
        switch state {
        case "available":
            let latest = summary?["latest"]?.string ?? "?"
            guard install else {
                print("NotchNull \(latest) is available (you have \(current)). Install it with: notchnull update install")
                return 0
            }
            guard send("POST", "update/install") != nil else { return 1 }
            print("Installing NotchNull \(latest). The app replaces itself and relaunches; ~/.notchnull is left as it is.")
            return 0
        case "upToDate":
            print("NotchNull \(current) is the latest version.")
            return 0
        default:
            return fail(summary?["error"]?.string ?? "The update check did not finish (\(state)).")
        }
    }

    // MARK: HTTP

    private static func request(_ method: String, _ path: String, body: JSONValue? = nil) -> Int32 {
        guard let text = send(method, path, body: body) else { return 1 }
        if !text.isEmpty { print(text) }
        return 0
    }

    /// The response body, or nil after printing why the request failed.
    private static func send(_ method: String, _ path: String, body: JSONValue? = nil) -> String? {
        guard let url = URL(string: "http://127.0.0.1:\(Constants.Agents.eventServerPort)/v1/\(path)") else {
            _ = fail("Bad path")
            return nil
        }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.httpMethod = method
        request.setValue(ClaudeHookInstaller.token(), forHTTPHeaderField: "X-NotchNull-Token")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body.any)
        }
        let semaphore = DispatchSemaphore(value: 0)
        var result: (Data?, HTTPURLResponse?, Error?) = (nil, nil, nil)
        URLSession.shared.dataTask(with: request) { data, response, error in
            result = (data, response as? HTTPURLResponse, error)
            semaphore.signal()
        }.resume()
        semaphore.wait()
        if let error = result.2 {
            if (error as? URLError)?.code == .timedOut {
                _ = fail("NotchNull did not answer in time. If a macOS permission prompt is open, answer it, then try again.")
            } else {
                _ = fail("NotchNull is not running (\(error.localizedDescription)). Open the app, then try again.")
            }
            return nil
        }
        let text = result.0.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let status = result.1?.statusCode ?? 0
        if status >= 400 {
            _ = fail(text.isEmpty ? "HTTP \(status)" : text)
            return nil
        }
        return text
    }

    private static func fail(_ message: String) -> Int32 {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        return 1
    }

    /// `--key value`, `--flag` and positional arguments.
    struct Options {
        var values: [String: String] = [:]
        var flags: Set<String> = []
        var positional: [String] = []

        static let valueKeys: Set<String> = ["subtitle", "symbol", "tint", "leading", "trailing", "progress", "for", "id", "open", "tab", "activity", "name", "summary"]

        init(_ arguments: [String]) {
            var index = 0
            while index < arguments.count {
                let argument = arguments[index]
                if argument.hasPrefix("--") {
                    let key = String(argument.dropFirst(2))
                    if Self.valueKeys.contains(key), index + 1 < arguments.count {
                        values[key] = arguments[index + 1]
                        index += 1
                    } else {
                        flags.insert(key)
                    }
                } else {
                    positional.append(argument)
                }
                index += 1
            }
        }

        subscript(key: String) -> String? { values[key] }
    }
}
