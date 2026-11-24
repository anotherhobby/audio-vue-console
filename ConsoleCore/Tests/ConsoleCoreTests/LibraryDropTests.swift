import CoreGraphics
import Foundation
import Testing

@testable import ConsoleCore

/// `card-parking`, "A library card dropped off the panel is parked", and the drop over the panel
/// beside it (design D10). The grid is 64 × 36 in `testPane`, which reaches 20 rows below it.
struct LibraryDropTests {
    /// A new 10 × 4 card, as a library drop carries it: its cells give only its size.
    private static func card(settings: [String: JSONValue] = [:]) -> LayoutCard {
        LayoutCard(
            kind: "meter", cells: CellRect(col: 0, row: 0, cols: 10, rows: 4), settings: settings)
    }

    private static func empty() throws -> SceneContent {
        SceneContent(layout: try layout([]))
    }

    /// "Dropped below the panel".
    @Test func aDropBelowThePanelIsParkedThere() throws {
        let card = Self.card()
        let dropped = try Self.empty().dropping(card, at: Cell(col: 20, row: 45), within: testPane)
        #expect(dropped.layout.cards.isEmpty)
        #expect(dropped.parked.map(\.cells) == [rect(15, 43, 10, 4)])
        #expect(dropped.parked.first?.id == card.id)
    }

    /// "Dropped across the edge": pushed down by the least that clears the grid.
    @Test func aDropAcrossTheEdgeIsPushedOff() throws {
        let dropped = try Self.empty().dropping(
            Self.card(), at: Cell(col: 20, row: 36), within: testPane)
        #expect(dropped.parked.map(\.cells) == [rect(15, 36, 10, 4)])
    }

    /// "Dropped onto a parked card".
    @Test func aDropOntoAParkedCardIsRefused() throws {
        let once = try Self.empty().dropping(
            Self.card(), at: Cell(col: 20, row: 45), within: testPane)
        #expect(throws: LayoutRefusal.spaceTaken) {
            try once.dropping(Self.card(), at: Cell(col: 22, row: 45), within: testPane)
        }
    }

    /// "No room beyond the edge": three rows below the panel.
    @Test func aDropWithNoRoomBeyondTheEdgeIsRefused() throws {
        let shallow = rect(-30, -20, 124, 59)
        #expect(throws: LayoutRefusal.noRoomOffPanel) {
            try Self.empty().dropping(Self.card(), at: Cell(col: 20, row: 37), within: shallow)
        }
    }

    /// "A set-up card": its settings and size go with it.
    @Test func aSetUpCardIsParkedWithItsSetup() throws {
        let setUp = LayoutCard(
            kind: "meter", cells: CellRect(col: 0, row: 0, cols: 12, rows: 8),
            settings: ["style": .string("bar")])
        let dropped = try Self.empty().dropping(setUp, at: Cell(col: 20, row: 48), within: testPane)
        let parked = try #require(dropped.parked.first)
        #expect(parked.settings == ["style": .string("bar")])
        #expect(parked.cells.cols == 12 && parked.cells.rows == 8)
    }

    /// "A drop over the panel lands on it": "Near the edge".
    @Test func aDropOverThePanelStaysOnTheGrid() throws {
        let dropped = try Self.empty().dropping(
            Self.card(), at: Cell(col: 20, row: 35), within: testPane)
        #expect(dropped.parked.isEmpty)
        #expect(dropped.layout.cards.map(\.cells) == [rect(15, 32, 10, 4)])
    }

    @Test func theCellUnderAPointerOffTheGrid() {
        let geometry = GridGeometry(
            grid: CellSize(cols: 96, rows: 36), size: CGSize(width: 960, height: 360))
        #expect(geometry.cellOnOrOff(at: CGPoint(x: -15, y: 365)) == Cell(col: -2, row: 36))
        #expect(geometry.cell(at: CGPoint(x: -15, y: 365)) == Cell(col: 0, row: 35))
    }
}
