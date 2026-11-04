import Foundation
import Testing

@testable import ConsoleCore

/// `scene-canvas`'s selection, previews and refusals, through the editor the canvas drives.
@MainActor struct SceneEditorTests {
    /// A pair grouped as `pair` on columns 0 to 7, and a loose card at column 20.
    private let pair = [
        card("a", rect(0, 0, 4, 4), group: "pair"), card("b", rect(4, 0, 4, 4), group: "pair"),
    ]
    private let loose = card("c", rect(20, 0, 4, 4))
    private let scene: SceneLayout

    init() throws {
        scene = try layout(pair + [loose])
    }

    @Test func selectingAMemberSelectsItsGroup() throws {
        let editor = SceneEditor(layout: scene)
        editor.select(pair[1].id)
        #expect(editor.selection == Set(pair.map(\.id)))
    }

    @Test func toggleAddsAndRemovesWholeGroups() throws {
        let editor = SceneEditor(layout: scene)
        editor.select(loose.id)
        editor.toggle(pair[0].id)
        #expect(editor.selection.count == 3)
        editor.toggle(pair[1].id)
        #expect(editor.selection == [loose.id])
    }

    @Test func aMarqueeSelectsWhatItTouches() throws {
        let editor = SceneEditor(layout: scene)
        editor.select(touching: rect(6, 0, 1, 1))
        #expect(editor.selection == Set(pair.map(\.id)))
        editor.select(touching: rect(21, 3, 1, 1), adding: true)
        #expect(editor.selection == Set(pair.map(\.id) + [loose.id]))
        editor.select(touching: rect(30, 30, 2, 2))
        #expect(editor.selection.isEmpty)
    }

    @Test func onlyALoneUngroupedCardIsResizable() throws {
        let editor = SceneEditor(layout: scene)
        editor.select(loose.id)
        #expect(editor.resizableCard?.id == loose.id)
        editor.select(pair[0].id)
        #expect(editor.resizableCard == nil)
    }

    @Test func previewsCommitNothing() throws {
        let editor = SceneEditor(layout: scene)
        editor.select(loose.id)
        let moved = try editor.previewMove(by: CellOffset(cols: 2, rows: 0)).get()
        #expect(moved.card(loose.id)?.cells.col == 22)
        #expect(editor.layout == scene)
        let refused = editor.previewMove(by: CellOffset(cols: -14, rows: 0))
        #expect(throws: LayoutRefusal.spaceTaken) { try refused.get() }
        #expect(editor.refusal == nil)
    }

    @Test func aRefusalIsKeptUntilTheNextSelection() throws {
        let editor = SceneEditor(layout: scene)
        editor.select(loose.id)
        editor.move(by: CellOffset(cols: -14, rows: 0))
        #expect(editor.refusal == .spaceTaken)
        #expect(editor.layout == scene)
        editor.clearSelection()
        #expect(editor.refusal == nil)
    }

    @Test func aDroppedCardIsSelected() throws {
        let editor = SceneEditor(layout: try layout([]))
        editor.drop(kind: "meter", size: CellSize(cols: 4, rows: 4), at: Cell(col: 10, row: 10))
        let added = try #require(editor.layout.cards.last)
        #expect(editor.selection == [added.id])
    }

    @Test func groupRefusalSaysWhy() throws {
        let editor = SceneEditor(layout: scene)
        editor.select(pair[0].id)
        #expect(editor.groupRefusal == .alreadyAGroup)
        #expect(editor.canUngroup)
        editor.toggle(loose.id)
        #expect(editor.groupRefusal == .cardInTheWay || editor.groupRefusal == .notARectangle)
    }

    @Test func committedLayoutsReachTheApp() throws {
        var committed: [SceneLayout] = []
        let editor = SceneEditor(layout: scene) { committed.append($0) }
        editor.select(loose.id)
        editor.move(by: CellOffset(cols: 1, rows: 0))
        editor.move(by: CellOffset(cols: -30, rows: 0))
        #expect(committed == [editor.layout])
    }

    @Test(arguments: [ReadOnlyReason.builtIn, .shape(scene: "16:9", panel: "8:3")])
    func aReadOnlySceneRefusesEveryEdit(reason: ReadOnlyReason) throws {
        let editor = SceneEditor(layout: scene, readOnly: reason)
        editor.select(loose.id)
        #expect(editor.selection == [loose.id])
        #expect(editor.resizableCard == nil)
        editor.move(by: CellOffset(cols: 1, rows: 0))
        editor.resize(loose.id, edges: .right, by: CellOffset(cols: 1, rows: 0))
        editor.drop(kind: "meter", size: CellSize(cols: 2, rows: 2), at: Cell(col: 40, row: 20))
        editor.deleteSelection()
        editor.select(pair[0].id)
        editor.ungroup()
        #expect(editor.layout == scene)
        #expect(editor.refusal == .readOnly(reason))
        #expect(editor.groupRefusal == .readOnly(reason))
        #expect(!editor.canUngroup)
    }
}
