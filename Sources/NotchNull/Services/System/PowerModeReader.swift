import Foundation

/// The Energy Mode chosen in System Settings › Battery for the current power source.
enum PowerMode: Int, Equatable {
    case automatic = 0
    case low = 1
    case high = 2

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .low: "Low Power"
        case .high: "High Power"
        }
    }
}

/// Reads the active energy mode from `pmset -g`, which reports the settings of the current source.
/// macOS posts no notification when High Power is toggled, so callers poll it off the main thread.
enum PowerModeReader {
    static func read() -> PowerMode {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return fallback
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return parse(String(decoding: data, as: UTF8.self)) ?? fallback
    }

    /// Finds `powermode N` (or the older `lowpowermode 1`) in pmset output.
    static func parse(_ output: String) -> PowerMode? {
        var legacyLow: Bool?
        for line in output.split(separator: "\n") {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count >= 2, let value = Int(fields[1]) else { continue }
            switch fields[0] {
            case "powermode": return PowerMode(rawValue: value) ?? .automatic
            case "lowpowermode": legacyLow = value == 1
            default: continue
            }
        }
        return legacyLow.map { $0 ? .low : .automatic }
    }

    private static var fallback: PowerMode {
        ProcessInfo.processInfo.isLowPowerModeEnabled ? .low : .automatic
    }
}
