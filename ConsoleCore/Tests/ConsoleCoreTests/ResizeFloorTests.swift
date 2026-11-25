import Foundation
import Testing

@testable import ConsoleCore

/// `scene-layout`, "A resize stops at a neighbour's edge", `card-minimum`, "The readable floor
/// depends on the width", and `card-parking`, "A parked card resizes within the pane": a resize
/// kept to the helper's readable floor (design D4).
@MainActor struct ResizeFloorTests {
    /// A waveform that reads at 8 rows from 20 columns, 9 at 19, and 10 at 17 and 18.
    private static let waveformFloor = MinimumFloor.answered([17: 10, 18: 10, 19: 9, 20: 8])

    private static func resized(
        _ cells: CellRect, _ edges: CardEdges, by offset: CellOffset, floor: MinimumFloor
    ) throws -> CellRect? {
        let waveform = card("waveform", cells)
        return try layout([waveform]).resizing(waveform.id, edges: edges, by: offset, floor: floor)
            .card(waveform.id)?.cells
    }

    /// "Narrowing stops where the height cannot read".
    @Test func narrowingStopsWhereTheHeightCannotRead() throws {
        let cells = try Self.resized(
            rect(0, 0, 20, 8), .right, by: CellOffset(cols: -3, rows: 0), floor: Self.waveformFloor)
        #expect(cells == rect(0, 0, 20, 8))
    }

    /// "Narrowing a taller card".
    @Test func aTallerCardNarrows() throws {
        let cells = try Self.resized(
            rect(0, 0, 20, 10), .right, by: CellOffset(cols: -3, rows: 0), floor: Self.waveformFloor
        )
        #expect(cells == rect(0, 0, 17, 10))
    }

    /// "Shrinking to the minimum", from the left, the card tall enough at every width.
    @Test func shrinkingStopsAtTheAnswersNarrowestWidth() throws {
        let cells = try Self.resized(
            rect(10, 0, 20, 12), .left, by: CellOffset(cols: 6, rows: 0), floor: Self.waveformFloor)
        #expect(cells == rect(13, 0, 17, 12))
    }

    /// "A card already below its minimum".
    @Test func aCardBelowItsFloorIsNotLowered() throws {
        let cells = try Self.resized(
            rect(0, 0, 17, 9), .bottom, by: CellOffset(cols: 0, rows: -2), floor: Self.waveformFloor
        )
        #expect(cells == rect(0, 0, 17, 9))
    }

    /// "Widening a card below its floor".
    @Test func aCardBelowItsFloorWidens() throws {
        let cells = try Self.resized(
            rect(0, 0, 10, 6), .right, by: CellOffset(cols: 3, rows: 0),
            floor: .answered([17: 10]))
        #expect(cells?.cols == 13)
    }

    /// A corner dragged far in stops at the smallest size the floor allows.
    @Test func aCornerDraggedInStopsAtTheFloor() throws {
        let cells = try Self.resized(
            rect(0, 0, 20, 12), [.right, .bottom], by: CellOffset(cols: -8, rows: -8),
            floor: Self.waveformFloor)
        #expect(cells == rect(0, 0, 17, 10))
    }

    /// `card-parking`, "The readable floor".
    @Test func aParkedCardStopsAtItsReadableFloor() throws {
        let meter = card("meter", rect(0, 40, 12, 10))
        let content = SceneContent(layout: try layout([]), parked: [meter])
        let resized = try content.resizing(
            meter.id, edges: .bottom, by: CellOffset(cols: 0, rows: -5),
            floor: .answered([12: 7]), within: testPane)
        #expect(resized.card(meter.id)?.cells == rect(0, 40, 12, 7))
    }

    // MARK: Through the editor

    /// A held answer's floor stops a resize where the declared minimum would not.
    @Test func theEditorUsesAHeldAnswer() throws {
        let waveform = card("waveform", rect(0, 0, 20, 12))
        let editor = SceneEditor(
            layout: try layout([waveform]), minimums: ["waveform": CellSize(cols: 12, rows: 6)])
        editor.heldMinimum = { _ in CardMinimum(whole: [:], readable: [17: 10, 20: 8]) }
        editor.resize(
            waveform.id, edges: [.right, .bottom], by: CellOffset(cols: -8, rows: -8),
            within: testPane)
        #expect(editor.layout.card(waveform.id)?.cells == rect(0, 0, 17, 10))
    }

    /// "Before the answer": with none held, the declared minimum stands in.
    @Test func theEditorFallsBackToTheDeclaredMinimum() throws {
        let waveform = card("waveform", rect(0, 0, 20, 12))
        let editor = SceneEditor(
            layout: try layout([waveform]), minimums: ["waveform": CellSize(cols: 12, rows: 6)])
        editor.resize(
            waveform.id, edges: [.right, .bottom], by: CellOffset(cols: -10, rows: -10),
            within: testPane)
        #expect(editor.layout.card(waveform.id)?.cells == rect(0, 0, 12, 6))
    }
}
