import Foundation
import Testing

@testable import ConsoleCore

/// A card of `kind` on `cells`, for building layouts in tests.
func card(_ kind: String, _ cells: CellRect, group: String? = nil) -> LayoutCard {
    LayoutCard(kind: kind, cells: cells, group: group)
}

/// The block at `col, row`, `cols` × `rows`.
func rect(_ col: Int, _ row: Int, _ cols: Int, _ rows: Int) -> CellRect {
    CellRect(col: col, row: row, cols: cols, rows: rows)
}

/// A 64 × 36 layout of `cards`, the default grid.
func layout(_ cards: [LayoutCard], cols: Int = 64, rows: Int = 36) throws -> SceneLayout {
    try SceneLayout(grid: CellSize(cols: cols, rows: rows), cards: cards)
}

/// `scene-layout`, "Every card lies on the scene's grid" and "Cards never overlap".
struct SceneLayoutTests {
    @Test func aCardAtTheGridsEdgeLiesOnIt() throws {
        let edge = card("meter", rect(56, 0, 8, 4))
        #expect(try layout([edge]).cards == [edge])
    }

    @Test func aCardRunningOffTheGridIsRefused() {
        #expect(throws: LayoutRefusal.offGrid) { try layout([card("meter", rect(57, 0, 8, 4))]) }
        #expect(throws: LayoutRefusal.offGrid) { try layout([card("meter", rect(0, 33, 8, 4))]) }
        #expect(throws: LayoutRefusal.offGrid) { try layout([card("meter", rect(-1, 0, 8, 4))]) }
    }

    @Test func twoCardsSideBySide() throws {
        #expect(
            try layout([card("a", rect(0, 0, 8, 4)), card("b", rect(8, 0, 8, 4))]).cards.count == 2)
    }

    @Test func overlappingCardsAreRefused() {
        #expect(throws: LayoutRefusal.spaceTaken) {
            try layout([card("a", rect(0, 0, 8, 4)), card("b", rect(7, 3, 8, 4))])
        }
    }

    @Test func aGroupThatDoesNotTileARectangleIsRefused() {
        let lShape = [
            card("a", rect(0, 0, 8, 8), group: "g"), card("b", rect(8, 0, 8, 8), group: "g"),
            card("c", rect(0, 8, 8, 8), group: "g"),
        ]
        #expect(throws: LayoutRefusal.notARectangle) { try layout(lShape) }
    }

    @Test func aStackOfFourIsAGroup() throws {
        let stack = [0, 9, 18, 27].map { card("meter", rect(0, $0, 16, 9), group: "meters") }
        #expect(try layout(stack).groups["meters"]?.count == 4)
    }

    @Test func widenedReachesWholeGroups() throws {
        let pair = [
            card("a", rect(0, 0, 8, 8), group: "pair"), card("b", rect(8, 0, 8, 8), group: "pair"),
        ]
        let loose = card("c", rect(20, 0, 4, 4))
        let scene = try layout(pair + [loose])
        #expect(scene.widened([pair[0].id]) == Set(pair.map(\.id)))
        #expect(scene.widened([loose.id]) == [loose.id])
    }

    @Test func cellRects() {
        let block = CellRect(col: 2, row: 3, cols: 4, rows: 5)
        #expect(block.maxCol == 6 && block.maxRow == 8 && block.area == 20)
        #expect(block.intersects(CellRect(col: 5, row: 7, cols: 1, rows: 1)))
        #expect(!block.intersects(CellRect(col: 6, row: 3, cols: 1, rows: 1)))
        #expect(block.contains(CellRect(col: 2, row: 3, cols: 4, rows: 5)))
        #expect(!block.contains(CellRect(col: 2, row: 3, cols: 5, rows: 5)))
        let enclosing = CellRect(enclosing: [block, CellRect(col: 0, row: 10, cols: 1, rows: 1)])
        #expect(enclosing == CellRect(col: 0, row: 3, cols: 6, rows: 8))
        #expect(CellRect(enclosing: []) == nil)
    }

    @Test func everyRefusalSaysSomething() {
        let refusals: [LayoutRefusal] = [
            .offGrid, .spaceTaken, .largerThanGrid, .cardIsGrouped, .tooFewCards, .alreadyAGroup,
            .notARectangle, .cardInTheWay, .readOnly(.builtIn),
            .readOnly(.shape(scene: "16:9", panel: "8:3")),
        ]
        #expect(Set(refusals.map(\.description)).count == refusals.count)
        #expect(
            LayoutRefusal.readOnly(.shape(scene: "16:9", panel: "8:3")).description.contains("8:3"))
    }
}

