import Foundation
import Testing

@testable import ConsoleCore

/// `card-parking`, "A parked card is selected and edited like any card" and "Parked cards are part
/// of the scene's edits", through the editor the canvas drives. A test has no run loop to close undo
/// groups, so the manager has `groupsByEvent` off.
@MainActor struct SceneEditorParkingTests {
    private let manager = UndoManager()
    private let onGrid = card("rta", rect(0, 0, 10, 4))
    /// A pair grouped as `pair`, parked below the grid.
    private let pair = [
        card("a", rect(0, 40, 10, 4), group: "pair"), card("b", rect(10, 40, 10, 4), group: "pair"),
    ]
    private let loose = card("meter", rect(30, 40, 10, 4))
    private let editor: SceneEditor

    init() throws {
        manager.groupsByEvent = false
        editor = SceneEditor(
            content: SceneContent(layout: try layout([onGrid]), parked: pair + [loose]),
            undoManager: manager)
    }

    @Test func clickingAParkedMemberSelectsItsGroup() {
        editor.select(pair[1].id)
        #expect(editor.selection == Set(pair.map(\.id)))
        #expect(editor.selectedCards.map(\.id) == pair.map(\.id))
    }

    @Test func aMarqueeOffTheGridSelectsParkedCards() {
        editor.select(touching: rect(15, 41, 20, 1))
        #expect(editor.selection == Set(pair.map(\.id) + [loose.id]))
    }

    @Test func aParkedCardShowsNoHandles() {
        editor.select(loose.id)
        #expect(editor.resizableCard == nil)
        editor.select(onGrid.id)
        #expect(editor.resizableCard?.id == onGrid.id)
    }

    @Test func groupingWithAParkedCardIsRefused() {
        editor.select(onGrid.id)
        editor.toggle(loose.id)
        #expect(editor.groupRefusal == .parkedCannotGroup)
    }

    @Test func aParkedCardsSettingIsKeptOnReturn() {
        editor.set("style", to: .string("segments"), label: "Style", on: [loose.id])
        #expect(editor.content.parked.last?.settings["style"] == .string("segments"))
        editor.select(loose.id)
        editor.drag(by: CellOffset(cols: 0, rows: -30), within: testPane)
        #expect(editor.content.parked.count == 2)
        #expect(editor.layout.card(loose.id)?.settings["style"] == .string("segments"))
    }

    @Test func deletingAParkedGroup() {
        editor.select(pair[0].id)
        editor.deleteSelection()
        #expect(editor.content.parked.map(\.id) == [loose.id])
        #expect(editor.selection.isEmpty)
    }

    @Test func ungroupingAParkedGroup() {
        editor.select(pair[0].id)
        #expect(editor.canUngroup)
        editor.ungroup()
        #expect(editor.content.parked.allSatisfy { $0.group == nil })
    }

    @Test func undoingAPark() {
        editor.select(onGrid.id)
        editor.drag(by: CellOffset(cols: 0, rows: 50), within: testPane)
        #expect(editor.layout.cards.isEmpty)
        #expect(editor.hasParked)
        #expect(manager.undoActionName == "Move")
        manager.undo()
        #expect(editor.layout.card(onGrid.id)?.cells == onGrid.cells)
        #expect(manager.redoActionName == "Move")
        #expect(!manager.canUndo)
    }
}
