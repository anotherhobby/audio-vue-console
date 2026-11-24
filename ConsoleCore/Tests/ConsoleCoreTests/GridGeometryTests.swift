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

    // MARK: The pane (`card-parking`)

    /// The same grid placed at (100, 50) in a pane.
    private let placed = GridGeometry(
        grid: CellSize(cols: 96, rows: 36), size: CGSize(width: 960, height: 360),
        origin: CGPoint(x: 100, y: 50))

    @Test func cellsOffTheGridMapLeftOfAndAboveTheOrigin() {
        let rect = placed.rect(of: CellRect(col: -2, row: -1, cols: 2, rows: 1))
        #expect(rect == CGRect(x: 80, y: 40, width: 20, height: 10))
        let touched = placed.cellsOnAndOff(touching: CGRect(x: 81, y: 41, width: 5, height: 5))
        #expect(touched == CellRect(col: -2, row: -1, cols: 1, rows: 1))
    }

    @Test func theReachOfAPaneLargerThanThePanel() {
        let reach = placed.reach(in: CGSize(width: 1200, height: 500))
        #expect(reach == CellRect(col: -10, row: -5, cols: 120, rows: 50))
    }

    @Test func theReachAlwaysHoldsTheGrid() {
        let reach = placed.reach(in: CGSize(width: 500, height: 200))
        #expect(reach.contains(CellRect(col: 0, row: 0, cols: 96, rows: 36)))
    }

    /// `card-parking`, "Every parked card stays in view": "Nothing parked".
    @Test func nothingParkedKeepsThePanelsSize() {
        let scale = placed.fittingScale(of: nil, in: CGSize(width: 1200, height: 500))
        #expect(min(1, scale) == 1)
    }

    /// `card-parking`, "Every parked card stays in view": "Narrowing the window".
    @Test func aParkedBlockPastThePaneShrinksThePanel() {
        let block = CellRect(col: 0, row: 36, cols: 10, rows: 4)
        let scale = placed.fittingScale(of: block, in: CGSize(width: 1200, height: 430))
        #expect(abs(scale - 200.0 / 220.0) < 0.0001)
        #expect(placed.fittingScale(of: block, in: CGSize(width: 1200, height: 500)) > 1)
    }

    /// `scene-canvas`, "The pane around the panel is a grid of the panel's cells": the lines pass
    /// through the region's corners and repeat at its cell pitch across the whole pane.
    @Test func thePanesLinesMeetTheGridsCorners() {
        let region = GridGeometry(
            grid: CellSize(cols: 96, rows: 36), size: CGSize(width: 960, height: 360),
            origin: CGPoint(x: 25, y: 15))
        let (columns, rows) = region.lines(in: CGSize(width: 1000, height: 400))
        #expect(columns.first == 5 && columns.last == 995 && columns.count == 100)
        #expect(rows.first == 5 && rows.last == 395 && rows.count == 40)
        #expect(columns.contains(25) && columns.contains(985))
        #expect(rows.contains(15) && rows.contains(375))
        #expect(zip(columns, columns.dropFirst()).allSatisfy { $1 - $0 == 10 })
    }

    @Test func aGridWithNoSizeHasNoLines() {
        let (columns, rows) = GridGeometry(grid: CellSize(cols: 96, rows: 36), size: .zero)
            .lines(in: CGSize(width: 1000, height: 400))
        #expect(columns.isEmpty && rows.isEmpty)
    }
}
