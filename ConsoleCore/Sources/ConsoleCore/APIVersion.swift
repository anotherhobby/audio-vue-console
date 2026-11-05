/// A host API's semantic version, read by its numeric core: `2.4.2-rc.1+abc` is 2.4.2.
public struct APIVersion: Sendable, Hashable, CustomStringConvertible {
    /// The one major version this app speaks. Minor releases are taken to be additive.
    public static let supportedMajor = 2

    public let major: Int
    public let minor: Int
    public let patch: Int
    /// The version as the host gave it.
    public let description: String

    /// How a host's API stands against this app's.
    public enum Compatibility: Sendable, Equatable {
        case compatible
        case hostNewer
        case hostOlder
    }

    /// Reads `text` as `MAJOR.MINOR.PATCH`, with any pre-release or build suffix ignored, or returns
    /// nil when it is not semantic versioning.
    public init?(parsing text: String) {
        let core = text.prefix { $0 != "-" && $0 != "+" }
        var fields = core.split(separator: ".", omittingEmptySubsequences: false).makeIterator()
        guard let major = fields.next().flatMap(Self.number),
            let minor = fields.next().flatMap(Self.number),
            let patch = fields.next().flatMap(Self.number),
            fields.next() == nil
        else { return nil }
        self.major = major
        self.minor = minor
        self.patch = patch
        description = text
    }

    /// One field of the numeric core: ASCII digits only, so no sign or space slips through `Int`.
    private static func number(_ field: Substring) -> Int? {
        guard !field.isEmpty, field.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(field)
    }

    public var compatibility: Compatibility {
        if major > Self.supportedMajor { return .hostNewer }
        if major < Self.supportedMajor { return .hostOlder }
        return .compatible
    }
}
