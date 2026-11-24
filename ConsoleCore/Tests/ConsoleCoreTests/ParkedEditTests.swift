import Foundation
import Testing

@testable import ConsoleCore

/// `card-parking`: a parked card resized and grouped as a card on the panel is, kept off the panel
/// (design D11). The grid is 64 × 36 in `testPane`, which reaches row 56.
@MainActor struct ParkedEditTests {
    private static func content(parked: [LayoutCard], onGrid: [LayoutCard] = []) throws
        -> SceneContent
    {
        SceneContent(layout: try layout(onGrid), parked: parked)
    }

    private static func resized(
        _ content: SceneContent, _ card: LayoutCard, _ edges: CardEdges, by offset: CellOffset,
        minimum: CellSize = .oneCell
    ) throws -> CellRect? {
        try content.resizing(
            card.id, edges: edges, by: offset, minimum: minimum, within: testPane
        ).card(card.id)?.cells
    }

    // MARK: Resizing

    /// "Growing a parked card".
    @Test func aParkedCardGrows() throws {
        let card = card("meter", rect(10, 40, 10, 4))
        let content = try Self.content(parked: [card])
        let cells = try Self.resized(content, card, .right, by: CellOffset(cols: 3, rows: 0))
        #expect(cells == rect(10, 40, 13, 4))
    }

    /// "Stopping at the panel's edge".
    @Test func aResizeStopsAtThePanel() throws {
        let card = card("meter", rect(10, 36, 10, 4))
        let content = try Self.content(parked: [card])
        let cells = try Self.resized(content, card, .top, by: CellOffset(cols: 0, rows: -2))
        #expect(cells == rect(10, 36, 10, 4))
    }

    /// "Stopping at another parked card".
    @Test func aResizeStopsAtAParkedCard() throws {
        let card = card("meter", rect(0, 40, 10, 4))
        let other = ConsoleCoreTests.card("readout", rect(14, 40, 6, 4))
        let content = try Self.content(parked: [card, other])
        let cells = try Self.resized(content, card, .right, by: CellOffset(cols: 10, rows: 0))
        #expect(cells?.maxCol == 14)
    }

    /// "Stopping at the pane's edge".
    @Test func aResizeStopsAtThePane() throws {
        let card = card("meter", rect(0, 50, 10, 4))
        let content = try Self.content(parked: [card])
        let cells = try Self.resized(content, card, .bottom, by: CellOffset(cols: 0, rows: 10))
        #expect(cells?.maxRow == testPane.maxRow)
    }

    /// "The declared minimum".
    @Test func aResizeStopsAtTheMinimum() throws {
        let card = card("meter", rect(0, 40, 10, 8))
        let content = try Self.content(parked: [card])
        let cells = try Self.resized(
            content, card, [.right, .bottom], by: CellOffset(cols: -5, rows: -5),
            minimum: CellSize(cols: 8, rows: 6))
        #expect(cells == rect(0, 40, 8, 6))
    }

    @Test func aGroupedParkedCardIsNotResized() throws {
        let card = card("meter", rect(0, 40, 4, 4), group: "g")
        let other = ConsoleCoreTests.card("readout", rect(4, 40, 4, 4), group: "g")
        let content = try Self.content(parked: [card, other])
        #expect(throws: LayoutRefusal.cardIsGrouped) {
            try Self.resized(content, card, .right, by: CellOffset(cols: 1, rows: 0))
        }
    }

    // MARK: Grouping

    /// "Grouping parked cards", named past the grid's groups.
    @Test func parkedCardsThatTileAreGrouped() throws {
        let (left, right) = (card("a", rect(0, 40, 4, 4)), card("b", rect(4, 40, 4, 4)))
        let onGrid = [
            card("c", rect(0, 0, 4, 4), group: "group-1"),
            card("d", rect(4, 0, 4, 4), group: "group-1"),
        ]
        let content = try Self.content(parked: [left, right], onGrid: onGrid)
        let grouped = try content.grouping([left.id, right.id])
        #expect(grouped.parked.map(\.group) == ["group-2", "group-2"])
        #expect(grouped.layout == content.layout)
    }

    @Test func parkedCardsWithAHoleAreRefused() throws {
        let (left, right) = (card("a", rect(0, 40, 4, 4)), card("b", rect(8, 40, 4, 4)))
        let content = try Self.content(parked: [left, right])
        #expect(throws: LayoutRefusal.notARectangle) {
            try content.grouping([left.id, right.id])
        }
    }

    /// "Grouping with a parked card".
    @Test func aGroupAcrossThePanelsEdgeIsRefused() throws {
        let (onGrid, parked) = (card("a", rect(0, 32, 4, 4)), card("b", rect(0, 36, 4, 4)))
        let content = try Self.content(parked: [parked], onGrid: [onGrid])
        #expect(throws: LayoutRefusal.acrossPanelEdge) {
            try content.grouping([onGrid.id, parked.id])
        }
    }

    // MARK: Through the editor

    @Test func aParkedResizeIsOneStepNamedResize() throws {
        let manager = UndoManager()
        manager.groupsByEvent = false
        let card = card("meter", rect(10, 40, 10, 4))
        let editor = SceneEditor(content: try Self.content(parked: [card]), undoManager: manager)
        editor.select(card.id)
        #expect(editor.resizableCard?.id == card.id)
        editor.resize(card.id, edges: .right, by: CellOffset(cols: 2, rows: 0), within: testPane)
        #expect(editor.content.card(card.id)?.cells.cols == 12)
        #expect(manager.undoActionName == "Resize")
        #expect(
            editor.previewResize(
                card.id, edges: .right, by: CellOffset(cols: 1, rows: 0), within: testPane
            ).map { $0.card(card.id)?.cells.cols } == .success(13))
    }

    @Test func groupingParkedCardsThroughTheEditor() throws {
        let (left, right) = (card("a", rect(0, 40, 4, 4)), card("b", rect(4, 40, 4, 4)))
        let editor = SceneEditor(content: try Self.content(parked: [left, right]))
        editor.select(left.id)
        editor.toggle(right.id)
        #expect(editor.groupRefusal == nil)
        editor.group()
        #expect(editor.content.parked.allSatisfy { $0.group == "group-1" })
        #expect(editor.canUngroup && editor.resizableCard == nil)
    }
}
