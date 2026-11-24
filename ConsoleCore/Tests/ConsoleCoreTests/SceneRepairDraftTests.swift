import Foundation
import Testing

@testable import ConsoleCore

/// `scene-repair`: which scenes need a repair, and a repair applied to a draft and to the open
/// editor, against the trimmed copy of audio-vue's schema.
@MainActor
struct SceneRepairDraftTests {
    private static let grid = CellSize(cols: 96, rows: 36)

    private static func schemaText() throws -> String {
        let file = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "Fixtures/schema-trimmed.json")
        return try String(contentsOf: file, encoding: .utf8)
    }

    private static func shape() throws -> SceneShape {
        SceneShape(
            schema: try JSONDecoder().decode(JSONValue.self, from: Data(try schemaText().utf8)))
    }

    /// A stored scene written before the RTA's settings moved to its card, holding a card the
    /// host no longer has between two it has.
    private static func stale(builtIn: Bool = false) throws -> SceneDocument {
        let doc =
            #"{"name": "Primary", "analysis": {"rta_weighting": "F", "rta_hold_s": 1}, "cards": ["#
            + #"{"card": "rta_bars", "col": 0, "row": 0, "colspan": 48, "rowspan": 36},"#
            + #"{"card": "spectrum_old", "col": 48, "row": 0, "colspan": 8, "rowspan": 8},"#
            + #"{"card": "meter", "col": 56, "row": 0, "colspan": 8, "rowspan": 8}]}"#
        return SceneDocument(
            id: "u1", name: "Primary", builtIn: builtIn, fixed: false,
            doc: try JSONDecoder().decode(JSONValue.self, from: Data(doc.utf8)), rev: 4)
    }

    @Test func aStaleSceneNeedsARepairAndIsNotUnsavedUntilRepaired() throws {
        let drafts = SceneDrafts()
        let document = try Self.stale()
        let draft = try drafts.draft(for: document, panel: Self.grid)
        let repair = try #require(drafts.repair(of: document, shape: try Self.shape()))
        #expect(repair.canRepair && repair.removedCards == [1])
        #expect(!draft.isUnsaved)
    }

    @Test func aBuiltInIsNeverRepaired() throws {
        #expect(
            SceneDrafts().repair(of: try Self.stale(builtIn: true), shape: try Self.shape()) == nil)
    }

    @Test func aRepairIsAnUnsavedNewParseKeepingTheCardsItKeeps() throws {
        let drafts = SceneDrafts()
        let document = try Self.stale()
        let shape = try Self.shape()
        let ids = try drafts.draft(for: document, panel: Self.grid).layout.cards.map(\.id)
        try drafts.repair("u1", with: try #require(drafts.repair(of: document, shape: shape)))
        let repaired = try #require(drafts.draft("u1"))
        #expect(repaired.isUnsaved && repaired.repaired && repaired.rev == 4)
        #expect(repaired.layout.cards.map(\.id) == [ids[0], ids[2]])
        #expect(repaired.doc["analysis"] == .object([:]))
        #expect(drafts.repair(of: document, shape: shape) == nil)
    }

    /// The repair is held per scene, but follows the draft: deleting the unknown card by hand
    /// leaves only the analysis keys to repair.
    @Test func aHeldRepairFollowsAnEdit() throws {
        let drafts = SceneDrafts()
        let document = try Self.stale()
        let shape = try Self.shape()
        let draft = try drafts.draft(for: document, panel: Self.grid)
        #expect(drafts.repair(of: document, shape: shape)?.removedCards == [1])
        let unknown = try #require(draft.layout.cards.first { $0.kind == "spectrum_old" })
        drafts.keep(
            draft.content.with(layout: draft.layout.removing([unknown.id])), for: "u1")
        let repair = try #require(drafts.repair(of: document, shape: shape))
        #expect(repair.removedCards.isEmpty && repair.changes.count == 2)
    }

    @Test func aRepairedDraftStaysUnsavedOnAnotherPanel() throws {
        let drafts = SceneDrafts()
        let document = try Self.stale()
        _ = try drafts.draft(for: document, panel: Self.grid)
        try drafts.repair(
            "u1", with: try #require(drafts.repair(of: document, shape: try Self.shape())))
        drafts.relay(on: CellSize(cols: 64, rows: 36))
        #expect(drafts.draft("u1")?.isUnsaved == true)
    }

    @Test func aRevertAfterARepairIsANewParseNeedingTheRepairAgain() throws {
        let drafts = SceneDrafts()
        let document = try Self.stale()
        let shape = try Self.shape()
        _ = try drafts.draft(for: document, panel: Self.grid)
        try drafts.repair("u1", with: try #require(drafts.repair(of: document, shape: shape)))
        let reverted = try #require(try drafts.revert("u1", to: document))
        #expect(reverted.newParse)
        #expect(drafts.draft("u1")?.isUnsaved == false)
        #expect(drafts.repair(of: document, shape: shape) != nil)
    }

    /// The session's Repair, with the host serving the real schema: "Mine" holds `peak` on its
    /// card's entry, which a placement does not declare.
    @Test func theSessionRepairsAndRevertsTheOpenScene() async throws {
        var answers = PanelScenesTests.answers()
        answers[.schema] = .status(200, try Self.schemaText())
        answers[.scenes] = PanelScenesTests.listingWithMine
        answers[.scene("u1")] = PanelScenesTests.mine(rev: 3)
        let scenes = try PanelScenesTests.scenes(FakeTransport(answers))
        await scenes.load()
        let writes = SceneWrites(
            scenes: scenes, drafts: SceneDrafts(), thumbnails: SceneThumbnails())
        let mine = try #require(scenes.scenes.last)
        let draft = try writes.drafts.draft(for: mine, panel: CellSize(cols: 64, rows: 36))
        let editor = SceneEditor(content: draft.content, undoManager: UndoManager()) {
            writes.drafts.keep($0, for: "u1")
        }
        let session = SceneSession(id: "u1", writes: writes)
        session.attach(editor)
        #expect(session.neededRepair?.lines == ["meter (card 1): peak removed"])
        session.repair()
        #expect(session.isUnsaved && session.neededRepair == nil && session.parses == 1)
        session.revert()
        #expect(!session.isUnsaved && session.neededRepair != nil)
    }
}
