import Foundation

/// A scene document read as a layout the canvas edits, keeping each card's entry by its id, so
/// writing the layout back changes only its cells and groups (design D6).
public struct LaidOutScene: Sendable, Equatable {
    public let document: SceneDocument
    public let layout: SceneLayout
    /// Each card's entry as the document gave it, by the id the layout gave the card.
    let entries: [UUID: JSONValue]

    /// `document` laid out on its grid, or on `defaultGrid` where it declares none. A card's unset
    /// `col` or `row` is 0, and an unset span covers the grid (audio-vue `scene-grid`).
    public init(_ document: SceneDocument, defaultGrid: CellSize) throws(LayoutRefusal) {
        let grid = CellSize(
            cols: document.doc["grid"]?["cols"]?.intValue ?? defaultGrid.cols,
            rows: document.doc["grid"]?["rows"]?.intValue ?? defaultGrid.rows)
        var cards: [LayoutCard] = []
        var entries: [UUID: JSONValue] = [:]
        for entry in document.doc["cards"]?.arrayValue ?? [] {
            let card = try Self.card(entry, on: grid)
            cards.append(card)
            entries[card.id] = entry
        }
        self.document = document
        self.layout = try SceneLayout(grid: grid, cards: cards)
        self.entries = entries
    }

    /// The document's `doc` with its cards as `layout` places them, in its order: each card's
    /// original entry with its cells and group replaced, and a new card's entry those alone.
    public func doc(for layout: SceneLayout) -> JSONValue {
        var fields = document.doc.objectValue ?? [:]
        fields["cards"] = .array(layout.cards.map(entry(for:)))
        return .object(fields)
    }

    private func entry(for card: LayoutCard) -> JSONValue {
        var fields = entries[card.id]?.objectValue ?? ["card": .string(card.kind)]
        fields["col"] = .integer(card.cells.col)
        fields["row"] = .integer(card.cells.row)
        fields["colspan"] = .integer(card.cells.cols)
        fields["rowspan"] = .integer(card.cells.rows)
        fields["group"] = card.group.map(JSONValue.string)
        return .object(fields)
    }

    private static func card(_ entry: JSONValue, on grid: CellSize) throws(LayoutRefusal)
        -> LayoutCard
    {
        guard let kind = entry["card"]?.stringValue else { throw .unreadableCard }
        let cells = CellRect(
            col: try cell(entry["col"], unset: 0), row: try cell(entry["row"], unset: 0),
            cols: try cell(entry["colspan"], unset: grid.cols),
            rows: try cell(entry["rowspan"], unset: grid.rows))
        let group = entry["group"]?.stringValue
        return LayoutCard(kind: kind, cells: cells, group: group)
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
