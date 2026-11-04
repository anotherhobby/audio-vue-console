import CoreGraphics
import Testing

@testable import ConsoleCore

/// Points and cells on a 96 × 36 grid drawn at 960 × 360 pt, so each cell is 10 pt square.
struct GridGeometryTests {
    private let geometry = GridGeometry(
        grid: CellSize(cols: 96, rows: 36), size: CGSize(width: 960, height: 360))

    @Test func cellSize() {
        #expect(geometry.cellWidth == 10)
        #expect(geometry.cellHeight == 10)
    }

    @Test(arguments: [
        (CGPoint(x: 0, y: 0), Cell(col: 0, row: 0)),
        (CGPoint(x: 9.9, y: 9.9), Cell(col: 0, row: 0)),
        (CGPoint(x: 10, y: 10), Cell(col: 1, row: 1)),
        (CGPoint(x: 955, y: 355), Cell(col: 95, row: 35)),
        (CGPoint(x: 960, y: 360), Cell(col: 95, row: 35)),
        (CGPoint(x: -40, y: 2000), Cell(col: 0, row: 35)),
    ])
    func theCellAtAPoint(point: CGPoint, cell: Cell) {
        #expect(geometry.cell(at: point) == cell)
    }

    @Test func theRectOfCells() {
        let rect = geometry.rect(of: CellRect(col: 2, row: 3, cols: 4, rows: 5))
        #expect(rect == CGRect(x: 20, y: 30, width: 40, height: 50))
    }

    @Test(arguments: [
        (CGSize(width: 14, height: -14), CellOffset(cols: 1, rows: -1)),
        (CGSize(width: 15, height: 26), CellOffset(cols: 2, rows: 3)),
        (CGSize(width: 4, height: -4), CellOffset.zero),
    ])
    func aDragRoundsToWholeCells(translation: CGSize, offset: CellOffset) {
        #expect(geometry.offset(for: translation) == offset)
    }

    @Test func aMarqueeTouchesEveryCellItCrosses() {
        let touched = geometry.cells(touching: CGRect(x: 5, y: 5, width: 20, height: 1))
        #expect(touched == CellRect(col: 0, row: 0, cols: 3, rows: 1))
    }

    @Test func aMarqueePastTheEdgeStopsThere() {
        let touched = geometry.cells(touching: CGRect(x: 900, y: 300, width: 500, height: 500))
        #expect(touched == CellRect(col: 90, row: 30, cols: 6, rows: 6))
    }
}
