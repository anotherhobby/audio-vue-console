import Foundation

/// The moves that park cards off the panel and bring them back (`card-parking`, design D2 and D3).
/// `reach` is the canvas pane in cells from the grid's top-left, as the canvas shows it; it always
/// holds the grid.
extension SceneContent {
    /// The cards `ids` reach, whole groups included, dragged together by `offset` as one block.
    /// A block landing wholly on the grid joins the layout. One that would leave the grid is kept
    /// to `reach`, pushed across the edge it crosses by the least that clears the grid, and parked.
    public func dragging(_ ids: Set<UUID>, by offset: CellOffset, within reach: CellRect)
        throws(LayoutRefusal) -> SceneContent
    {
        let moving = widened(ids)
        guard let block = CellRect(enclosing: cards.filter { moving.contains($0.id) }.map(\.cells))
        else { return self }
        let shifted = block.offset(by: offset)
        if layout.bounds.contains(shifted) { return try placing(moving, by: offset) }
        let kept = shifted.kept(within: reach)
        // Kept to the pane, a block back on the grid had nowhere off it to go.
        if layout.bounds.contains(kept) { throw .noRoomOffPanel }
        let parked = kept.intersects(layout.bounds) ? try pushedOff(kept, within: reach) : kept
        return try parking(
            moving, by: CellOffset(cols: parked.col - block.col, rows: parked.row - block.row))
    }

    /// The cards `ids` reach nudged by `offset`: those on the grid stop at its edge, as
    /// `SceneLayout.moving` keeps them, and parked ones move by the same step, which is refused
    /// where one would reach the grid or leave `reach`. An arrow key never parks a card.
    public func nudging(_ ids: Set<UUID>, by offset: CellOffset, within reach: CellRect)
        throws(LayoutRefusal) -> SceneContent
    {
        let moving = widened(ids)
        let onGrid = moving.intersection(layout.cards.map(\.id))
        let step = onGrid.isEmpty ? offset : layout.clampedOffset(onGrid, by: offset)
        var nudged = with(layout: try layout.moving(onGrid, by: step))
        nudged.parked = try parked(moving, shiftedBy: step) { cells throws(LayoutRefusal) in
            if cells.intersects(layout.bounds) || !reach.contains(cells) { throw .dragToCross }
        }
        return nudged
    }

    // MARK: Edits to every card

    /// The cards `ids`, and no others of their groups, setting `key` to `value`.
    public func setting(_ key: String, to value: JSONValue, on ids: Set<UUID>) -> SceneContent {
        changingParked(ids, layout.setting(key, to: value, on: ids)) { $0.settings[key] = value }
    }

    /// The cards `ids` leaving `key` unset.
    public func unsetting(_ key: String, on ids: Set<UUID>) -> SceneContent {
        changingParked(ids, layout.unsetting(key, on: ids)) { $0.settings[key] = nil }
    }

    /// The cards `ids` each taking `transform` of their own value of `key`.
    public func changingSetting(
        _ key: String, on ids: Set<UUID>, _ transform: (JSONValue?) -> JSONValue?
    ) -> SceneContent {
        changingParked(ids, layout.changingSetting(key, on: ids, transform)) { card in
            let next = transform(card.settings[key])
            card.settings[key] = next
        }
    }

    /// Every group the cards `ids` reach dissolved, on the grid or parked.
    public func ungrouping(_ ids: Set<UUID>) -> SceneContent {
        let chosen = widened(ids)
        return changingParked(chosen, layout.ungrouping(chosen)) { $0.group = nil }
    }

    /// The cards `ids` reach removed, whole groups included, on the grid or parked.
    public func removing(_ ids: Set<UUID>) -> SceneContent {
        let chosen = widened(ids)
        var removed = with(layout: layout.removing(chosen))
        removed.parked = parked.filter { !chosen.contains($0.id) }
        return removed
    }

    // MARK: Parts

    /// The cards `moving` shifted by `offset`, all onto the grid: refused where one lands on a
    /// card that stays.
    private func placing(_ moving: Set<UUID>, by offset: CellOffset) throws(LayoutRefusal)
        -> SceneContent
    {
        let placed =
            layout.cards.map { moving.contains($0.id) ? $0.shifted(by: offset) : $0 }
            + parked.filter { moving.contains($0.id) }.map { $0.shifted(by: offset) }
        var moved = with(layout: try SceneLayout(grid: layout.grid, cards: placed))
        moved.parked = parked.filter { !moving.contains($0.id) }
        return moved
    }

