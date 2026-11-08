import Foundation
import Testing

@testable import ConsoleCore

/// `scene-layout`, "Every edit can be undone", and `scene-canvas`, "Undo and Redo name the edit".
/// A test has no run loop to close undo groups, so each manager has `groupsByEvent` off.
@MainActor struct SceneEditorUndoTests {
    private let manager = UndoManager()
    private let left = card("a", rect(0, 0, 4, 4))
    private let right = card("b", rect(4, 0, 4, 4))
    private let editor: SceneEditor

    init() throws {
        manager.groupsByEvent = false
        editor = SceneEditor(layout: try layout([left, right]), undoManager: manager)
    }

    @Test func undoingAndRedoingAMove() throws {
        editor.select(right.id)
        editor.move(by: CellOffset(cols: 2, rows: 0))
        #expect(manager.undoActionName == "Move")
        manager.undo()
        #expect(editor.layout.card(right.id)?.cells.col == 4)
        #expect(manager.redoActionName == "Move")
        manager.redo()
        #expect(editor.layout.card(right.id)?.cells.col == 6)
        #expect(editor.layout.card(left.id)?.cells.col == 0)
    }

    @Test func eachEditIsNamed() throws {
        editor.select(left.id)
        editor.resize(left.id, edges: .bottom, by: CellOffset(cols: 0, rows: 2))
        #expect(manager.undoActionName == "Resize")
        editor.resize(left.id, edges: .bottom, by: CellOffset(cols: 0, rows: -2))
        editor.toggle(right.id)
        editor.group()
        #expect(manager.undoActionName == "Group")
        editor.ungroup()
        #expect(manager.undoActionName == "Ungroup")
        editor.drop(kind: "meter", size: CellSize(cols: 2, rows: 2), at: Cell(col: 30, row: 20))
        #expect(manager.undoActionName == "Add Card")
        editor.deleteSelection()
        #expect(manager.undoActionName == "Delete")
    }

    @Test func undoRestoresTheSelectionToo() throws {
        editor.select(left.id)
        editor.toggle(right.id)
        editor.deleteSelection()
        #expect(editor.layout.cards.isEmpty)
        #expect(editor.selection.isEmpty)
        manager.undo()
        #expect(editor.layout.cards.count == 2)
        #expect(editor.selection == [left.id, right.id])
    }

    @Test func aRefusedEditAddsNoStep() throws {
        editor.select(right.id)
        editor.move(by: CellOffset(cols: 2, rows: 0))
        editor.move(by: CellOffset(cols: -6, rows: 0))
        #expect(editor.refusal == .spaceTaken)
        manager.undo()
        #expect(editor.layout.card(right.id)?.cells.col == 4)
        #expect(!manager.canUndo)
    }

    @Test func anEditThatChangesNothingAddsNoStep() throws {
        editor.select(left.id)
        editor.move(by: CellOffset(cols: -3, rows: 0))
        #expect(!manager.canUndo)
    }

    @Test func aRevertIsUndoneByName() throws {
        let saved = editor.layout
        editor.select(right.id)
        editor.move(by: CellOffset(cols: 2, rows: 0))
        let edited = editor.layout
        editor.revert(to: saved)
        #expect(editor.layout == saved)
        #expect(manager.undoActionName == "Revert")
        manager.undo()
        #expect(editor.layout == edited)
    }

    @Test func aReplaceLeavesNoUndo() throws {
        editor.select(right.id)
        editor.move(by: CellOffset(cols: 2, rows: 0))
        let other = try layout([card("c", rect(10, 0, 4, 4))])
        editor.replace(with: other)
        #expect(editor.layout == other)
        #expect(editor.selection.isEmpty)
        #expect(!manager.canUndo)
    }

    @Test func detachingRemovesTheEditorsActions() throws {
        editor.select(right.id)
        editor.move(by: CellOffset(cols: 2, rows: 0))
        editor.detach()
        #expect(!manager.canUndo)
    }
}
