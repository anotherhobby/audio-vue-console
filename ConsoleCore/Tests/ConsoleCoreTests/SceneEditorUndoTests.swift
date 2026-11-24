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
        editor.nudge(by: CellOffset(cols: 2, rows: 0), within: testPane)
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
        editor.resize(left.id, edges: .bottom, by: CellOffset(cols: 0, rows: 2), within: testPane)
        #expect(manager.undoActionName == "Resize")
        editor.resize(left.id, edges: .bottom, by: CellOffset(cols: 0, rows: -2), within: testPane)
        editor.toggle(right.id)
        editor.group()
        #expect(manager.undoActionName == "Group")
        editor.ungroup()
        #expect(manager.undoActionName == "Ungroup")
        editor.drop(
            kind: "meter", size: CellSize(cols: 2, rows: 2), at: Cell(col: 30, row: 20),
            within: testPane)
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
        editor.nudge(by: CellOffset(cols: 2, rows: 0), within: testPane)
        editor.nudge(by: CellOffset(cols: -6, rows: 0), within: testPane)
        #expect(editor.refusal == .spaceTaken)
        manager.undo()
        #expect(editor.layout.card(right.id)?.cells.col == 4)
        #expect(!manager.canUndo)
    }

    @Test func anEditThatChangesNothingAddsNoStep() throws {
        editor.select(left.id)
        editor.nudge(by: CellOffset(cols: -3, rows: 0), within: testPane)
        #expect(!manager.canUndo)
    }

    @Test func aRevertIsUndoneByName() throws {
        let saved = editor.content
        editor.select(right.id)
        editor.nudge(by: CellOffset(cols: 2, rows: 0), within: testPane)
        let edited = editor.layout
        editor.revert(to: saved)
        #expect(editor.content == saved)
        #expect(manager.undoActionName == "Revert")
        manager.undo()
        #expect(editor.layout == edited)
    }

    @Test func aReplaceLeavesNoUndo() throws {
        editor.select(right.id)
        editor.nudge(by: CellOffset(cols: 2, rows: 0), within: testPane)
        let other = try layout([card("c", rect(10, 0, 4, 4))])
        editor.replace(with: SceneContent(layout: other))
        #expect(editor.layout == other)
        #expect(editor.selection.isEmpty)
        #expect(!manager.canUndo)
    }

    @Test func detachingRemovesTheEditorsActions() throws {
        editor.select(right.id)
        editor.nudge(by: CellOffset(cols: 2, rows: 0), within: testPane)
        editor.detach()
        #expect(!manager.canUndo)
    }
}

/// `card-settings`, "Each setting change is one step to undo" and "A shared setting is changed on
/// every selected card" (design D4).
@MainActor struct SceneEditorSettingsUndoTests {
    private let manager = UndoManager()
    private let vu = card("vu_meter", rect(0, 0, 4, 4), group: "g")
    private let peak = card("peak_rms", rect(4, 0, 4, 4), group: "g")
    private let loose = card("peak_rms", rect(8, 0, 4, 4))
    private let editor: SceneEditor

    init() throws {
        manager.groupsByEvent = false
        editor = SceneEditor(layout: try layout([vu, peak, loose]), undoManager: manager)
    }

    @Test func aChangeIsOneStepNamedForItsLabel() {
        editor.select(loose.id)
        editor.set("lamp_hold_s", to: .integer(2), label: "Lamp hold", on: [loose.id])
        #expect(manager.undoActionName == "Change Lamp hold")
        #expect(editor.layout.card(loose.id)?.settings["lamp_hold_s"] == .integer(2))
        manager.undo()
        #expect(editor.layout.card(loose.id)?.settings.isEmpty == true)
        #expect(!manager.canUndo)
    }

    @Test func useDefaultIsOneStepNamedForItsLabel() {
        editor.select(loose.id)
        editor.set("floor_db", to: .integer(-80), label: "Floor", on: [loose.id])
        editor.useDefault("floor_db", label: "Floor", on: [loose.id])
        #expect(manager.undoActionName == "Use Default for Floor")
        #expect(editor.layout.card(loose.id)?.settings["floor_db"] == nil)
        manager.undo()
        #expect(editor.layout.card(loose.id)?.settings["floor_db"] == .integer(-80))
    }

    @Test func settingTheCurrentValueAddsNoStep() {
        editor.select(loose.id)
        editor.set("floor_db", to: .integer(-80), label: "Floor", on: [loose.id])
        manager.removeAllActions()
        editor.set("floor_db", to: .integer(-80), label: "Floor", on: [loose.id])
        editor.useDefault("show_scale", label: "Scale", on: [loose.id])
        #expect(!manager.canUndo)
    }

