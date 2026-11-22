import Foundation
import Testing

@testable import ConsoleCore

/// `scene-rendering`, "A tile's size is the first size on a ladder": the sizes a tile is tried at and the
/// binary search that finds the smallest that fits.
@MainActor
struct TileLadderTests {
    private let meter = SchemaFacts.Card(
        name: "meter", minimum: CellSize(cols: 8, rows: 6), placeable: true)

    // MARK: The ladder (`scene-rendering`, "A tile's size is the first size on a ladder")

    @Test func theLadderGrowsFromTheMinimumByWholeCells() {
        #expect(LibraryTiles.Ladder.size(meter, step: 0) == CellSize(cols: 8, rows: 6))
        #expect(LibraryTiles.Ladder.size(meter, step: 3) == CellSize(cols: 11, rows: 9))
    }

    /// `scene-rendering`, "An aspect-locked card keeps its shape on the ladder": two columns for each row.
    @Test func anAspectLockedCardGrowsInItsAspect() {
        let round = SchemaFacts.Card(
            name: "round", minimum: CellSize(cols: 8, rows: 8), placeable: true, aspect: 2)
        #expect(LibraryTiles.Ladder.size(round, step: 4) == CellSize(cols: 12, rows: 10))
    }

    @Test func theTopStepIsWhereTheCardLeavesTheGrid() {
        let grid = CellSize(cols: 64, rows: 36)
        #expect(LibraryTiles.Ladder.top(meter, grid: grid) == 30)
        let wide = SchemaFacts.Card(
            name: "wide", minimum: CellSize(cols: 80, rows: 6), placeable: true)
        #expect(LibraryTiles.Ladder.top(wide, grid: grid) == nil)
    }

    @Test func theSearchFindsTheSmallestFittingStepInFewProbes() async {
        var probes: [Int] = []
        let result = await LibraryTiles.Ladder.smallestFitting(
            top: 30,
            probe: { step in
                probes.append(step)
                return step
            }, fits: { $0 >= 7 })
        guard case .found(let step, let plate) = result else {
            Issue.record("No step was found")
            return
        }
        #expect(step == 7 && plate == 7)
        #expect(probes.count <= 6)
    }

    @Test func aCardFittingAtNoStepHasNoFoundSize() async {
        let result = await LibraryTiles.Ladder.smallestFitting(
            top: 30, probe: { step in step }, fits: { _ in false })
        guard case .none = result else {
            Issue.record("A step was found where none fits")
            return
        }
    }

    @Test func aRefusedProbeEndsTheSearch() async {
        let result = await LibraryTiles.Ladder.smallestFitting(
            top: 30, probe: { step in step == 15 ? nil : step }, fits: { _ in true })
        guard case .failed = result else {
            Issue.record("The search went on past a refused probe")
            return
        }
    }
}
