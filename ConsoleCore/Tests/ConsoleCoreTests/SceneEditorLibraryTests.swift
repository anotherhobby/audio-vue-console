import Foundation
import Testing

@testable import ConsoleCore

/// `library-setup` through the editor: the library card selected, its setup, and what a drop takes
/// (design D5). A test has no run loop to close undo groups, so the manager has `groupsByEvent` off.
@MainActor struct SceneEditorLibraryTests {
    private let manager = UndoManager()
    private let loose = card("c", rect(20, 0, 4, 4))
    private let editor: SceneEditor
    private let size = CellSize(cols: 4, rows: 4)

    init() throws {
        manager.groupsByEvent = false
        editor = SceneEditor(layout: try layout([loose]), undoManager: manager)
    }

    /// "Clicking the meter's tile" and "Back to the canvas".
    @Test func aLibraryCardAndTheCanvasSelectionExcludeEachOther() {
        editor.select(loose.id)
        editor.chooseLibraryCard("meter")
        #expect(editor.libraryCard == "meter" && editor.selection.isEmpty)
        editor.select(loose.id)
        #expect(editor.libraryCard == nil && editor.selection == [loose.id])
        editor.chooseLibraryCard("meter")
        editor.clearSelection()
        #expect(editor.libraryCard == nil)
    }

    /// "Dropping two set-up meters" and "Changing the setup afterwards".
    @Test func aDropTakesTheSetupAsItStands() throws {
        editor.setSetup("style", to: .string("bar"), on: "meter")
        editor.drop(kind: "meter", size: size, at: Cell(col: 2, row: 2), within: testPane)
        let first = try #require(editor.layout.cards.last)
        #expect(first.settings == ["style": .string("bar")])
        #expect(manager.undoActionName == "Add Card")
        editor.setSetup("style", to: .string("needle"), on: "meter")
        #expect(editor.layout.card(first.id)?.settings == ["style": .string("bar")])
        editor.drop(kind: "meter", size: size, at: Cell(col: 40, row: 20), within: testPane)
        #expect(editor.layout.cards.last?.settings == ["style": .string("needle")])
    }

    @Test func aCardWithNoSetupDropsWithNoSettings() throws {
        editor.drop(kind: "meter", size: size, at: Cell(col: 2, row: 2), within: testPane)
        #expect(editor.layout.cards.last?.settings == [:])
    }

    /// `card-parking`, "Dropped below the panel" and "A set-up card", through the editor.
    @Test func aDropOffTheGridParksTheCardWithItsSetup() throws {
        editor.select(loose.id)
        editor.setSetup("style", to: .string("bar"), on: "meter")
        editor.drop(kind: "meter", size: size, at: Cell(col: 20, row: 45), within: testPane)
        let parked = try #require(editor.content.parked.first)
        #expect(parked.settings == ["style": .string("bar")])
        #expect(parked.cells.row >= editor.layout.grid.rows)
        #expect(editor.selection == [parked.id])
        #expect(manager.undoActionName == "Add Card")
        manager.undo()
        #expect(!editor.hasParked)
    }

    /// `card-parking`, "Near the edge": a drop over the panel stays on its grid.
    @Test func aDropOverThePanelsEdgeStaysOnTheGrid() throws {
        editor.drop(kind: "meter", size: size, at: Cell(col: 2, row: 35), within: testPane)
        #expect(!editor.hasParked)
        #expect(editor.layout.cards.last?.cells.maxRow == editor.layout.grid.rows)
    }

    @Test func aReadOnlySceneRefusesADropOnOrOff() throws {
        let editor = SceneEditor(layout: try layout([loose]), readOnly: .builtIn)
        editor.drop(kind: "meter", size: size, at: Cell(col: 2, row: 2), within: testPane)
        editor.drop(kind: "meter", size: size, at: Cell(col: 20, row: 45), within: testPane)
        #expect(editor.layout.cards.count == 1 && !editor.hasParked)
        #expect(editor.refusal == .readOnly(.builtIn))
        #expect(
            editor.previewDrop(
                kind: "meter", size: size, at: Cell(col: 20, row: 45),
                within: testPane) == .failure(.readOnly(.builtIn)))
    }

    /// A setup is not a scene edit: no undo step, no change to the content, no commit.
    @Test func aSetupIsNotAnEdit() {
        var commits = 0
        let editor = SceneEditor(layout: self.editor.layout, undoManager: manager) { _ in
            commits += 1
        }
        let before = editor.content
        editor.chooseLibraryCard("meter")
        editor.setSetup("style", to: .string("bar"), on: "meter")
        editor.editSetup("floor_db", on: "meter") { _ in .integer(-60) }
        #expect(editor.content == before && !manager.canUndo && commits == 0)
    }

    /// "Back to the default" and "Marked and cleared".
    @Test func useDefaultAndClearEmptyTheSetup() {
        editor.setSetup("style", to: .string("bar"), on: "meter")
        editor.unsetSetup("style", on: "meter")
        #expect(editor.setups["meter"] == nil)
        editor.setSetup("style", to: .string("bar"), on: "meter")
        editor.setSetup("floor_db", to: .integer(-60), on: "meter")
        editor.clearSetup("meter")
        #expect(editor.setups.isEmpty)
    }

    /// "Looking at RTA": a read-only scene's library is set up, though nothing is dropped.
    @Test func aReadOnlySceneIsSetUp() throws {
        let editor = SceneEditor(layout: try layout([loose]), readOnly: .builtIn)
        editor.chooseLibraryCard("meter")
        editor.setSetup("style", to: .string("bar"), on: "meter")
        #expect(editor.libraryCard == "meter")
        #expect(editor.setups["meter"] == ["style": .string("bar")])
    }

    /// An undo that selects cards leaves no library card selected.
    @Test func anUndoThatSelectsClearsTheLibraryCard() {
        editor.select(loose.id)
        editor.nudge(by: CellOffset(cols: 1, rows: 0), within: testPane)
        editor.chooseLibraryCard("meter")
        manager.undo()
        #expect(editor.selection == [loose.id] && editor.libraryCard == nil)
    }
}
