import Foundation

/// Any JSON value: widget files, command output and API payloads are all read through this, so
/// user-written files never crash the app on an unexpected shape.
enum JSONValue: Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(_ any: Any?) {
        switch any {
        case nil, is NSNull: self = .null
        case let value as NSNumber where CFGetTypeID(value) == CFBooleanGetTypeID(): self = .bool(value.boolValue)
        case let value as NSNumber: self = .number(value.doubleValue)
        case let value as String: self = .string(value)
        case let value as [Any]: self = .array(value.map { JSONValue($0) })
        case let value as [String: Any]: self = .object(value.mapValues { JSONValue($0) })
        case let value as Bool: self = .bool(value)
        case let value as Double: self = .number(value)
        case let value as Int: self = .number(Double(value))
        default: self = .string(String(describing: any!))
        }
    }

    /// Parses JSON text; nil when it is not valid JSON.
    static func parse(_ data: Data) -> JSONValue? {
        guard let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return nil }
        return JSONValue(object)
    }

    var any: Any {
        switch self {
        case .null: NSNull()
        case .bool(let value): value
        // Shortest decimal form, so files read 1.35 and not 1.3500000000000001.
        case .number(let value): value.isFinite && value.rounded() != value ? NSDecimalNumber(string: "\(value)") : value
        case .string(let value): value
        case .array(let values): values.map(\.any)
        case .object(let values): values.mapValues(\.any)
        }
    }

    subscript(key: String) -> JSONValue? {
        if case .object(let values) = self { return values[key] }
        return nil
    }

    /// Follows a dotted path: `data.items.0.title`.
    func value(at path: String) -> JSONValue? {
        var current: JSONValue? = self
        for part in path.split(separator: ".").map(String.init) where !part.isEmpty {
            switch current {
            case .object(let values): current = values[part]
            case .array(let values):
                guard let index = Int(part), values.indices.contains(index) else { return nil }
                current = values[index]
            default: return nil
            }
        }
        return current
    }

    var string: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var double: Double? {
        switch self {
        case .number(let value): value
        case .string(let value): Double(value.trimmingCharacters(in: .whitespaces))
        case .bool(let value): value ? 1 : 0
        default: nil
        }
    }

    var bool: Bool? {
        switch self {
        case .bool(let value): value
        case .number(let value): value != 0
        case .string(let value): ["true", "yes", "1", "on"].contains(value.lowercased())
        default: nil
        }
    }

    var array: [JSONValue]? {
        if case .array(let values) = self { return values }
        return nil
    }

    var object: [String: JSONValue]? {
        if case .object(let values) = self { return values }
        return nil
    }

    /// Truthiness for `when` conditions: empty, zero, false and null are false.
    var isTruthy: Bool {
        switch self {
        case .null: false
        case .bool(let value): value
        case .number(let value): value != 0
        case .string(let value): !["", "0", "false"].contains(value.lowercased())
        case .array(let values): !values.isEmpty
        case .object(let values): !values.isEmpty
        }
    }

    /// Text shown when a value is interpolated into a string.
    var text: String {
        switch self {
        case .null: ""
        case .bool(let value): value ? "true" : "false"
        case .number(let value):
            value.rounded() == value && abs(value) < 1e15 ? String(Int64(value)) : Self.decimal(value)
        case .string(let value): value
        case .array, .object:
            (try? JSONSerialization.data(withJSONObject: any, options: [.fragmentsAllowed])).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        }
    }

    /// At most two decimals, without trailing zeros: 3.4, 0.25, 12.
    static func decimal(_ value: Double) -> String {
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }
}

/// `{{data.count}}`, `{{item.title | upper}}`: resolves template strings against a scope.
/// A string that is exactly one `{{…}}` keeps the value's type (numbers for gauges, arrays for
/// lists); anything else becomes text.
enum Template {
    static func resolve(_ value: JSONValue?, in scope: JSONValue) -> JSONValue? {
        guard case .string(let raw) = value else { return value }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("{{"), trimmed.hasSuffix("}}"), trimmed.components(separatedBy: "{{").count == 2 {
            return evaluate(String(trimmed.dropFirst(2).dropLast(2)), in: scope)
        }
        return .string(interpolate(raw, in: scope))
    }

    static func text(_ value: JSONValue?, in scope: JSONValue) -> String {
        resolve(value, in: scope)?.text ?? ""
    }

    static func interpolate(_ raw: String, in scope: JSONValue) -> String {
        var output = ""
        var rest = Substring(raw)
        while let open = rest.range(of: "{{") {
            output += rest[..<open.lowerBound]
            guard let close = rest.range(of: "}}", range: open.upperBound..<rest.endIndex) else {
                output += rest[open.lowerBound...]
                return output
            }
            output += evaluate(String(rest[open.upperBound..<close.lowerBound]), in: scope)?.text ?? ""
            rest = rest[close.upperBound...]
        }
        return output + rest
    }

    /// `path | filter | filter`. Unknown paths resolve to null, unknown filters are ignored.
    static func evaluate(_ expression: String, in scope: JSONValue) -> JSONValue? {
        let parts = expression.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let path = parts.first else { return nil }
        var value: JSONValue = literal(path) ?? scope.value(at: path) ?? .null
        for filter in parts.dropFirst() { value = apply(filter, to: value) }
        return value
    }

    private static func literal(_ token: String) -> JSONValue? {
        if token.hasPrefix("'"), token.hasSuffix("'"), token.count >= 2 { return .string(String(token.dropFirst().dropLast())) }
        if let number = Double(token) { return .number(number) }
        return nil
    }

    private static func apply(_ filter: String, to value: JSONValue) -> JSONValue {
        let name = filter.split(separator: " ").first.map(String.init) ?? filter
        let argument = filter.dropFirst(name.count).trimmingCharacters(in: .whitespaces)
        switch name {
        case "upper": return .string(value.text.uppercased())
        case "lower": return .string(value.text.lowercased())
        case "round": return value.double.map { .number($0.rounded()) } ?? value
        case "percent": return value.double.map { .string("\(Int(($0 <= 1 ? $0 * 100 : $0).rounded()))%") } ?? value
        case "bytes": return value.double.map { .string(ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file)) } ?? value
        case "count": return .number(Double(value.array?.count ?? value.object?.count ?? value.text.count))
        case "first": return value.array?.first ?? value
        case "last": return value.array?.last ?? value
        case "default": return value.isTruthy ? value : (literal(argument) ?? .string(argument))
        case "not": return .bool(!value.isTruthy)
        case "relative":
            guard let date = date(from: value) else { return value }
            return .string(RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date()))
        case "div":
            guard let number = value.double, let divisor = Double(argument), divisor != 0 else { return value }
            return .number(number / divisor)
        default: return value
        }
    }

    private static func date(from value: JSONValue) -> Date? {
        if let seconds = value.double, seconds > 1_000_000_000 {
            return Date(timeIntervalSince1970: seconds > 1e12 ? seconds / 1000 : seconds)
        }
        guard let text = value.string else { return nil }
        return ISO8601DateFormatter().date(from: text)
    }
}
