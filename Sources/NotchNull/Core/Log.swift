import OSLog

/// Structured logging facade over the unified logging system (`log stream --predicate 'subsystem == "dev.notchnull.app"'`).
enum Log {
    static let app = Logger(subsystem: Constants.bundleIdentifier, category: "app")
    static let window = Logger(subsystem: Constants.bundleIdentifier, category: "window")
    static let media = Logger(subsystem: Constants.bundleIdentifier, category: "media")
    static let agents = Logger(subsystem: Constants.bundleIdentifier, category: "agents")
    static let system = Logger(subsystem: Constants.bundleIdentifier, category: "system")
    static let files = Logger(subsystem: Constants.bundleIdentifier, category: "files")
}
