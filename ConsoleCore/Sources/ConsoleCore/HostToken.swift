/// A token a host gave this app when it paired, sent as `Authorization: Bearer`. Its description
/// hides the value, so a token printed by mistake does not land in a log.
public struct HostToken: Sendable, Hashable, Codable, CustomStringConvertible {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public init(from decoder: any Decoder) throws {
        value = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    public var description: String { "HostToken(…)" }
}