    @Test func aChangeOnTwoCardsUndoesAsOne() {
        editor.select(vu.id)
        editor.set("show_readout", to: .bool(false), label: "Readout", on: [vu.id, peak.id])
        #expect(editor.selectedCards.allSatisfy { $0.settings["show_readout"] == .bool(false) })
        manager.undo()
        #expect(editor.selectedCards.allSatisfy { $0.settings.isEmpty })
        #expect(!manager.canUndo)
    }

    @Test func aChangeOnOneCardOfAGroupChangesThatCardAlone() {
        editor.select(vu.id)
        #expect(editor.selection == [vu.id, peak.id])
        editor.set("channel", to: .string("right"), label: "Channel", on: [vu.id])
        #expect(editor.layout.card(vu.id)?.settings["channel"] == .string("right"))
        #expect(editor.layout.card(peak.id)?.settings.isEmpty == true)
    }

    @Test func aCardThatLeftTheSelectionIsStillChanged() {
        editor.select(loose.id)
        editor.set("floor_db", to: .integer(-80), label: "Floor", on: [loose.id])
        editor.select(vu.id)
        editor.set("floor_db", to: .integer(-70), label: "Floor", on: [loose.id])
        #expect(editor.layout.card(loose.id)?.settings["floor_db"] == .integer(-70))
        #expect(editor.layout.card(vu.id)?.settings.isEmpty == true)
    }

    @Test func aReadOnlySceneRefusesAChange() throws {
        let readOnly = SceneEditor(layout: try layout([loose]), readOnly: .builtIn)
        readOnly.select(loose.id)
        readOnly.set("floor_db", to: .integer(-80), label: "Floor", on: [loose.id])
        readOnly.useDefault("floor_db", label: "Floor", on: [loose.id])
        #expect(readOnly.layout.card(loose.id)?.settings.isEmpty == true)
        #expect(readOnly.refusal == .readOnly(.builtIn))
    }
}

/// `scene-settings`, "A scene setting change is an edit to the open scene" and "A read-only
/// scene's settings are shown, not changed" (design D1, D2).
@MainActor struct SceneEditorBlockTests {
    private let manager = UndoManager()
    private let left = card("a", rect(0, 0, 4, 4))
    private let editor: SceneEditor

    init() throws {
        manager.groupsByEvent = false
        let colours = JSONValue.object(["series": .string("#00FF88")])
        editor = SceneEditor(
            content: SceneContent(layout: try layout([left]), blocks: ["colors": colours]),
            undoManager: manager)
    }

    @Test func undoingAcrossKindsOfEdit() throws {
        editor.select(left.id)
        editor.nudge(by: CellOffset(cols: 2, rows: 0), within: testPane)
        editor.setBlock("backdrop", "color", to: .string("#102030"), label: "Colour")
        #expect(editor.content.blocks["backdrop"] == .object(["color": .string("#102030")]))
        #expect(manager.undoActionName == "Change Colour")
        manager.undo()
        #expect(editor.content.blocks["backdrop"] == nil)
        #expect(editor.layout.card(left.id)?.cells.col == 2)
        manager.undo()
        #expect(editor.layout.card(left.id)?.cells.col == 0)
    }

    @Test func useDefaultOnTheLastKeyRemovesTheBlock() throws {
        editor.useDefault(block: "colors", key: "series", label: "Series")
        #expect(editor.content.blocks["colors"] == nil)
        #expect(manager.undoActionName == "Use Default for Series")
        manager.undo()
        #expect(editor.content.blocks["colors"]?["series"] == .string("#00FF88"))
    }

    @Test func theScenesOwnSettingIsSetAndLeftUnset() throws {
        editor.setScene("typeface", to: .string("oxanium"), label: "Typeface")
        #expect(editor.content.blocks["typeface"] == .string("oxanium"))
        #expect(manager.undoActionName == "Change Typeface")
        editor.useDefault(scene: "typeface", label: "Typeface")
        #expect(editor.content.blocks["typeface"] == nil)
        manager.undo()
        #expect(editor.content.blocks["typeface"] == .string("oxanium"))
    }

    @Test func aWholeBlockIsOneStep() throws {
        let stops = JSONValue.array([.string("#000000"), .string("#FFFFFF")])
        editor.replace(block: "backdrop", with: ["gradient": stops], label: "Backdrop")
        editor.replace(block: "backdrop", with: [:], label: "Backdrop")
        #expect(editor.content.blocks["backdrop"] == nil)
        manager.undo()
        #expect(editor.content.blocks["backdrop"]?["gradient"]?.arrayValue?.count == 2)
    }

    @Test func aReadOnlySceneRefusesBlockEdits() throws {
        let readOnly = SceneEditor(
            content: SceneContent(layout: try layout([left]), blocks: editor.content.blocks),
            readOnly: .builtIn)
        readOnly.setBlock("colors", "series", to: .string("#FFFFFF"), label: "Series")
        readOnly.useDefault(block: "colors", key: "series", label: "Series")
        #expect(readOnly.content.blocks == editor.content.blocks)
        #expect(readOnly.refusal == .readOnly(.builtIn))
    }
}
