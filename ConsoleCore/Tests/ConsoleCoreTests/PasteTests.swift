import Foundation
import Testing

@testable import ConsoleCore

/// `card-clipboard`: where a paste lands, on the panel or parked off it, and when it is refused
/// (design D3). Scenes are on a 64 × 36 panel.
struct PasteTests {
    private static let panel = CellSize(cols: 64, rows: 36)
    private static let placeable: Set<String> = ["meter", "readout", "waveform", "rta_bars"]
    /// The pane: ten rows above the panel and ten below, no columns either side.
    private static let pane = CellRect(col: 0, row: -10, cols: 64, rows: 56)

    private static func scene(_ cards: String) throws -> LaidOutScene {
        try LaidOutScene(
            SceneDocument(
                id: "s", name: "S", builtIn: false, fixed: false,
                doc: try JSONDecoder().decode(
                    JSONValue.self, from: Data(#"{"cards": [\#(cards)]}"#.utf8))),
            panel: panel)
    }

    /// A meter in columns 0–7, rows 0–5, grouped with a readout in columns 8–15, and a waveform
    /// in columns 30–39, rows 20–25.
    private static func source() throws -> LaidOutScene {
        try scene(
            #"{"card": "meter", "colspan": 8, "rowspan": 6, "group": "g", "#
                + #""params": {"floor_db": -60}},"#
                + #"{"card": "readout", "col": 8, "colspan": 8, "rowspan": 6, "group": "g"},"#
                + #"{"card": "waveform", "col": 30, "row": 20, "colspan": 10, "rowspan": 6}"#)
    }

    /// The source scene's card of `kind`, copied alone or with its group.
    private static func copied(_ kind: String) throws -> CopiedCards.Pasting {
        let source = try Self.source()
        let card = try #require(source.layout.cards.first { $0.kind == kind })
        let copied = try #require(CopiedCards([card.id], of: source.content, in: source))
        return try copied.cards(on: panel)
    }

    private static func paste(
        _ pasting: CopiedCards.Pasting, into content: SceneContent, within pane: CellRect = pane
    ) throws(LayoutRefusal) -> SceneContent {
        try content.pasting(pasting, within: pane, panelCols: 64, placeable: placeable)
    }

    /// "Pasting into another scene with the cells free".
    @Test func theCopiedCellsWhereTheyAreFree() throws {
        let pasting = try Self.copied("waveform")
        let empty = try Self.scene("").content
        let pasted = try Self.paste(pasting, into: empty)
        #expect(pasted.layout.cards.map(\.cells) == [CellRect(col: 30, row: 20, cols: 10, rows: 6)])
        #expect(pasted.layout.cards.first?.id == pasting.cards.first?.id)
    }

    /// "Pasting where it was copied": the nearest free cells, the source unchanged.
    @Test func theNearestFreeCellsBesideTheSource() throws {
        let source = try Self.source()
        let pasted = try Self.paste(try Self.copied("waveform"), into: source.content)
        #expect(pasted.layout.cards.prefix(3) == source.layout.cards[...])
        // Six rows up or down (36) is nearer than ten columns across (100); of the two, the
        // higher row is found first.
        #expect(pasted.layout.cards.last?.cells == CellRect(col: 30, row: 14, cols: 10, rows: 6))
    }

    /// "A group keeps its arrangement": side by side, as one new group.
    @Test func aGroupPastesAsANewGroup() throws {
        let source = try Self.source()
        let pasted = try Self.paste(try Self.copied("meter"), into: source.content)
        let copies = pasted.layout.cards.suffix(2)
        #expect(copies.map(\.group) == ["group-1", "group-1"])
        let (meter, readout) = (try #require(copies.first), try #require(copies.last))
        #expect(readout.cells.col == meter.cells.maxCol && readout.cells.row == meter.cells.row)
        #expect(meter.settings == ["floor_db": .integer(-60)])
    }

    /// The panel covered whole by one card.
    private static func full() throws -> SceneContent {
        try scene(#"{"card": "rta_bars"}"#).content
    }

    /// "A full panel": parked above it.
    @Test func aFullPanelParksThePasteAbove() throws {
        let pasted = try Self.paste(try Self.copied("waveform"), into: try Self.full())
        let parked = try #require(pasted.parked.first)
        #expect(parked.cells == CellRect(col: 30, row: -6, cols: 10, rows: 6))
        #expect(pasted.layout.cards.count == 1)
    }

    /// "No room above": parked below.
    @Test func tooFewRowsAboveParksThePasteBelow() throws {
        let pane = CellRect(col: 0, row: -3, cols: 64, rows: 49)
        let pasted = try Self.paste(
            try Self.copied("waveform"), into: try Self.full(), within: pane)
        #expect(pasted.parked.first?.cells == CellRect(col: 30, row: 36, cols: 10, rows: 6))
    }

    /// A parked card already above is not covered.
    @Test func aParkedCardIsNotCovered() throws {
        let pasting = try Self.copied("waveform")
        let once = try Self.paste(pasting, into: try Self.full())
        let twice = try Self.paste(try Self.copied("waveform"), into: once)
        let cells = twice.parked.map(\.cells)
        #expect(cells.count == 2 && !cells[0].intersects(cells[1]))
    }

    /// "Nowhere to go".
    @Test func noRoomAnywhereIsRefused() throws {
        let grid = CellRect(col: 0, row: 0, cols: 64, rows: 36)
        #expect(throws: LayoutRefusal.noRoomToPaste) {
            try Self.paste(try Self.copied("waveform"), into: try Self.full(), within: grid)
        }
    }

    /// "A card the panel no longer places".
    @Test func aCardThePanelDoesNotPlaceIsRefused() throws {
        let pasting = try Self.copied("waveform")
        #expect(throws: LayoutRefusal.notPlaceable("waveform")) {
            try (try Self.scene("")).content.pasting(
                pasting, within: Self.pane, panelCols: 64, placeable: ["meter"])
        }
    }

    /// A scene too wide: free cells past the panel's last column are not taken.
    @Test func thePanelsColumnsOnASceneTooWide() throws {
        let wide = try Self.scene(
            #"{"card": "rta_bars", "colspan": 64}, {"card": "meter", "col": 80, "colspan": 16, "#
                + #""rowspan": 8}"#
        ).content
        #expect(wide.layout.grid.cols == 96)
        let pane = CellRect(col: 0, row: -10, cols: 96, rows: 56)
        let pasted = try Self.paste(try Self.copied("waveform"), into: wide, within: pane)
        #expect(pasted.layout.cards.count == 2)
        #expect(pasted.parked.first?.cells.maxRow == 0)
    }

    /// Each paste's entries ride with the content, for the scene to write.
    @Test func thePastedEntriesAreKept() throws {
        let pasting = try Self.copied("meter")
        let pasted = try Self.paste(pasting, into: try Self.scene("").content)
        #expect(Set(pasted.entries.keys) == Set(pasting.cards.map(\.id)))
    }
}