/// `scene-layout`, "A card is added only where its cells are free".
struct AddingTests {
    @Test func freeCells() throws {
        let added = try layout([]).adding(
            kind: "rta_bars", size: CellSize(cols: 19, rows: 18), centredOn: Cell(col: 20, row: 18))
        let new = try #require(added.cards.last)
        #expect(new.kind == "rta_bars")
        #expect(new.cells == CellRect(col: 11, row: 9, cols: 19, rows: 18))
    }

    @Test func nearTheEdgeTheCardIsKeptOnTheGrid() throws {
        let added = try layout([]).adding(
            kind: "meter", size: CellSize(cols: 8, rows: 4), centredOn: Cell(col: 63, row: 0))
        #expect(added.cards.last?.cells == CellRect(col: 56, row: 0, cols: 8, rows: 4))
    }

    @Test func aTakenCell() throws {
        let scene = try layout([card("a", rect(10, 10, 4, 4))])
        #expect(throws: LayoutRefusal.spaceTaken) {
            try scene.adding(
                kind: "b", size: CellSize(cols: 4, rows: 4), centredOn: Cell(col: 15, row: 15))
        }
    }

    @Test func tooLargeForTheGrid() throws {
        #expect(throws: LayoutRefusal.largerThanGrid) {
            try layout([]).adding(
                kind: "rta", size: CellSize(cols: 96, rows: 36), centredOn: Cell(col: 32, row: 18))
        }
    }
}

/// `scene-layout`, "A move keeps to the grid and refuses taken cells" and "A group moves and is
/// removed as one".
struct MovingTests {
    @Test func aMoveIntoFreeCells() throws {
        let meter = card("meter", rect(0, 0, 8, 4))
        let moved = try layout([meter]).moving([meter.id], by: CellOffset(cols: 4, rows: 0))
        #expect(moved.card(meter.id)?.cells == CellRect(col: 4, row: 0, cols: 8, rows: 4))
    }

    @Test func aMovePastTheEdgeStopsThere() throws {
        let meter = card("meter", rect(54, 0, 8, 4))
        let moved = try layout([meter]).moving([meter.id], by: CellOffset(cols: 5, rows: -3))
        #expect(moved.card(meter.id)?.cells == CellRect(col: 56, row: 0, cols: 8, rows: 4))
    }

    @Test func aMoveOntoAnotherCardIsRefused() throws {
        let meter = card("meter", rect(0, 0, 8, 4))
        let scene = try layout([meter, card("other", rect(10, 0, 4, 4))])
        #expect(throws: LayoutRefusal.spaceTaken) {
            try scene.moving([meter.id], by: CellOffset(cols: 3, rows: 0))
        }
    }

    @Test func twoCardsMovedTogether() throws {
        let left = card("a", rect(0, 0, 4, 4))
        let right = card("b", rect(4, 0, 4, 4))
        let moved = try layout([left, right]).moving(
            [left.id, right.id], by: CellOffset(cols: 1, rows: 0))
        #expect(moved.card(left.id)?.cells.col == 1)
        #expect(moved.card(right.id)?.cells.col == 5)
    }

    @Test func movingAMemberMovesTheGroup() throws {
        let group = [0, 4, 8].map { card("meter", rect($0, 0, 4, 4), group: "row") }
        let moved = try layout(group).moving([group[1].id], by: CellOffset(cols: 0, rows: 2))
        #expect(moved.cards.map(\.cells.row) == [2, 2, 2])
        #expect(moved.cards.map(\.cells.col) == [0, 4, 8])
    }
}

/// `scene-layout`, "A resize stops at a neighbour's edge" and "A grouped card is not resized on its
/// own".
struct ResizingTests {
    @Test func growingIntoFreeCells() throws {
        let meter = card("meter", rect(0, 0, 4, 4))
        let resized = try layout([meter]).resizing(
            meter.id, edges: .right, by: CellOffset(cols: 3, rows: 0))
        #expect(resized.card(meter.id)?.cells.cols == 7)
    }

    @Test func growingIntoANeighbourStopsAtItsEdge() throws {
        let meter = card("meter", rect(0, 0, 4, 4))
        let resized = try layout([meter, card("wall", rect(6, 2, 4, 4))]).resizing(
            meter.id, edges: .right, by: CellOffset(cols: 6, rows: 0))
        #expect(resized.card(meter.id)?.cells == CellRect(col: 0, row: 0, cols: 6, rows: 4))
    }

    @Test func aNeighbourOnOtherRowsIsNoWall() throws {
        let meter = card("meter", rect(0, 0, 4, 4))
        let resized = try layout([meter, card("below", rect(6, 4, 4, 4))]).resizing(
            meter.id, edges: .right, by: CellOffset(cols: 6, rows: 0))
        #expect(resized.card(meter.id)?.cells.cols == 10)
    }

