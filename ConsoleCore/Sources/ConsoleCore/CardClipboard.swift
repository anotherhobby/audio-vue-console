import Foundation

/// Cards copied from a scene as the pasteboard carries them: each card's whole entry as its scene
/// writes it, so a paste brings every field, settings included, and the parse that reads a scene
/// reads them back (`card-clipboard`, design D1).
public struct CopiedCards: Sendable, Equatable {
    /// The private type the pasteboard carries copied cards under, declared by the app.
    public static let typeIdentifier = "com.hobbysprawl.AudioVueConsole.cards"

    /// Each copied card's entry, in the scene's order.
    public let entries: [JSONValue]

    /// The cards `ids` reach in `content`, whole groups, on the grid or parked, each as `laidOut`
    /// would write it; nil where `ids` reaches no card.
    public init?(_ ids: Set<UUID>, of content: SceneContent, in laidOut: LaidOutScene) {
        let reached = content.widened(ids)
        let cards = content.cards.filter { reached.contains($0.id) }
        guard !cards.isEmpty else { return nil }
        entries = laidOut.entries(of: cards, in: content)
    }

    /// Copied cards of `entries`, each a card's entry as its scene writes it.
    public init(entries: [JSONValue]) {
        self.entries = entries
    }

    /// Copied cards read from the pasteboard's `data`, nil where it holds no array of entries.
    public init?(data: Data) {
        do {
            guard let entries = try JSONDecoder().decode(JSONValue.self, from: data).arrayValue,
                !entries.isEmpty
            else { return nil }
            self.entries = entries
        } catch {
            return nil
        }
    }

    /// The entries as the pasteboard carries them.
    public var data: Data {
        do {
            return try JSONEncoder().encode(JSONValue.array(entries))
        } catch {
            // An array of decoded JSON always encodes.
            return Data()
        }
    }

    /// The copied cards laid out on `grid`, each with a fresh id at every read, so pasting twice
    /// adds two sets of cards, as they were copied: their cells, groups and settings, and their
    /// entries by the new ids. Refused where an entry cannot be read.
    public func cards(on grid: CellSize) throws(LayoutRefusal) -> Pasting {
        var pasting = Pasting(cards: [], entries: [:])
        for entry in entries {
            let card = try LaidOutScene.card(entry, on: grid, id: UUID())
            pasting.cards.append(card)
            pasting.entries[card.id] = entry
        }
        return pasting
    }

    /// Copied cards read for one paste: the cards with fresh ids, and each one's whole entry.
    public struct Pasting: Sendable, Equatable {
        public var cards: [LayoutCard]
        public var entries: [UUID: JSONValue]

        public init(cards: [LayoutCard], entries: [UUID: JSONValue]) {
            self.cards = cards
            self.entries = entries
        }
    }
}
