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
    /// A card of `kind` and `size`, holding `settings`, added centred on `cell`, kept on the
    /// grid. The new card is last in `cards`.
    public func adding(
        kind: String, size: CellSize, centredOn cell: Cell, settings: [String: JSONValue] = [:]
    ) throws(LayoutRefusal) -> SceneLayout {
        let cells = CellRect(col: 0, row: 0, cols: size.cols, rows: size.rows)
        return try adding(LayoutCard(kind: kind, cells: cells, settings: settings), centredOn: cell)
    }

    /// `card`, new, centred on `cell` at the size its cells give, kept on the grid, keeping its id
    /// and settings.
    func adding(_ card: LayoutCard, centredOn cell: Cell) throws(LayoutRefusal) -> SceneLayout {
        let size = CellSize(cols: card.cells.cols, rows: card.cells.rows)
        guard let cells = placement(of: size, centredOn: cell) else { throw .largerThanGrid }
        guard !cards.contains(where: { $0.cells.intersects(cells) }) else { throw .spaceTaken }
        var placed = card
        placed.cells = cells
        return SceneLayout(checked: grid, cards: cards + [placed])
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

    /// The card `id` with `edges` dragged by `offset`, each edge stopping at the grid and at any
    /// card in its path, and kept to `floor`, the least rows at each width, as
    /// `CellRect.resized` keeps it (`scene-layout`, `card-minimum`).
    public func resizing(
        _ id: UUID, edges: CardEdges, by offset: CellOffset, floor: MinimumFloor = .oneCell
    ) throws(LayoutRefusal) -> SceneLayout {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return self }
        guard cards[index].group == nil else { throw .cardIsGrouped }
        let others = cards.filter { $0.id != id }.map(\.cells)
        var resized = cards
        resized[index].cells = cards[index].cells.resized(
            edges: edges, by: offset,
            within: CellRect(col: 0, row: 0, cols: grid.cols, rows: grid.rows),
            avoiding: others, floor: floor)
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

    /// The cards `ids`, and no others of their groups, setting `key` to `value`. Settings touch no
    /// cells, so this is never refused (`card-settings`, design D4).
    public func setting(_ key: String, to value: JSONValue, on ids: Set<UUID>) -> SceneLayout {
        changingSettings(of: ids) { $0[key] = value }
    }

    /// The cards `ids` leaving `key` unset, so each takes its own default.
    public func unsetting(_ key: String, on ids: Set<UUID>) -> SceneLayout {
        changingSettings(of: ids) { $0[key] = nil }
    }

    /// The cards `ids` each taking `transform` of their own value of `key`, a nil result leaving it
    /// unset, so each card's entry changes by its own value (`meter-scales-editor`, design D3).
    public func changingSetting(
        _ key: String, on ids: Set<UUID>, _ transform: (JSONValue?) -> JSONValue?
    ) -> SceneLayout {
        changingSettings(of: ids) { settings in
            let next = transform(settings[key])
            settings[key] = next
        }
    }

    private func changingSettings(
        of ids: Set<UUID>, _ change: (inout [String: JSONValue]) -> Void
    ) -> SceneLayout {
        var changed = cards
        for index in changed.indices where ids.contains(changed[index].id) {
            change(&changed[index].settings)
        }
        return SceneLayout(checked: grid, cards: changed)
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

    /// The block with `edges` dragged by `offset`, each edge stopping at `bounds` and at any of
    /// `others` in its path, kept to `floor` (`card-minimum`, design D4): it is narrowed only to
    /// widths whose floor it can reach, its height dragged to or its own, widening back towards its own width
    /// where the dragged one does not, and lowered only to the floor at the width it reaches. It
    /// may widen freely. No edge grows that was not dragged, and one already below its floor is
    /// not made smaller.
    func resized(
        edges: CardEdges, by offset: CellOffset, within bounds: CellRect,
        avoiding others: [CellRect],
        floor: MinimumFloor
    ) -> CellRect {
        let cols = bounds.col...bounds.maxCol
        let rows = bounds.row...bounds.maxRow
        var across = resizedAcross(
            edges: edges, by: offset.cols, within: cols, avoiding: others, atLeast: 1)
        // The vertical edge is the horizontal one with rows and columns swapped.
        let lowered = { (block: CellRect, least: Int) in
            block.transposed.resizedAcross(
                edges: edges.transposed, by: offset.rows, within: rows,
                avoiding: others.map(\.transposed), atLeast: least
            ).transposed
        }
        // The tallest it may end: where it was dragged to, or its own height where that is more,
        // so a corner dragged in may stop at the floor but no edge grows past where it was.
        let ceiling = max(lowered(across, 1).rows, self.rows)
        var width = across.cols
        while width < self.cols, (floor.rows(at: width).map { $0 > ceiling }) ?? true {
            width += 1
        }
        if edges.contains(.left) { across.col = across.maxCol - width }
        across.cols = width
        return lowered(across, floor.rows(at: width) ?? self.rows)
    }

    /// The block with its left or right edge, as `edges` says, moved by `delta` columns, stopping
    /// at the columns `bounds` holds, at any of `others` on its rows, and at `minimum` columns, or
    /// at its own width where that is less, so a block never grows narrower than it is by being
    /// resized.
    func resizedAcross(
        edges: CardEdges, by delta: Int, within bounds: ClosedRange<Int>,
        avoiding others: [CellRect], atLeast minimum: Int
    ) -> CellRect {
        var cells = self
        let narrowest = Swift.max(1, Swift.min(minimum, cols))
        let inPath = others.filter { $0.sharesRows(with: self) }
        if edges.contains(.right) {
            let wall = inPath.filter { $0.col >= maxCol }.map(\.col).min() ?? bounds.upperBound
            cells.cols = (maxCol + delta).clamped(to: (col + narrowest)...wall) - col
        }
        if edges.contains(.left) {
            let wall = inPath.filter { $0.maxCol <= col }.map(\.maxCol).max() ?? bounds.lowerBound
            cells.col = (col + delta).clamped(to: wall...(maxCol - narrowest))
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
