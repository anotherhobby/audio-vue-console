import Foundation
import Testing

@testable import ConsoleCore

/// `scene-rendering`, "An edit draws again only what it changed".
struct PlateChangesTests {
    private let meter = card("meter", rect(0, 0, 8, 8))
    private let waveform = card("waveform", rect(8, 0, 8, 8))
    private let logo = card("logo", rect(30, 0, 8, 8))

    private func base() throws -> SceneLayout {
        try layout([meter, waveform, logo])
    }

    @Test func aMoveDrawsTheMovedPlate() throws {
        let old = try base()
        let new = try old.moving([logo.id], by: CellOffset(cols: 2, rows: 0))
        let changes = PlateChanges.between(old, new)
        #expect(changes.redraw == [[logo.id]])
        #expect(changes.removed.isEmpty)
    }

    @Test func aResizeDrawsThatPlate() throws {
        let old = try base()
        let new = try old.resizing(logo.id, edges: .right, by: CellOffset(cols: 3, rows: 0))
        #expect(PlateChanges.between(old, new).redraw == [[logo.id]])
    }

    @Test func groupingReplacesTwoPlatesWithOne() throws {
        let old = try base()
        let new = try old.grouping([meter.id, waveform.id])
        let changes = PlateChanges.between(old, new)
        #expect(changes.redraw == [[meter.id, waveform.id]])
        #expect(changes.removed == [[meter.id], [waveform.id]])
    }

    @Test func ungroupingReplacesOnePlateWithTwo() throws {
        let old = try base().grouping([meter.id, waveform.id])
        let new = old.ungrouping([meter.id])
        let changes = PlateChanges.between(old, new)
        #expect(changes.redraw == [[meter.id], [waveform.id]])
        #expect(changes.removed == [[meter.id, waveform.id]])
    }

    @Test func aDeleteDrawsNothing() throws {
        let old = try base()
        let changes = PlateChanges.between(old, old.removing([logo.id]))
        #expect(changes.redraw.isEmpty)
        #expect(changes.removed == [[logo.id]])
    }

    @Test func anAddDrawsTheNewPlate() throws {
        let old = try base()
        let new = try old.adding(
            kind: "readout", size: CellSize(cols: 6, rows: 4), centredOn: Cell(col: 50, row: 20))
        let added = try #require(new.cards.last)
        #expect(PlateChanges.between(old, new).redraw == [[added.id]])
    }

    @Test func anUndoDrawsThePlateBack() throws {
        let old = try base()
        let new = try old.moving([logo.id], by: CellOffset(cols: 2, rows: 0))
        #expect(PlateChanges.between(new, old).redraw == [[logo.id]])
    }

    @Test func movingAGroupDrawsItsOnePlate() throws {
        let old = try base().grouping([meter.id, waveform.id])
        let new = try old.moving([meter.id], by: CellOffset(cols: 0, rows: 4))
        #expect(PlateChanges.between(old, new).redraw == [[meter.id, waveform.id]])
    }
}
