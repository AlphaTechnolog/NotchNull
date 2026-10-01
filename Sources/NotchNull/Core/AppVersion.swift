import Foundation

/// A release number like 1.4.0, compared part by part so 1.10.0 is newer than 1.9.2.
struct AppVersion: Comparable, CustomStringConvertible {
    let parts: [Int]

    /// Accepts "1.4.0" and a tag like "v1.4.0"; nil for anything that is not dotted numbers.
    init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let numbers = (trimmed.hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed).split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !numbers.isEmpty, numbers.allSatisfy({ $0 != nil && $0! >= 0 }) else { return nil }
        parts = numbers.compactMap { $0 }
    }

    /// The running app's version; a build run from source without a bundle counts as 0.
    static var current: AppVersion {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap(AppVersion.init) ?? AppVersion("0")!
    }

    var description: String { parts.map(String.init).joined(separator: ".") }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        for index in 0..<max(lhs.parts.count, rhs.parts.count) {
            let left = index < lhs.parts.count ? lhs.parts[index] : 0
            let right = index < rhs.parts.count ? rhs.parts[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool { !(lhs < rhs) && !(rhs < lhs) }
}
