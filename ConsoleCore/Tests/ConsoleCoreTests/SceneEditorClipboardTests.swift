import Foundation
import Testing

@testable import ConsoleCore

/// `card-clipboard`'s Cut and Paste through the editor the canvas drives. A test has no run loop to
/// close undo groups, so the manager has `groupsByEvent` off.
@MainActor struct SceneEditorClipboardTests {
    private let manager = UndoManager()
    /// A pair grouped as `pair` on columns 0 to 7, and a loose card at column 20.
    private let pair = [
        card("a", rect(0, 0, 4, 4), group: "pair"), card("b", rect(4, 0, 4, 4), group: "pair"),
    ]
    private let loose = card("c", rect(20, 0, 4, 4))
    private let scene: SceneLayout

    init() throws {
        manager.groupsByEvent = false
        scene = try layout(pair + [loose])
    }

    /// The loose card copied, with a setting, as its scene writes it.
    private let copiedLoose = CopiedCards(entries: [
        .object([
            "card": .string("c"), "col": .integer(20), "row": .integer(0),
            "colspan": .integer(4), "rowspan": .integer(4), "params": .object(["x": .integer(1)]),
        ])
    ])

    private func paste(_ copied: CopiedCards, into editor: SceneEditor) {
        editor.paste(copied, within: testPane, panelCols: 64, placeable: ["c"])
    }

    /// "Pasting where it was copied": the copy is added and selected, as one step named Paste.
    @Test func aPasteIsSelectedAndUndoneAsOne() throws {
        let editor = SceneEditor(layout: scene, undoManager: manager)
        editor.select(pair[0].id)
        paste(copiedLoose, into: editor)
        let pasted = try #require(editor.layout.cards.last)
        #expect(pasted.id != loose.id && editor.selection == [pasted.id])
        #expect(pasted.settings == ["x": .integer(1)])
        #expect(manager.undoActionName == "Paste")
        manager.undo()
        #expect(editor.layout == scene)
        #expect(editor.selection == Set(pair.map(\.id)))
    }

    /// "Cutting a group member": the whole group goes, as one step named Cut.
    @Test func cuttingAMemberCutsItsGroup() throws {
        let editor = SceneEditor(layout: scene, undoManager: manager)
        editor.select(pair[1].id)
        editor.cut()
        #expect(editor.layout.cards.map(\.id) == [loose.id])
        #expect(editor.selection.isEmpty)
        #expect(manager.undoActionName == "Cut")
        manager.undo()
        #expect(editor.layout == scene)
    }

    @Test func cuttingTakesAParkedCard() throws {
        let editor = SceneEditor(layout: scene, undoManager: manager)
        editor.select(loose.id)
        editor.drag(by: CellOffset(cols: 0, rows: 36), within: testPane)
        #expect(editor.hasParked)
        editor.cut()
        #expect(!editor.hasParked && editor.layout.cards.count == 2)
    }

    @Test func anUnreadablePasteIsRefused() throws {
        let editor = SceneEditor(layout: scene, undoManager: manager)
        paste(CopiedCards(entries: [.object(["col": .integer(0)])]), into: editor)
        #expect(editor.refusal == .unreadableCard)
        #expect(editor.layout == scene && !manager.canUndo)
    }

    @Test func cuttingNothingAddsNoStep() throws {
        let editor = SceneEditor(layout: scene, undoManager: manager)
        editor.cut()
        #expect(editor.layout == scene && !manager.canUndo)
    }

    /// "Into a built-in scene" and "Cutting from a built-in scene".
    @Test func aReadOnlySceneRefusesCutAndPaste() throws {
        let reason = ReadOnlyReason.builtIn
        let editor = SceneEditor(layout: scene, readOnly: reason, undoManager: manager)
        editor.select(loose.id)
        editor.cut()
        #expect(editor.refusal == .readOnly(reason))
        paste(copiedLoose, into: editor)
        #expect(editor.refusal == .readOnly(reason))
        #expect(editor.layout == scene && !manager.canUndo)
    }
}
