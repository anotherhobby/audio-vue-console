import CoreGraphics

/// Points in a scene's region, converted to and from its cells, so the canvas does no cell
/// arithmetic of its own. The region's origin is the grid's top-left corner.
public struct GridGeometry: Sendable, Equatable {
    public let grid: CellSize
    /// The scene region's size in points.
    public let size: CGSize

    public init(grid: CellSize, size: CGSize) {
        self.grid = grid
        self.size = size
    }

    public var cellWidth: CGFloat { size.width / CGFloat(grid.cols) }
    public var cellHeight: CGFloat { size.height / CGFloat(grid.rows) }

    /// The cell under `point`, or the nearest cell on the grid for a point off it. A point on a
    /// boundary belongs to the cell to its right or below.
    public func cell(at point: CGPoint) -> Cell {
        Cell(
            col: Self.index(point.x / cellWidth, count: grid.cols),
            row: Self.index(point.y / cellHeight, count: grid.rows))
    }

    /// The region `cells` covers, in points.
    public func rect(of cells: CellRect) -> CGRect {
        CGRect(
            x: CGFloat(cells.col) * cellWidth, y: CGFloat(cells.row) * cellHeight,
            width: CGFloat(cells.cols) * cellWidth, height: CGFloat(cells.rows) * cellHeight)
    }

    /// A drag's `translation`, rounded to the nearest whole cells.
    public func offset(for translation: CGSize) -> CellOffset {
        CellOffset(
            cols: Int((translation.width / cellWidth).rounded()),
            rows: Int((translation.height / cellHeight).rounded()))
    }

    /// Every cell `rect` touches, kept to the grid: what a marquee over `rect` reaches.
    public func cells(touching rect: CGRect) -> CellRect {
        let first = cell(at: rect.origin)
        let last = cell(at: CGPoint(x: rect.maxX, y: rect.maxY))
        return CellRect(
            col: first.col, row: first.row, cols: last.col - first.col + 1,
            rows: last.row - first.row + 1)
    }

    private static func index(_ position: CGFloat, count: Int) -> Int {
        min(max(Int(position.rounded(.down)), 0), count - 1)
    }
}
