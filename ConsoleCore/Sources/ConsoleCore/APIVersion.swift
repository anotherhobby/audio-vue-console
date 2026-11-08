/// A host API's semantic version, read by its numeric core: `2.4.2-rc.1+abc` is 2.4.2.
public struct APIVersion: Sendable, Hashable, CustomStringConvertible {
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

    /// How this version stands against the API of the contract bundled with the app, the one
    /// version it speaks (`host-connection`).
    public var compatibility: Compatibility {
        compatibility(with: .bundled)
    }

    /// How this version stands against `contract`'s, by the numeric core: any part that differs
    /// makes the host newer or older.
    public func compatibility(with contract: SavedContract) -> Compatibility {
        let theirs = contract.version.core
        if core == theirs { return .compatible }
        return core.lexicographicallyPrecedes(theirs) ? .hostOlder : .hostNewer
    }

    /// Major, minor and patch, in the order they rank.
    private var core: [Int] { [major, minor, patch] }
}
