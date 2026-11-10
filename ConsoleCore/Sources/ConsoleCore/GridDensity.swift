/// A scene's grid made finer or coarser at its own aspect, every card moved to the cells covering
/// the same part of the scene (`scene-settings`, "The grid's density changes columns and rows
/// together"; design D5).
public enum GridDensity {
    /// The fewest and most rows a choice may have.
    public static let rows = 18...108

    /// The grids at `grid`'s aspect with whole columns and rows in `rows`, fewest rows first,
    /// `grid` itself among them even where its rows fall outside.
    public static func choices(for grid: CellSize) -> [CellSize] {
        let divisor = greatestCommonDivisor(grid.cols, grid.rows)
        let (wide, tall) = (grid.cols / divisor, grid.rows / divisor)
        let steps = (rows.lowerBound + tall - 1) / tall...(rows.upperBound / tall)
        var choices = steps.map { CellSize(cols: $0 * wide, rows: $0 * tall) }
        if !choices.contains(grid) {
            choices.append(grid)
            choices.sort { $0.rows < $1.rows }
        }
        return choices
    }

    /// `layout` on `grid`: each card's edges scaled from its grid and rounded half up, so an edge
    /// two cards share lands on one cell, no cards overlap that did not, and groups still tile.
    /// Refused naming the card where one would be smaller than its minimum in `minimums`, each
    /// already on `grid`'s rows, or would cover no cells.
    public static func relaid(
        _ layout: SceneLayout, to grid: CellSize, minimums: [String: CellSize]
    ) throws(LayoutRefusal) -> SceneLayout {
        let old = layout.grid
        var cards: [LayoutCard] = []
        for card in layout.cards {
            var moved = card
            moved.cells = scaled(card.cells, from: old, to: grid)
            let minimum = minimums[card.kind] ?? .oneCell
            if moved.cells.cols < max(minimum.cols, 1) || moved.cells.rows < max(minimum.rows, 1) {
                throw .tooSmall(card.kind)
            }
            cards.append(moved)
        }
        return try SceneLayout(grid: grid, cards: cards)
    }

    private static func scaled(_ cells: CellRect, from old: CellSize, to new: CellSize) -> CellRect
    {
        let left = scaled(cells.col, by: new.cols, over: old.cols)
        let top = scaled(cells.row, by: new.rows, over: old.rows)
        return CellRect(
            col: left, row: top, cols: scaled(cells.maxCol, by: new.cols, over: old.cols) - left,
            rows: scaled(cells.maxRow, by: new.rows, over: old.rows) - top)
    }

    /// `edge × new / old`, rounded half up.
    private static func scaled(_ edge: Int, by new: Int, over old: Int) -> Int {
        (2 * edge * new + old) / (2 * old)
    }

    private static func greatestCommonDivisor(_ first: Int, _ second: Int) -> Int {
        second == 0 ? max(first, 1) : greatestCommonDivisor(second, first % second)
    }
}
