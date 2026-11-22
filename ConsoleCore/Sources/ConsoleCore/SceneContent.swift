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

    public init(
        layout: SceneLayout, blocks: [String: JSONValue] = [:], parked: [LayoutCard] = []
    ) {
        self.layout = layout
        self.blocks = blocks
        self.parked = parked
    }

    /// This content with its cards placed as `layout` places them, the parked cards kept.
    public func with(layout: SceneLayout) -> SceneContent {
        SceneContent(layout: layout, blocks: blocks, parked: parked)
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

    /// The blocks of the scene document `doc`: its keys but `cards` and `name`.
    static func blocks(of doc: JSONValue) -> [String: JSONValue] {
        (doc.objectValue ?? [:]).filter { !notBlocks.contains($0.key) }
    }

    private static let notBlocks: Set<String> = ["cards", "name"]
}
