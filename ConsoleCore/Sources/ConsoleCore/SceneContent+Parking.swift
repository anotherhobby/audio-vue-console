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

    /// `card`, new, dropped from the library centred on `cell`: added on the grid, kept within
    /// it, where `cell` is on the grid, and parked where it is off (`card-parking`, "A library card
    /// dropped off the panel is parked"). `card`'s cells give only its size.
    public func dropping(_ card: LayoutCard, at cell: Cell, within reach: CellRect)
        throws(LayoutRefusal) -> SceneContent
    {
        guard layout.bounds.contains(CellRect(col: cell.col, row: cell.row, cols: 1, rows: 1))
        else { return try droppingOff(card, centredOn: cell, within: reach) }
        return with(layout: try layout.adding(card, centredOn: cell))
    }

    /// `card` parked centred on `cell`, kept to `reach`, and pushed wholly off the grid across the
    /// edge it crosses by the least that clears it, as a dragged block is. Refused on a parked card,
    /// or where the pane has no room beyond the edge.
    private func droppingOff(_ card: LayoutCard, centredOn cell: Cell, within reach: CellRect)
        throws(LayoutRefusal) -> SceneContent
    {
        let size = card.cells
        let centred = CellRect(
            col: cell.col - size.cols / 2, row: cell.row - size.rows / 2, cols: size.cols,
            rows: size.rows)
        let kept = centred.kept(within: reach)
        if layout.bounds.contains(kept) { throw .noRoomOffPanel }
        let cells = kept.intersects(layout.bounds) ? try pushedOff(kept, within: reach) : kept
        if parked.contains(where: { $0.cells.intersects(cells) }) { throw .spaceTaken }
        var dropped = self
        var placed = card
        placed.cells = cells
        dropped.parked.append(placed)
        return dropped
    }

    /// The card `id` with `edges` dragged by `offset`, kept to `floor` (`card-minimum`): on the
    /// grid as `SceneLayout.resizing` resizes it, parked within `reach`, the pane in cells
    /// (`card-parking`, design D11).
    public func resizing(
        _ id: UUID, edges: CardEdges, by offset: CellOffset, floor: MinimumFloor,
        within reach: CellRect
    ) throws(LayoutRefusal) -> SceneContent {
        guard layout.card(id) == nil else {
            return with(layout: try layout.resizing(id, edges: edges, by: offset, floor: floor))
        }
        return try resizingParked(id, edges: edges, by: offset, floor: floor, within: reach)
    }

    /// The cards `ids` reach made one new group, on the grid as `SceneLayout.grouping` groups
    /// them, or parked by the same rules. Refused for cards on both sides of the panel's edge,
    /// since a group is wholly on the panel or wholly off it (`card-parking`, design D11).
    public func grouping(_ ids: Set<UUID>) throws(LayoutRefusal) -> SceneContent {
        let chosen = widened(ids)
        let onGrid = layout.cards.contains { chosen.contains($0.id) }
        let off = parked.contains { chosen.contains($0.id) }
        if onGrid && off { throw .acrossPanelEdge }
        return off ? try groupingParked(chosen) : with(layout: try layout.grouping(chosen))
    }

    /// The parked cards `chosen` made one new group: refused unless they are two or more, not
    /// already one group, and tile a rectangle with no other parked card inside it.
    private func groupingParked(_ chosen: Set<UUID>) throws(LayoutRefusal) -> SceneContent {
        let members = parked.filter { chosen.contains($0.id) }
        guard members.count > 1 else { throw .tooFewCards }
        let replaced = Set(members.compactMap(\.group))
        if replaced.count == 1, members.allSatisfy({ $0.group != nil }) { throw .alreadyAGroup }
        if let refusal = SceneLayout.tilingRefusal(members, among: parked) { throw refusal }
        let name = Self.groupName(notIn: Set(cards.compactMap(\.group)).subtracting(replaced))
        var grouped = self
        for index in grouped.parked.indices where chosen.contains(grouped.parked[index].id) {
            grouped.parked[index].group = name
        }
        return grouped
    }

    /// The parked card `id` with `edges` dragged by `offset`, as `SceneLayout.resizing` resizes a
    /// card on the grid, each edge stopping at `reach`, the pane in cells, at any other parked card
    /// in its path, at the grid, so a resize never takes it onto the panel, and at `floor`
    /// (`card-parking`, "A parked card resizes within the pane").
    private func resizingParked(
        _ id: UUID, edges: CardEdges, by offset: CellOffset, floor: MinimumFloor,
        within reach: CellRect
    ) throws(LayoutRefusal) -> SceneContent {
        guard let index = parked.firstIndex(where: { $0.id == id }) else { return self }
        guard parked[index].group == nil else { throw .cardIsGrouped }
        let cells = parked[index].cells
        let others = parked.filter { $0.id != id }.map(\.cells) + [layout.bounds]
        // The pane widened to the card, so a pane that shrank past it never empties a range.
        guard let pane = CellRect(enclosing: [reach, cells]) else { return self }
        var resized = self
        resized.parked[index].cells = cells.resized(
            edges: edges, by: offset, within: pane, avoiding: others, floor: floor)
        return resized
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
        removed.entries = entries.filter { !chosen.contains($0.key) }
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
