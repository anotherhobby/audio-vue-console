import Foundation
import OpenAPIRuntime

/// Any JSON value, kept as the host wrote it so a document passes through the app untouched: a
/// scene's params, plate colours and alternates go back to the host, and to the render helper, as
/// they came. Integers and decimals are kept apart, so a cell is never sent back as `48.0` (design D6).
public enum JSONValue: Sendable, Hashable {
    case null
    case bool(Bool)
    case integer(Int)
    case decimal(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    /// The value under `key` in an object, or nil for a key it lacks or a value that is no object.
    public subscript(key: String) -> JSONValue? {
        guard case .object(let fields) = self else { return nil }
        return fields[key]
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let fields) = self { return fields }
        return nil
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let items) = self { return items }
        return nil
    }

    public var stringValue: String? {
        if case .string(let text) = self { return text }
        return nil
    }

    public var intValue: Int? {
        if case .integer(let number) = self { return number }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let flag) = self { return flag }
        return nil
    }

    /// The value as JSON text's bytes, keys sorted so the same value always writes the same bytes.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    /// A value the generated client decoded, read again as JSON: the runtime's containers hold the
    /// same JSON, typed loosely.
    init(_ container: some Encodable) throws {
        self = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(container))
    }
}

extension JSONValue: Codable {
    /// Reads null, then a flag, an integer, a decimal, text, a list and an object, in that order, so a
    /// number with no fraction is an integer.
    public init(from decoder: any Decoder) throws {
        let single = try decoder.singleValueContainer()
        if single.decodeNil() {
            self = .null
        } else if let flag = Self.read(Bool.self, from: single) {
            self = .bool(flag)
        } else if let number = Self.read(Int.self, from: single) {
            self = .integer(number)
        } else if let number = Self.read(Double.self, from: single) {
            self = .decimal(number)
        } else if let text = Self.read(String.self, from: single) {
            self = .string(text)
        } else if let items = Self.read([JSONValue].self, from: single) {
            self = .array(items)
        } else {
            self = .object(try single.decode([String: JSONValue].self))
        }
    }

    /// The value read as `type`, or nil where it is JSON of another type. Every failure means that
    /// here: Foundation says a decimal read as an integer with an error of its own, not a
    /// `DecodingError`. A value that is no JSON type at all fails the last read, as an object.
    private static func read<Value: Decodable>(
        _ type: Value.Type, from single: any SingleValueDecodingContainer
    ) -> Value? {
        do {
            return try single.decode(type)
        } catch {
            return nil
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var single = encoder.singleValueContainer()
        switch self {
        case .null: try single.encodeNil()
        case .bool(let flag): try single.encode(flag)
        case .integer(let number): try single.encode(number)
        case .decimal(let number): try single.encode(number)
        case .string(let text): try single.encode(text)
        case .array(let items): try single.encode(items)
        case .object(let fields): try single.encode(fields)
        }
    }
}
