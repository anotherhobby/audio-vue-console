import CoreGraphics

/// Points in a scene's region, converted to and from its cells, so the canvas does no cell
/// arithmetic of its own. `origin` is the grid's top-left corner in the points used: zero in the
/// region itself, the region's place in the canvas pane for the pane's parked cards
/// (`card-parking`).
public struct GridGeometry: Sendable, Equatable {
    public let grid: CellSize
    /// The scene region's size in points.
    public let size: CGSize
    public let origin: CGPoint

    public init(grid: CellSize, size: CGSize, origin: CGPoint = .zero) {
        self.grid = grid
        self.size = size
        self.origin = origin
    }

    public var cellWidth: CGFloat { size.width / CGFloat(grid.cols) }
    public var cellHeight: CGFloat { size.height / CGFloat(grid.rows) }

    /// The cell under `point`, or the nearest cell on the grid for a point off it. A point on a
    /// boundary belongs to the cell to its right or below.
    public func cell(at point: CGPoint) -> Cell {
        let free = cellReached(by: point)
        return Cell(
            col: min(max(free.col, 0), grid.cols - 1), row: min(max(free.row, 0), grid.rows - 1))
    }

    /// The cell under `point`, on the grid or off it: where a library drop over the pane lands
    /// (`card-parking`, "A library card dropped off the panel is parked").
    public func cellOnOrOff(at point: CGPoint) -> Cell {
        cellReached(by: point)
    }

    /// The region `cells` covers, in points, on the grid or off it.
    public func rect(of cells: CellRect) -> CGRect {
        CGRect(
            x: origin.x + CGFloat(cells.col) * cellWidth,
            y: origin.y + CGFloat(cells.row) * cellHeight,
            width: CGFloat(cells.cols) * cellWidth, height: CGFloat(cells.rows) * cellHeight)
    }

    /// A drag's `translation`, rounded to the nearest whole cells.
    public func offset(for translation: CGSize) -> CellOffset {
        CellOffset(
            cols: Int((translation.width / cellWidth).rounded()),
            rows: Int((translation.height / cellHeight).rounded()))
    }

    /// Every cell `rect` touches, kept to the grid: what a marquee over the region reaches.
    public func cells(touching rect: CGRect) -> CellRect {
        let first = cell(at: rect.origin)
        let last = cell(at: CGPoint(x: rect.maxX, y: rect.maxY))
        return CellRect(
            col: first.col, row: first.row, cols: last.col - first.col + 1,
            rows: last.row - first.row + 1)
    }

    /// Every cell `rect` touches, on the grid or off it: what a marquee over the pane reaches.
    public func cellsOnAndOff(touching rect: CGRect) -> CellRect {
        let first = cellReached(by: rect.origin)
        let last = cellReached(by: CGPoint(x: rect.maxX, y: rect.maxY))
        return CellRect(
            col: first.col, row: first.row, cols: last.col - first.col + 1,
            rows: last.row - first.row + 1)
    }

    /// The whole cells, from the grid's top-left, that lie within a pane of `paneSize` whose
    /// top-left is the zero point: where a parked card may go. It always holds the grid.
    public func reach(in paneSize: CGSize) -> CellRect {
        let left = Int((origin.x / cellWidth).rounded(.down))
        let top = Int((origin.y / cellHeight).rounded(.down))
        let right = Int(((paneSize.width - origin.x - size.width) / cellWidth).rounded(.down))
        let bottom = Int(((paneSize.height - origin.y - size.height) / cellHeight).rounded(.down))
        let (cols, rows) = (max(left, 0), max(top, 0))
        return CellRect(
            col: -cols, row: -rows, cols: cols + grid.cols + max(right, 0),
            rows: rows + grid.rows + max(bottom, 0))
    }

    /// Where the grid's lines fall across a pane of `paneSize` whose top-left is the zero point: the
    /// x of each column line and the y of each row line within it, through the grid's corners at its
    /// cell pitch and continued past them, as the pane's grid around the panel is drawn
    /// (`scene-canvas`, "The pane around the panel is a grid of the panel's cells").
    public func lines(in paneSize: CGSize) -> (columns: [CGFloat], rows: [CGFloat]) {
        guard cellWidth > 0, cellHeight > 0 else { return ([], []) }
        return (
            Self.lines(from: origin.x, pitch: cellWidth, within: paneSize.width),
            Self.lines(from: origin.y, pitch: cellHeight, within: paneSize.height)
        )
    }

    /// Every `start + k × pitch`, for whole `k`, from zero to `extent`.
    private static func lines(from start: CGFloat, pitch: CGFloat, within extent: CGFloat)
        -> [CGFloat]
    {
        let first = Int((-start / pitch).rounded(.up))
        let last = Int(((extent - start) / pitch).rounded(.down))
        guard first <= last else { return [] }
        return (first...last).map { start + CGFloat($0) * pitch }
    }

    /// The largest factor this geometry may be scaled by, about the grid's centre, with `block`
    /// still lying within a pane of `paneSize` whose top-left is the zero point: infinite where
    /// there is no block (design D6). The canvas draws the panel at the least of 1 and this.
    public func fittingScale(of block: CellRect?, in paneSize: CGSize) -> CGFloat {
        guard let block else { return .infinity }
        let rect = rect(of: block)
        let centre = CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        return min(
            Self.factor(centre.x, rect.minX, rect.maxX, paneSize.width),
            Self.factor(centre.y, rect.minY, rect.maxY, paneSize.height))
    }

    /// The largest factor about `centre` keeping `low` to `high` within zero to `extent`, on one
    /// axis.
    private static func factor(
        _ centre: CGFloat, _ low: CGFloat, _ high: CGFloat, _ extent: CGFloat
    ) -> CGFloat {
        var factor = CGFloat.infinity
        if low < centre { factor = min(factor, centre / (centre - low)) }
        if high > centre { factor = min(factor, (extent - centre) / (high - centre)) }
        return max(factor, 0)
    }

    /// The cell under `point`, on the grid or off it.
    private func cellReached(by point: CGPoint) -> Cell {
        Cell(
            col: Int(((point.x - origin.x) / cellWidth).rounded(.down)),
            row: Int(((point.y - origin.y) / cellHeight).rounded(.down)))
    }
}
