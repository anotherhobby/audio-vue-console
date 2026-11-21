import Foundation

/// A scene document read as a layout the canvas edits, keeping each card's entry by its id, so
/// writing the layout back changes only its cells, groups and settings (design D6; `card-settings`
/// design D1).
public struct LaidOutScene: Sendable, Equatable {
    public let document: SceneDocument
    public let layout: SceneLayout
    /// The panel's grid, which the layout's is unless a card reaches past its last column.
    public let panel: CellSize
    /// Each card's entry as the document gave it, by the id the layout gave the card.
    let entries: [UUID: JSONValue]

    /// `document` laid out on `panel`, the panel's grid, or on as many columns as its furthest
    /// card reaches where that is more (`scene-layout`, "A scene too wide for the panel is laid
    /// out on its reach"). A card's unset `col` or `row` is 0, and an unset span covers the
    /// panel's grid (audio-vue `scene-grid`). Where `ids` has one id per card, the cards take them
    /// in order: a scene read again after a save keeps the ids the editor holds, since the host
    /// stores the cards in the order they were sent. `keeping` is a layout this one replaces
    /// under an open editor, whose columns it keeps: a scene too wide stays as wide until it is
    /// opened again.
    public init(
        _ document: SceneDocument, panel: CellSize, ids: [UUID]? = nil,
        keeping old: SceneLayout? = nil
    ) throws(LayoutRefusal) {
        let read = document.doc["cards"]?.arrayValue ?? []
        let ids = ids?.count == read.count ? ids : nil
        var cards: [LayoutCard] = []
        var entries: [UUID: JSONValue] = [:]
        for (index, entry) in read.enumerated() {
            let card = try Self.card(entry, on: panel, id: ids?[index] ?? UUID())
            cards.append(card)
            entries[card.id] = entry
        }
        let reach = max(cards.map(\.cells.maxCol).max() ?? 0, old?.grid.cols ?? 0)
        self.document = document
        self.panel = panel
        self.layout = try SceneLayout(
            grid: CellSize(cols: max(panel.cols, reach), rows: panel.rows), cards: cards)
        self.entries = entries
    }

    private init(
        document: SceneDocument, layout: SceneLayout, panel: CellSize, entries: [UUID: JSONValue]
    ) {
        self.document = document
        self.layout = layout
        self.panel = panel
        self.entries = entries
    }

    /// `layout` as a scene of its own, read from `document`: what a copy starts from. Each card
    /// keeps its id and the entry this scene writes for it, so the copy needs no second parse.
    func copy(_ layout: SceneLayout, as document: SceneDocument) -> LaidOutScene {
        LaidOutScene(
            document: document, layout: layout, panel: panel,
            entries: Dictionary(uniqueKeysWithValues: layout.cards.map { ($0.id, entry(for: $0)) }))
    }

    /// The scene as read: its layout and its blocks, the grid block without a size, which the
    /// host no longer takes (`scene-saving`, "A saved scene declares no grid size").
    public var content: SceneContent {
        var blocks = SceneContent.blocks(of: document.doc)
        if var grid = blocks[Self.gridBlock]?.objectValue {
            for key in Self.gridSize { grid[key] = nil }
            blocks[Self.gridBlock] = grid.isEmpty ? nil : .object(grid)
        }
        return SceneContent(layout: layout, blocks: blocks)
    }

    /// Whether the document as stored sets a grid size, so the host refuses it until it is saved
    /// again without one.
    public var declaresGridSize: Bool {
        Self.gridSize.contains { document.doc[Self.gridBlock]?[$0] != nil }
    }

    private static let gridBlock = "grid"
    private static let gridSize = ["cols", "rows"]

    /// The document's `doc` with its blocks as `content` holds them and its cards as its layout
    /// places them, in its order: each card's original entry with its cells, group and `params`
    /// replaced, and a new card's entry those alone. A card with no settings is written with no
    /// `params`. No grid size is written: the grid is the panel's (`scene-saving`, "A saved scene
    /// declares no grid size").
    public func doc(for content: SceneContent) -> JSONValue {
        var fields = content.blocks
        fields["name"] = document.doc["name"]
        fields["cards"] = .array(content.layout.cards.map(entry(for:)))
        return .object(fields)
    }

    /// Whether `content`, an edit of this scene, places a card past the panel's last column, so
    /// the panel would refuse to draw it (audio-vue `scene-grid`, "A scene too wide for the
    /// display is refused").
    public func isTooWide(_ content: SceneContent) -> Bool {
        content.layout.cards.contains { $0.cells.maxCol > panel.cols }
    }

    /// The document with the blocks as read and the cards as `layout` places them, as a library
    /// tile is drawn.
    public func doc(for layout: SceneLayout) -> JSONValue {
        doc(for: content.with(layout: layout))
    }

    private func entry(for card: LayoutCard) -> JSONValue {
        var fields = entries[card.id]?.objectValue ?? ["card": .string(card.kind)]
        fields["col"] = .integer(card.cells.col)
        fields["row"] = .integer(card.cells.row)
        // A span the entry leaves unset stays unset while the card still covers the panel's
        // grid that way, so it covers any panel's (`scene-saving`, "An unset span is kept until
        // its card is resized").
        let fillsCols = card.cells.col == 0 && card.cells.cols == panel.cols
        let fillsRows = card.cells.row == 0 && card.cells.rows == panel.rows
        fields["colspan"] =
            fields["colspan"] == nil && fillsCols ? nil : .integer(card.cells.cols)
        fields["rowspan"] =
            fields["rowspan"] == nil && fillsRows ? nil : .integer(card.cells.rows)
        fields["group"] = card.group.map(JSONValue.string)
        fields["params"] = card.settings.isEmpty ? nil : .object(card.settings)
        return .object(fields)
    }

    private static func card(_ entry: JSONValue, on grid: CellSize, id: UUID) throws(LayoutRefusal)
        -> LayoutCard
    {
        guard let kind = entry["card"]?.stringValue else { throw .unreadableCard }
        let cells = CellRect(
            col: try cell(entry["col"], unset: 0), row: try cell(entry["row"], unset: 0),
            cols: try cell(entry["colspan"], unset: grid.cols),
            rows: try cell(entry["rowspan"], unset: grid.rows))
        let group = entry["group"]?.stringValue
        return LayoutCard(
            id: id, kind: kind, cells: cells, group: group, settings: try settings(entry["params"]))
    }

    /// A card entry's `params`, none where it is missing or null.
    private static func settings(_ value: JSONValue?) throws(LayoutRefusal) -> [String: JSONValue] {
        switch value {
        case nil, .null?: return [:]
        case .object(let settings)?: return settings
        default: throw .unreadableCard
        }
    }

    /// A cell field's whole number, `unset` where it is missing or null.
    private static func cell(_ value: JSONValue?, unset: Int) throws(LayoutRefusal) -> Int {
        switch value {
        case nil, .null?: return unset
        case .integer(let number)?: return number
        default: throw .unreadableCard
        }
    }
}