    /// The cards `moving` shifted by `offset`, all off the grid: refused where one lands on a
    /// parked card that stays.
    private func parking(_ moving: Set<UUID>, by offset: CellOffset) throws(LayoutRefusal)
        -> SceneContent
    {
        let arriving = layout.cards.filter { moving.contains($0.id) }.map { $0.shifted(by: offset) }
        var moved = with(layout: layout.removing(moving))
        moved.parked = try parked(moving, shiftedBy: offset) { _ throws(LayoutRefusal) in }
        moved.parked += arriving
        if arriving.contains(where: { card in
            moved.parked.contains { $0.id != card.id && $0.cells.intersects(card.cells) }
        }) {
            throw .spaceTaken
        }
        return moved
    }

    /// The parked cards, those in `moving` shifted by `offset` after `check` passes each one's new
    /// cells: refused where a moved card lands on a parked card that stays.
    private func parked(
        _ moving: Set<UUID>, shiftedBy offset: CellOffset,
        check: (CellRect) throws(LayoutRefusal) -> Void
    ) throws(LayoutRefusal) -> [LayoutCard] {
        let staying = parked.filter { !moving.contains($0.id) }.map(\.cells)
        var shifted = parked
        for index in shifted.indices where moving.contains(shifted[index].id) {
            let cells = shifted[index].cells.offset(by: offset)
            try check(cells)
            if staying.contains(where: cells.intersects) { throw .spaceTaken }
            shifted[index].cells = cells
        }
        return shifted
    }

    /// `block`, which crosses the grid's edge, pushed wholly off it: across each edge it crosses by
    /// the least that clears the grid, least push first and rows before columns on a tie, taking
    /// the first that stays within `reach`.
    private func pushedOff(_ block: CellRect, within reach: CellRect) throws(LayoutRefusal)
        -> CellRect
    {
        let grid = layout.bounds
        var pushes: [CellOffset] = []
        if block.row < grid.row {
            pushes.append(CellOffset(cols: 0, rows: grid.row - block.maxRow))
        }
        if block.maxRow > grid.maxRow {
            pushes.append(CellOffset(cols: 0, rows: grid.maxRow - block.row))
        }
        if block.col < grid.col {
            pushes.append(CellOffset(cols: grid.col - block.maxCol, rows: 0))
        }
        if block.maxCol > grid.maxCol {
            pushes.append(CellOffset(cols: grid.maxCol - block.col, rows: 0))
        }
        // Rows come first in `pushes`, and the index breaks a tie, so rows win it.
        let ordered = pushes.enumerated().sorted { first, second in
            (first.element.length, first.offset) < (second.element.length, second.offset)
        }
        guard let fits = ordered.map({ block.offset(by: $0.element) }).first(where: reach.contains)
        else { throw .noRoomOffPanel }
        return fits
    }

    /// The parked cards, those in `ids` changed by `change`, beside `layout`.
    private func changingParked(
        _ ids: Set<UUID>, _ layout: SceneLayout, _ change: (inout LayoutCard) -> Void
    ) -> SceneContent {
        var changed = with(layout: layout)
        for index in changed.parked.indices where ids.contains(changed.parked[index].id) {
            change(&changed.parked[index])
        }
        return changed
    }
}

extension LayoutCard {
    fileprivate func shifted(by offset: CellOffset) -> LayoutCard {
        var card = self
        card.cells = cells.offset(by: offset)
        return card
    }
}

extension CellOffset {
    /// How far the offset moves, in cells along whichever axis it takes.
    fileprivate var length: Int { abs(cols) + abs(rows) }
}

extension CellRect {
    /// The block moved by the least that brings it within `bounds`, or to its top-left where it is
    /// larger than `bounds`.
    fileprivate func kept(within bounds: CellRect) -> CellRect {
        CellRect(
            col: Swift.max(bounds.col, Swift.min(col, bounds.maxCol - cols)),
            row: Swift.max(bounds.row, Swift.min(row, bounds.maxRow - rows)),
            cols: cols, rows: rows)
    }
}
