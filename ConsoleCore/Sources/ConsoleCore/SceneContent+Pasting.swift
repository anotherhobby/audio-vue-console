import Foundation

/// Where a paste lands (`card-clipboard`, design D3): on the panel in the free cells nearest the
/// copied ones, else parked off it, above first, then below, left and right, else nowhere.
extension SceneContent {
    /// `pasting`'s cards added as one block keeping their arrangement, each source group made a
    /// new group: on the panel's first `panelCols` columns where they fit, else parked within
    /// `reach`, the pane in cells. Refused where a card is not among `placeable`, or there is no
    /// room on the panel or off it.
    public func pasting(
        _ pasting: CopiedCards.Pasting, within reach: CellRect, panelCols: Int,
        placeable: Set<String>
    ) throws(LayoutRefusal) -> SceneContent {
        if let kind = pasting.cards.first(where: { !placeable.contains($0.kind) })?.kind {
            throw .notPlaceable(kind)
        }
        let cards = regrouped(pasting.cards)
        guard let block = CellRect(enclosing: cards.map(\.cells)) else { return self }
        var pasted = self
        pasted.entries.merge(pasting.entries) { _, copied in copied }
        if let offset = onPanel(cards, block, panelCols: panelCols) {
            pasted.layout = try SceneLayout(
                grid: layout.grid, cards: layout.cards + cards.map { $0.shifted(by: offset) })
            return pasted
        }
        guard let offset = offPanel(cards, block, within: reach) else { throw .noRoomToPaste }
        pasted.parked += cards.map { $0.shifted(by: offset) }
        return pasted
    }

    /// The offset nearest none that puts every card on the panel's first `panelCols` columns,
    /// covering no card on the grid, or nil where there is none.
    private func onPanel(_ cards: [LayoutCard], _ block: CellRect, panelCols: Int) -> CellOffset? {
        let cols = min(panelCols, layout.grid.cols)
        guard let across = Self.range(0, cols - block.cols),
            let down = Self.range(0, layout.grid.rows - block.rows)
        else { return nil }
        return Self.nearest(
            cards, from: block, cols: across, rows: down, avoiding: layout.cards.map(\.cells))
    }

    /// The offset nearest none that puts the block wholly off the grid within `reach`, covering no
    /// parked card: above the grid where any does, else below, else left, else right.
    private func offPanel(_ cards: [LayoutCard], _ block: CellRect, within reach: CellRect)
        -> CellOffset?
    {
        let grid = layout.bounds
        let across = Self.range(reach.col, reach.maxCol - block.cols)
        let down = Self.range(reach.row, reach.maxRow - block.rows)
        let sides: [(cols: ClosedRange<Int>?, rows: ClosedRange<Int>?)] = [
            (across, Self.range(reach.row, grid.row - block.rows)),
            (across, Self.range(grid.maxRow, reach.maxRow - block.rows)),
            (Self.range(reach.col, grid.col - block.cols), down),
            (Self.range(grid.maxCol, reach.maxCol - block.cols), down),
        ]
        let taken = parked.map(\.cells)
        return sides.lazy.compactMap { side in
            guard let cols = side.cols, let rows = side.rows else { return nil }
            return Self.nearest(cards, from: block, cols: cols, rows: rows, avoiding: taken)
        }.first
    }

    /// Of the offsets that move `block`'s top-left to a column in `cols` and a row in `rows`, the
    /// nearest none, the top-most then left-most on a tie, at which no card covers any of `taken`.
    private static func nearest(
        _ cards: [LayoutCard], from block: CellRect, cols: ClosedRange<Int>,
        rows: ClosedRange<Int>, avoiding taken: [CellRect]
    ) -> CellOffset? {
        var best: (distance: Int, offset: CellOffset)?
        for row in rows {
            for col in cols {
                let offset = CellOffset(cols: col - block.col, rows: row - block.row)
                let distance = offset.cols * offset.cols + offset.rows * offset.rows
                if let best, best.distance <= distance { continue }
                let free = cards.allSatisfy { card in
                    let cells = card.cells.offset(by: offset)
                    return !taken.contains(where: cells.intersects)
                }
                if free { best = (distance, offset) }
            }
        }
        return best?.offset
    }

    /// `low...high`, or nil where `high` is below `low`.
    private static func range(_ low: Int, _ high: Int) -> ClosedRange<Int>? {
        low <= high ? low...high : nil
    }

    /// `cards` with each source group renamed to the lowest `group-N` no card of the scene uses,
    /// on the grid or parked, in the order the groups first appear.
    private func regrouped(_ cards: [LayoutCard]) -> [LayoutCard] {
        var taken = Set(self.cards.compactMap(\.group))
        var renamed: [String: String] = [:]
        return cards.map { card in
            guard let group = card.group else { return card }
            if renamed[group] == nil {
                let name = Self.groupName(notIn: taken)
                renamed[group] = name
                taken.insert(name)
            }
            var regrouped = card
            regrouped.group = renamed[group]
            return regrouped
        }
    }
}

extension LayoutCard {
    fileprivate func shifted(by offset: CellOffset) -> LayoutCard {
        var card = self
        card.cells = cells.offset(by: offset)
        return card
    }
}
