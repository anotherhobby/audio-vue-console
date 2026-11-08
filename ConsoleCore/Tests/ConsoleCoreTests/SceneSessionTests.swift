import Foundation
import Testing

@testable import ConsoleCore

/// `scene-saving`: Revert to Saved, Versions and Discard Mine as the editor sees them. A test has
/// no run loop to close undo groups, so the manager has `groupsByEvent` off.
@MainActor
struct SceneSessionTests {
    /// A session over "Mine" at revision 3, opened in an editor whose edits the drafts keep. The
    /// session holds its editor weakly, as the view's state owns it, so the fixture keeps it.
    @MainActor private struct Opened {
        let session: SceneSession
        let editor: SceneEditor
        let manager: UndoManager
        let transport: FakeTransport

        init() async throws {
            let (scenes, transport) = try await PanelScenesTests.loadedWithMine()
            let writes = SceneWrites(
                scenes: scenes, drafts: SceneDrafts(), thumbnails: SceneThumbnails())
            let mine = try #require(scenes.scenes.last)
            let draft = try writes.drafts.draft(
                for: mine, defaultGrid: CellSize(cols: 64, rows: 36))
            manager = UndoManager()
            manager.groupsByEvent = false
            editor = SceneEditor(layout: draft.layout, undoManager: manager) {
                writes.drafts.keep($0, for: "u1")
            }
            session = SceneSession(id: "u1", writes: writes)
            session.attach(editor)
            self.transport = transport
        }
    }

    private static func moveFirst(_ editor: SceneEditor) throws {
        editor.select(try #require(editor.layout.cards.first).id)
        editor.move(by: CellOffset(cols: 10, rows: 0))
    }

    @Test func aRevertIsUndoneBackToTheEdit() async throws {
        let opened = try await Opened()
        let (session, editor, manager) = (opened.session, opened.editor, opened.manager)
        #expect(!session.canSave && !session.canRevert)
        try Self.moveFirst(editor)
        #expect(session.canSave && session.canRevert)
        session.revert()
        #expect(!session.isUnsaved)
        #expect(manager.undoActionName == "Revert")
        manager.undo()
        #expect(session.isUnsaved)
    }

    @Test func aVersionLoadsAsAnUnsavedEditWithNoUndo() async throws {
        let opened = try await Opened()
        let (session, editor, manager) = (opened.session, opened.editor, opened.manager)
        try Self.moveFirst(editor)
        let old = SceneRevision(
            rev: 2, savedAt: Date(timeIntervalSince1970: 0),
            doc: .object([
                "name": .string("My RTA"),
                "cards": .array([
                    .object([
                        "card": .string("meter"), "col": .integer(30), "colspan": .integer(8),
                        "rowspan": .integer(8),
                    ])
                ]),
            ]))
        session.load(old)
        #expect(session.parses == 1)
        #expect(session.isUnsaved && session.canRevert)
        #expect(!manager.canUndo)
        #expect(editor.layout.cards.first?.cells.col == 30)
        #expect(session.draft?.doc["name"] == .string("Mine"))
        session.revert()
        #expect(session.parses == 2)
        #expect(!session.isUnsaved)
        #expect(editor.layout.cards.first?.cells.col == 0)
    }

    @Test func discardMineShowsTheHostsScene() async throws {
        let opened = try await Opened()
        let (session, editor, transport) = (opened.session, opened.editor, opened.transport)
        try Self.moveFirst(editor)
        await transport.answer(.scene("u1"), with: PanelScenesTests.mine(rev: 4, col: 20))
        await session.discardMine()
        #expect(session.parses == 1)
        #expect(!session.isUnsaved)
        #expect(session.draft?.rev == 4)
        #expect(editor.layout.cards.first?.cells.col == 20)
    }

    @Test func aFailedSaveIsShownAndKeepsTheEdit() async throws {
        let opened = try await Opened()
        let (session, editor, transport) = (opened.session, opened.editor, opened.transport)
        try Self.moveFirst(editor)
        await transport.answer(
            .writeScene("u1"), with: .status(409, #"{"detail": "moved on", "current_rev": 4}"#))
        #expect(await session.save() == nil)
        #expect(session.failure == .stale(currentRev: 4))
        #expect(session.isUnsaved)
    }

    @Test func applySaysWhatTheSwitchCost() async throws {
        let opened = try await Opened()
        let body =
            #"{"status": "done", "scene": "u1", "capture": "rebuilt", "why": "deeper history", "#
            + #""recorded": false}"#
        await opened.transport.answer(.switchScene, with: .status(200, body))
        #expect(await opened.session.apply() == "u1")
        let result = SwitchResult(capture: .rebuilt, why: "deeper history", recorded: false)
        #expect(opened.session.note == EditorNote(kind: .apply, result: .success(.done(result))))
    }

    @Test func aResetsOutcomeIsNoted() async throws {
        let opened = try await Opened()
        let body = #"{"status": "refused", "reason": "a calibration has the panel"}"#
        await opened.transport.answer(.reset, with: .status(409, body))
        await opened.session.reset()
        let refused = CommandOutcome.refused("a calibration has the panel")
        #expect(opened.session.note == EditorNote(kind: .reset, result: .success(refused)))
    }

    @Test func theRevisionsAreRead() async throws {
        let opened = try await Opened()
        let (session, transport) = (opened.session, opened.transport)
        let body =
            #"{"revisions": [{"rev": 2, "saved_at": "2026-11-07T21:00:05+00:00", "doc": {}}]}"#
        await transport.answer(.revisions("u1"), with: .status(200, body))
        await session.readRevisions()
        #expect(session.revisions.map(\.rev) == [2])
        #expect(session.hasVersions)
    }
}
