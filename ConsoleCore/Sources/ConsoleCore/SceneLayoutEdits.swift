import Foundation

/// The edges of a card a resize drags.
public struct CardEdges: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let left = CardEdges(rawValue: 1 << 0)
    public static let right = CardEdges(rawValue: 1 << 1)
    public static let top = CardEdges(rawValue: 1 << 2)
    public static let bottom = CardEdges(rawValue: 1 << 3)

    /// The same edges with rows and columns swapped: top for left, bottom for right.
    var transposed: CardEdges {
        var edges: CardEdges = []
        if contains(.left) { edges.insert(.top) }
        if contains(.right) { edges.insert(.bottom) }
        if contains(.top) { edges.insert(.left) }
        if contains(.bottom) { edges.insert(.right) }
        return edges
    }
}

/// The edits a layout takes, each returning a new layout or refusing (`scene-layout`).
extension SceneLayout {
    /// A card of `kind` and `size` added centred on `cell`, kept on the grid. The new card is
    /// last in `cards`.
    public func adding(kind: String, size: CellSize, centredOn cell: Cell) throws(LayoutRefusal)
        -> SceneLayout
    {
        guard let cells = placement(of: size, centredOn: cell) else { throw .largerThanGrid }
        guard !cards.contains(where: { $0.cells.intersects(cells) }) else { throw .spaceTaken }
        return SceneLayout(checked: grid, cards: cards + [LayoutCard(kind: kind, cells: cells)])
    }

    /// The cards `ids` reach, whole groups included, shifted together by `offset`, which stops
    /// at the grid's edge. Refused if any lands on a card that is not moving.
    public func moving(_ ids: Set<UUID>, by offset: CellOffset) throws(LayoutRefusal) -> SceneLayout
    {
        let moving = widened(ids)
        let shift = clampedOffset(moving, by: offset)
        var moved = cards
        for index in moved.indices where moving.contains(moved[index].id) {
            moved[index].cells = moved[index].cells.offset(by: shift)
        }
        let staying = moved.filter { !moving.contains($0.id) }.map(\.cells)
        for card in moved where moving.contains(card.id) {
            if staying.contains(where: card.cells.intersects) { throw .spaceTaken }
        }
        return SceneLayout(checked: grid, cards: moved)
    }

    /// Where a card of `size` centred on `cell` would go, kept on the grid, or nil when it is
    /// larger than the grid. Whether its cells are free is not checked.
    public func placement(of size: CellSize, centredOn cell: Cell) -> CellRect? {
        guard size.cols <= grid.cols, size.rows <= grid.rows else { return nil }
        return CellRect(
            col: (cell.col - size.cols / 2).clamped(to: 0...(grid.cols - size.cols)),
            row: (cell.row - size.rows / 2).clamped(to: 0...(grid.rows - size.rows)),
            cols: size.cols, rows: size.rows)
    }

    /// `offset` cut short so every card `ids` reaches, whole groups included, stays on the grid.
    /// Whether the cells it reaches are free is not checked.
    public func clampedOffset(_ ids: Set<UUID>, by offset: CellOffset) -> CellOffset {
        let moving = widened(ids)
        guard let block = CellRect(enclosing: cards.filter { moving.contains($0.id) }.map(\.cells))
        else { return .zero }
        return CellOffset(
            cols: offset.cols.clamped(to: -block.col...(grid.cols - block.maxCol)),
            rows: offset.rows.clamped(to: -block.row...(grid.rows - block.maxRow)))
    }

    /// The card `id` with `edges` dragged by `offset`: the horizontal edge first, then the
    /// vertical, each stopping at the grid, at any card in its path, and at one cell.
    public func resizing(_ id: UUID, edges: CardEdges, by offset: CellOffset) throws(LayoutRefusal)
        -> SceneLayout
    {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return self }
        guard cards[index].group == nil else { throw .cardIsGrouped }
        let others = cards.filter { $0.id != id }.map(\.cells)
        let across = cards[index].cells.resizedAcross(
            edges: edges, by: offset.cols, within: grid.cols, avoiding: others)
        // The vertical edge is the horizontal one with rows and columns swapped.
        let down = across.transposed.resizedAcross(
            edges: edges.transposed, by: offset.rows, within: grid.rows,
            avoiding: others.map(\.transposed))
        var resized = cards
        resized[index].cells = down.transposed
        return SceneLayout(checked: grid, cards: resized)
    }

    /// The cards `ids` reach made one new group, named `group-N`, replacing any group they were
    /// in. Refused unless they are two or more, not already one group, and tile a rectangle with
    /// no other card inside it.
    public func grouping(_ ids: Set<UUID>) throws(LayoutRefusal) -> SceneLayout {
        let chosen = widened(ids)
        let members = cards.filter { chosen.contains($0.id) }
        guard members.count > 1 else { throw .tooFewCards }
        let replaced = Set(members.compactMap(\.group))
        if replaced.count == 1, members.allSatisfy({ $0.group != nil }) { throw .alreadyAGroup }
        if let refusal = Self.tilingRefusal(members, among: cards) { throw refusal }
        let name = newGroupName(replacing: replaced)
        var grouped = cards
        for index in grouped.indices where chosen.contains(grouped[index].id) {
            grouped[index].group = name
        }
        return SceneLayout(checked: grid, cards: grouped)
    }

    /// Every group the cards `ids` reach dissolved, each card left where it is.
    public func ungrouping(_ ids: Set<UUID>) -> SceneLayout {
        let chosen = widened(ids)
        var ungrouped = cards
        for index in ungrouped.indices where chosen.contains(ungrouped[index].id) {
            ungrouped[index].group = nil
        }
        return SceneLayout(checked: grid, cards: ungrouped)
    }

    /// The cards `ids` reach removed, whole groups included.
    public func removing(_ ids: Set<UUID>) -> SceneLayout {
        let chosen = widened(ids)
        return SceneLayout(checked: grid, cards: cards.filter { !chosen.contains($0.id) })
    }

    /// The lowest `group-N` no remaining group uses.
    private func newGroupName(replacing replaced: Set<String>) -> String {
        let taken = Set(cards.compactMap(\.group)).subtracting(replaced)
        var number = 1
        while taken.contains("group-\(number)") { number += 1 }
        return "group-\(number)"
    }
}

extension CellRect {
    /// The block with rows and columns swapped, so one routine serves both axes.
    var transposed: CellRect {
        CellRect(col: row, row: col, cols: rows, rows: cols)
    }

    /// The block with its left or right edge, as `edges` says, moved by `delta` columns, stopping
    /// at the grid's `width`, at any of `others` on its rows, and at one column.
    func resizedAcross(
        edges: CardEdges, by delta: Int, within width: Int, avoiding others: [CellRect]
    )
        -> CellRect
    {
        var cells = self
        let inPath = others.filter { $0.sharesRows(with: self) }
        if edges.contains(.right) {
            let wall = inPath.filter { $0.col >= maxCol }.map(\.col).min() ?? width
            cells.cols = (maxCol + delta).clamped(to: (col + 1)...wall) - col
        }
        if edges.contains(.left) {
            let wall = inPath.filter { $0.maxCol <= col }.map(\.maxCol).max() ?? 0
            cells.col = (col + delta).clamped(to: wall...(maxCol - 1))
            cells.cols = maxCol - cells.col
        }
        return cells
    }
}

extension Int {
    fileprivate func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
