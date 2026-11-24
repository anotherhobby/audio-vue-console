import Foundation

/// What a scene's edits change (`scene-settings`, design D1): its cards on the grid, and its own
/// blocks, every top-level key of its document but `cards` and `name`. The grid's `cols` and `rows`
/// are the layout's; `grid` in `blocks` holds the rest of that block, such as `gap`.
public struct SceneContent: Sendable, Hashable {
    public var layout: SceneLayout
    /// The scene's blocks as edited, by key, each as its document holds it.
    public var blocks: [String: JSONValue]
    /// The cards set aside off the panel while the scene is edited (`card-parking`): each wholly
    /// off the layout's grid, none overlapping, and a group wholly here or wholly on the grid.
    /// They are never written, drawn as the scene, or counted as its reach.
    public internal(set) var parked: [LayoutCard]
    /// The whole entries of cards added in the editor by a paste, by id: what each brings from the
    /// scene it was copied from, which this scene's parse holds none of (`card-clipboard`, design D2).
    public internal(set) var entries: [UUID: JSONValue]

    public init(
        layout: SceneLayout, blocks: [String: JSONValue] = [:], parked: [LayoutCard] = [],
        entries: [UUID: JSONValue] = [:]
    ) {
        self.layout = layout
        self.blocks = blocks
        self.parked = parked
        self.entries = entries
    }

    /// This content with its cards placed as `layout` places them, the parked cards and added
    /// cards' entries kept.
    public func with(layout: SceneLayout) -> SceneContent {
        SceneContent(layout: layout, blocks: blocks, parked: parked, entries: entries)
    }

    /// Every card of the scene: the layout's, then the parked ones.
    public var cards: [LayoutCard] { layout.cards + parked }

    public func card(_ id: UUID) -> LayoutCard? {
        cards.first { $0.id == id }
    }

    /// `ids` with every other card of any group they reach, on the grid or parked, since a group
    /// is edited as one.
    public func widened(_ ids: Set<UUID>) -> Set<UUID> {
        let reached = Set(cards.filter { ids.contains($0.id) }.compactMap(\.group))
        let widened = cards.filter { card in
            ids.contains(card.id) || card.group.map(reached.contains) == true
        }
        return Set(widened.map(\.id))
    }

    /// The lowest `group-N` not among `taken`: a new group's name.
    static func groupName(notIn taken: Set<String>) -> String {
        var number = 1
        while taken.contains("group-\(number)") { number += 1 }
        return "group-\(number)"
    }

    /// The blocks of the scene document `doc`: its keys but `cards` and `name`.
    static func blocks(of doc: JSONValue) -> [String: JSONValue] {
        (doc.objectValue ?? [:]).filter { !notBlocks.contains($0.key) }
    }

    private static let notBlocks: Set<String> = ["cards", "name"]
}
