import Foundation

/// A size in cells: a scene's grid, or a card's span.
public struct CellSize: Sendable, Hashable {
    public let cols: Int
    public let rows: Int

    public init(cols: Int, rows: Int) {
        self.cols = cols
        self.rows = rows
    }
}

/// One cell of the grid, counted from the top left, row 0 at the top as in audio-vue's scenes.
public struct Cell: Sendable, Hashable {
    public let col: Int
    public let row: Int

    public init(col: Int, row: Int) {
        self.col = col
        self.row = row
    }
}

/// A shift by whole cells.
public struct CellOffset: Sendable, Hashable {
    public let cols: Int
    public let rows: Int

    public static let zero = CellOffset(cols: 0, rows: 0)

    public init(cols: Int, rows: Int) {
        self.cols = cols
        self.rows = rows
    }
}

/// A block of grid cells: its top-left cell and its size.
public struct CellRect: Sendable, Hashable {
    public var col: Int
    public var row: Int
    public var cols: Int
    public var rows: Int

    public init(col: Int, row: Int, cols: Int, rows: Int) {
        self.col = col
        self.row = row
        self.cols = cols
        self.rows = rows
    }

    /// The smallest block holding every one of `blocks`, or nil for none.
    public init?(enclosing blocks: some Sequence<CellRect>) {
        var blocks = blocks.makeIterator()
        guard let first = blocks.next() else { return nil }
        var (left, top, right, bottom) = (first.col, first.row, first.maxCol, first.maxRow)
        while let block = blocks.next() {
            left = min(left, block.col)
            top = min(top, block.row)
            right = max(right, block.maxCol)
            bottom = max(bottom, block.maxRow)
        }
        self.init(col: left, row: top, cols: right - left, rows: bottom - top)
    }

    /// One past the block's last column.
    public var maxCol: Int { col + cols }
    /// One past the block's last row.
    public var maxRow: Int { row + rows }
    public var area: Int { cols * rows }

    public func intersects(_ other: CellRect) -> Bool {
        sharesCols(with: other) && sharesRows(with: other)
    }

    public func contains(_ other: CellRect) -> Bool {
        col <= other.col && other.maxCol <= maxCol && row <= other.row && other.maxRow <= maxRow
    }

    public func offset(by offset: CellOffset) -> CellRect {
        CellRect(col: col + offset.cols, row: row + offset.rows, cols: cols, rows: rows)
    }

    /// Whether the two blocks have a column in common, whatever their rows.
    func sharesCols(with other: CellRect) -> Bool {
        col < other.maxCol && other.col < maxCol
    }

    /// Whether the two blocks have a row in common, whatever their columns.
    func sharesRows(with other: CellRect) -> Bool {
        row < other.maxRow && other.row < maxRow
    }
}

/// One card placed on a layout. Its id tells two cards of one kind apart while they are edited,
/// since a scene file gives cards none.
public struct LayoutCard: Sendable, Hashable, Identifiable {
    public let id: UUID
    /// The card's name in audio-vue, such as `rta_bars`.
    public let kind: String
    public var cells: CellRect
    /// The declared group the card belongs to, if any.
    public var group: String?

    public init(id: UUID = UUID(), kind: String, cells: CellRect, group: String? = nil) {
        self.id = id
        self.kind = kind
        self.cells = cells
        self.group = group
    }
}

/// A scene's cards on its grid. A layout is always one the panel would load: every card lies on
/// the grid, no two overlap, and every group tiles a rectangle (`scene-layout`).
public struct SceneLayout: Sendable, Hashable {
    public let grid: CellSize
    public private(set) var cards: [LayoutCard]

    /// A layout of `cards`, refused if any runs off the grid, two overlap, or a group does not tile
    /// a rectangle.
    public init(grid: CellSize, cards: [LayoutCard]) throws(LayoutRefusal) {
        self.grid = grid
        self.cards = cards
        for card in cards where !bounds.contains(card.cells) { throw .offGrid }
        for (index, card) in cards.enumerated() {
            for other in cards.dropFirst(index + 1) where card.cells.intersects(other.cells) {
                throw .spaceTaken
            }
        }
        for members in groups.values {
            if let refusal = Self.tilingRefusal(members, among: cards) { throw refusal }
        }
    }

    /// A layout an edit has already checked.
    init(checked grid: CellSize, cards: [LayoutCard]) {
        self.grid = grid
        self.cards = cards
    }

    /// The whole grid, as a block.
    public var bounds: CellRect { CellRect(col: 0, row: 0, cols: grid.cols, rows: grid.rows) }

    public func card(_ id: UUID) -> LayoutCard? {
        cards.first { $0.id == id }
    }

    /// Each declared group's cards, by group name.
    public var groups: [String: [LayoutCard]] {
        Dictionary(grouping: cards.filter { $0.group != nil }) { $0.group ?? "" }
    }

    /// `ids` with every other card of any group they reach, since a group is edited as one.
    public func widened(_ ids: Set<UUID>) -> Set<UUID> {
        let reached = Set(cards.filter { ids.contains($0.id) }.compactMap(\.group))
        let widened = cards.filter { card in
            ids.contains(card.id) || card.group.map(reached.contains) == true
        }
        return Set(widened.map(\.id))
    }

    /// Why `chosen` cannot be one group among `cards`, or nil when they tile a rectangle with no
    /// other card inside it (audio-vue `scene-plate`).
    static func tilingRefusal(_ chosen: [LayoutCard], among cards: [LayoutCard]) -> LayoutRefusal? {
        guard let rectangle = CellRect(enclosing: chosen.map(\.cells)) else { return .tooFewCards }
        let ids = Set(chosen.map(\.id))
        if cards.contains(where: { !ids.contains($0.id) && $0.cells.intersects(rectangle) }) {
            return .cardInTheWay
        }
        // Cards never overlap, so their areas add up to the rectangle's only if they fill it.
        if chosen.map(\.cells.area).reduce(0, +) != rectangle.area { return .notARectangle }
        return nil
    }
}