    @Test func shrinkingToTheMinimum() throws {
        let meter = card("meter", rect(10, 0, 4, 4))
        let resized = try layout([meter]).resizing(
            meter.id, edges: .left, by: CellOffset(cols: 6, rows: 0))
        #expect(resized.card(meter.id)?.cells == CellRect(col: 13, row: 0, cols: 1, rows: 4))
    }

    @Test func shrinkingStopsAtTheDeclaredMinimum() throws {
        let waveform = card("waveform", rect(10, 0, 20, 12))
        let resized = try layout([waveform]).resizing(
            waveform.id, edges: .left, by: CellOffset(cols: 6, rows: 0),
            minimum: CellSize(cols: 17, rows: 10))
        #expect(resized.card(waveform.id)?.cells == CellRect(col: 13, row: 0, cols: 17, rows: 12))
    }

    @Test func aCardBelowItsMinimumIsMadeNoSmaller() throws {
        let waveform = card("waveform", rect(0, 0, 10, 12))
        let minimum = CellSize(cols: 17, rows: 10)
        let shrunk = try layout([waveform]).resizing(
            waveform.id, edges: .right, by: CellOffset(cols: -2, rows: 0), minimum: minimum)
        #expect(shrunk.card(waveform.id)?.cells.cols == 10)
        let grown = try layout([waveform]).resizing(
            waveform.id, edges: .right, by: CellOffset(cols: 3, rows: 0), minimum: minimum)
        #expect(grown.card(waveform.id)?.cells.cols == 13)
    }

    @MainActor @Test func theEditorStopsACardAtItsKindsMinimum() throws {
        let waveform = card("waveform", rect(0, 0, 20, 12))
        let editor = SceneEditor(
            layout: try layout([waveform]), minimums: ["waveform": CellSize(cols: 17, rows: 10)])
        editor.resize(waveform.id, edges: [.right, .bottom], by: CellOffset(cols: -8, rows: -8))
        #expect(
            editor.layout.card(waveform.id)?.cells == CellRect(col: 0, row: 0, cols: 17, rows: 10))
    }

    @Test func growingLeftAndUpStopsAtTheGrid() throws {
        let meter = card("meter", rect(2, 2, 4, 4))
        let resized = try layout([meter]).resizing(
            meter.id, edges: [.left, .top], by: CellOffset(cols: -5, rows: -5))
        #expect(resized.card(meter.id)?.cells == CellRect(col: 0, row: 0, cols: 6, rows: 6))
    }

    @Test func aCornerMeetingADiagonalNeighbourTakesTheWidthFirst() throws {
        // The neighbour sits below and to the right: growing across first is free, then the
        // card spans its columns and growing down stops at its top.
        let meter = card("meter", rect(0, 0, 4, 4))
        let resized = try layout([meter, card("diagonal", rect(6, 6, 4, 4))]).resizing(
            meter.id, edges: [.right, .bottom], by: CellOffset(cols: 4, rows: 4))
        #expect(resized.card(meter.id)?.cells == CellRect(col: 0, row: 0, cols: 8, rows: 6))
    }

    @Test func aGroupedCardIsNotResized() throws {
        let pair = [
            card("a", rect(0, 0, 4, 4), group: "pair"), card("b", rect(4, 0, 4, 4), group: "pair"),
        ]
        let scene = try layout(pair)
        #expect(throws: LayoutRefusal.cardIsGrouped) {
            try scene.resizing(pair[0].id, edges: .bottom, by: CellOffset(cols: 0, rows: 2))
        }
    }
}

/// The queries the canvas draws a refused drag from.
struct PlacementTests {
    @Test func aPlacementIsCentredAndKeptOnTheGrid() throws {
        let scene = try layout([card("a", rect(0, 0, 4, 4))])
        let size = CellSize(cols: 8, rows: 4)
        #expect(scene.placement(of: size, centredOn: Cell(col: 2, row: 1)) == rect(0, 0, 8, 4))
        #expect(
            scene.placement(of: CellSize(cols: 65, rows: 1), centredOn: Cell(col: 0, row: 0)) == nil
        )
    }

    @Test func anOffsetIsCutShortAtTheEdge() throws {
        let meter = card("meter", rect(54, 2, 8, 4))
        let scene = try layout([meter])
        let clamped = scene.clampedOffset([meter.id], by: CellOffset(cols: 5, rows: -3))
        #expect(clamped == CellOffset(cols: 2, rows: -2))
    }
}
