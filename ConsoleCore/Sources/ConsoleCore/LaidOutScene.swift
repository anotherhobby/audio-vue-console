import Foundation

/// A scene document read as a layout the canvas edits, keeping each card's entry by its id, so
/// writing the layout back changes only its cells, groups and settings (design D6; `card-settings`
/// design D1).
public struct LaidOutScene: Sendable, Equatable {
    public let document: SceneDocument
    public let layout: SceneLayout
    /// Each card's entry as the document gave it, by the id the layout gave the card.
    let entries: [UUID: JSONValue]

    /// `document` laid out on its grid, or on `defaultGrid` where it declares none. A card's unset
    /// `col` or `row` is 0, and an unset span covers the grid (audio-vue `scene-grid`). Where `ids`
    /// has one id per card, the cards take them in order: a scene read again after a save keeps
    /// the ids the editor holds, since the host stores the cards in the order they were sent.
    public init(_ document: SceneDocument, defaultGrid: CellSize, ids: [UUID]? = nil)
        throws(LayoutRefusal)
    {
        let grid = CellSize(
            cols: document.doc["grid"]?["cols"]?.intValue ?? defaultGrid.cols,
            rows: document.doc["grid"]?["rows"]?.intValue ?? defaultGrid.rows)
        let read = document.doc["cards"]?.arrayValue ?? []
        let ids = ids?.count == read.count ? ids : nil
        var cards: [LayoutCard] = []
        var entries: [UUID: JSONValue] = [:]
        for (index, entry) in read.enumerated() {
            let card = try Self.card(entry, on: grid, id: ids?[index] ?? UUID())
            cards.append(card)
            entries[card.id] = entry
        }
        self.document = document
        self.layout = try SceneLayout(grid: grid, cards: cards)
        self.entries = entries
    }

    private init(document: SceneDocument, layout: SceneLayout, entries: [UUID: JSONValue]) {
        self.document = document
        self.layout = layout
        self.entries = entries
    }

    /// `layout` as a scene of its own, read from `document`: what a copy starts from. Each card
    /// keeps its id and the entry this scene writes for it, so the copy needs no second parse.
    func copy(_ layout: SceneLayout, as document: SceneDocument) -> LaidOutScene {
        LaidOutScene(
            document: document, layout: layout,
            entries: Dictionary(uniqueKeysWithValues: layout.cards.map { ($0.id, entry(for: $0)) }))
    }

    /// The scene as read: its layout and its blocks.
    public var content: SceneContent {
        SceneContent(layout: layout, blocks: SceneContent.blocks(of: document.doc))
    }

    /// The document's `doc` with its blocks as `content` holds them and its cards as its layout
    /// places them, in its order: each card's original entry with its cells, group and `params`
    /// replaced, and a new card's entry those alone. A card with no settings is written with no
    /// `params`. The grid's `cols` and `rows` are written where the layout's grid is not the one
    /// read, so a scene that declares no grid is written with none until its grid changes
    /// (`scene-settings`, design D1).
    public func doc(for content: SceneContent) -> JSONValue {
        var fields = content.blocks
        fields["name"] = document.doc["name"]
        fields["cards"] = .array(content.layout.cards.map(entry(for:)))
        if content.layout.grid != layout.grid {
            var grid = fields["grid"]?.objectValue ?? [:]
            grid["cols"] = .integer(content.layout.grid.cols)
            grid["rows"] = .integer(content.layout.grid.rows)
            fields["grid"] = .object(grid)
        }
        return .object(fields)
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
        fields["colspan"] = .integer(card.cells.cols)
        fields["rowspan"] = .integer(card.cells.rows)
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
