/// How the card code the app carries differs from the code a panel runs, entry by entry
/// (`card-code`, design D8). Each manifest maps every card to the entry of the family directory that
/// declares it (`cards`); an entry no card maps to is shared code, a font or an asset.
public struct CardDrift: Sendable, Equatable {
    /// Where the host's manifest came from: the running panel, or the host's files.
    public let source: CardCode.Source
    /// The card families whose entries differ, by directory name.
    public let families: Set<String>
    /// The shared entries that differ, by repository path.
    public let shared: [String]
    /// The entries that differ, by repository path.
    let differing: Set<String>
    /// Each card's family entry, as either manifest gives it.
    let entries: [String: Set<String>]

    /// The entries that differ between the app's `bundled` manifest and the `host`'s, including
    /// entries only one of them has.
    public static func between(
        bundled: CardManifest, host: CardManifest, source: CardCode.Source
    ) -> CardDrift {
        let keys = Set(bundled.entries.keys).union(host.entries.keys)
        let differing = keys.filter { bundled.entries[$0] != host.entries[$0] }
        let familyEntries = Set(bundled.cards.values).union(host.cards.values)
        let entries = bundled.cards.mapValues { Set([$0]) }
            .merging(host.cards.mapValues { Set([$0]) }) { $0.union($1) }
        return CardDrift(
            source: source,
            families: Set(differing.intersection(familyEntries).map(Self.directoryName)),
            shared: differing.subtracting(familyEntries).sorted(), differing: differing,
            entries: entries)
    }

    /// Whether no card can be drawn: shared code differs, and every card draws through it.
    public var sharesNothing: Bool { !shared.isEmpty }

    /// Whether the card `name` must be drawn as a plain box: its family's entry differs, in either
    /// manifest, or neither manifest declares it, so the panel's code for it cannot be told.
    public func boxes(_ name: String) -> Bool {
        guard let known = entries[name] else { return true }
        return !known.isDisjoint(with: differing)
    }

    /// `src/cards/peak_rms` is `peak_rms`.
    private static func directoryName(_ entry: String) -> String {
        String(entry.split(separator: "/").last ?? Substring(entry))
    }

    /// The most names a message lists before it counts the rest.
    static let namesListed = 3

    /// `names` for a message: up to `namesListed` of them, then how many more.
    public static func listed(_ names: [String]) -> String {
        let shown = names.prefix(namesListed).joined(separator: ", ")
        let more = names.count - namesListed
        return more > 0 ? "\(shown) and \(more) more" : shown
    }
}
