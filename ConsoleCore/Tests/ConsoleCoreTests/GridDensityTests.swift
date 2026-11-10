import Foundation
import Testing

@testable import ConsoleCore

/// `scene-settings`, "The grid's density changes columns and rows together" and "A density that
/// would shrink a card below its minimum is refused" (design D5).
struct GridDensityTests {
    @Test func a16By9GridOffersElevenChoices() {
        let choices = GridDensity.choices(for: CellSize(cols: 64, rows: 36))
        #expect(choices.map(\.rows) == Array(stride(from: 18, through: 108, by: 9)))
        #expect(choices.allSatisfy { $0.cols * 9 == $0.rows * 16 })
        #expect(choices.count == 11)
    }

    @Test func an8By3GridOffersThirtyOneChoices() {
        let choices = GridDensity.choices(for: CellSize(cols: 96, rows: 36))
        #expect(choices.count == 31)
        #expect(choices.map(\.rows) == Array(stride(from: 18, through: 108, by: 3)))
        #expect(choices.contains(CellSize(cols: 48, rows: 18)))
        #expect(choices.contains(CellSize(cols: 144, rows: 54)))
    }

    @Test func aGridOutsideTheRangeIsStillAChoice() {
        let odd = CellSize(cols: 16, rows: 9)
        #expect(GridDensity.choices(for: odd).first == odd)
    }

    @Test func aCardMovesToTheCellsCoveringTheSamePart() throws {
        let wide = card("rta_bars", rect(16, 0, 32, 36))
        let finer = try GridDensity.relaid(
            try layout([wide]), to: CellSize(cols: 96, rows: 54), minimums: [:])
        #expect(finer.card(wide.id)?.cells == rect(24, 0, 48, 54))
        #expect(finer.grid == CellSize(cols: 96, rows: 54))
    }

    @Test func groupedCardsStillTileThereAndBack() throws {
        let left = card("meter", rect(0, 0, 10, 12), group: "g")
        let right = card("meter", rect(10, 0, 11, 12), group: "g")
        let start = try layout([left, right])
        let finer = try GridDensity.relaid(start, to: CellSize(cols: 96, rows: 54), minimums: [:])
        #expect(finer.card(left.id)?.cells.maxCol == finer.card(right.id)?.cells.col)
        #expect(SceneLayout.tilingRefusal(finer.cards, among: finer.cards) == nil)
        let back = try GridDensity.relaid(finer, to: CellSize(cols: 64, rows: 36), minimums: [:])
        #expect(back == start)
    }

    @Test func aCardAtItsMinimumRefusesACoarserGrid() throws {
        let waveform = card("waveform", rect(2, 0, 17, 10))
        let coarser = CellSize(cols: 48, rows: 27)
        let minimum = SchemaFacts.scaled(CellSize(cols: 17, rows: 10), toRows: coarser.rows)
        #expect(throws: LayoutRefusal.tooSmall("waveform")) {
            try GridDensity.relaid(
                try layout([waveform]), to: coarser, minimums: ["waveform": minimum])
        }
    }

    @MainActor @Test func aDensityIsOneStepAndARefusalLeavesTheGrid() throws {
        let manager = UndoManager()
        manager.groupsByEvent = false
        let waveform = card("waveform", rect(2, 0, 17, 10))
        let editor = SceneEditor(
            layout: try layout([waveform]), minimums: ["waveform": CellSize(cols: 17, rows: 10)],
            undoManager: manager)
        editor.setDensity(CellSize(cols: 96, rows: 54))
        #expect(editor.layout.grid == CellSize(cols: 96, rows: 54))
        #expect(editor.minimums["waveform"] == CellSize(cols: 26, rows: 15))
        #expect(manager.undoActionName == "Change Density")
        manager.undo()
        #expect(editor.layout.grid == CellSize(cols: 64, rows: 36))
        editor.setDensity(CellSize(cols: 48, rows: 27))
        #expect(editor.layout.grid == CellSize(cols: 64, rows: 36))
        #expect(editor.refusal == .tooSmall("waveform"))
    }
}
