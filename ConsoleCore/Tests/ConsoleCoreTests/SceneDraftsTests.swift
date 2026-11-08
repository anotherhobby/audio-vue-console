import Foundation
import Testing

@testable import ConsoleCore

/// `scene-canvas`, "Edits are kept until saved or discarded", and `scene-gallery`, "Duplicate
/// makes an unsaved copy": each draft keeps the parse it came from, so a card's settings survive.
@MainActor
struct SceneDraftsTests {
    static let grid = CellSize(cols: 64, rows: 36)

    /// The built-in RTA: a meter carrying a setting of its own, and bars beside it.
    static func rta() throws -> SceneDocument {
        let doc =
            #"{"name": "RTA", "grid": {"cols": 96, "rows": 36}, "cards": ["#
            + #"{"card": "meter", "col": 0, "row": 0, "colspan": 8, "rowspan": 8, "peak": "hold"},"#
            + #"{"card": "rta_bars", "col": 48, "row": 0, "colspan": 48, "rowspan": 36}]}"#
        return SceneDocument(
            id: "rta", name: "RTA", builtIn: true, fixed: false,
            doc: try JSONDecoder().decode(JSONValue.self, from: Data(doc.utf8)))
    }

    /// The bars moved ten columns left, in `draft`'s own parse.
    static func moveBars(_ draft: Draft) throws -> SceneLayout {
        let bars = try #require(draft.layout.cards.last)
        return try draft.layout.moving([bars.id], by: CellOffset(cols: -10, rows: 0))
    }

    @Test func aDraftIsTheSameOnASecondAsk() throws {
        let drafts = SceneDrafts()
        let first = try drafts.draft(for: try Self.rta(), defaultGrid: Self.grid)
        let second = try drafts.draft(for: try Self.rta(), defaultGrid: Self.grid)
        #expect(first == second)
        #expect(first.layout.cards.map(\.id) == second.layout.cards.map(\.id))
    }

    @Test func aKeptEditKeepsTheOtherCardsSettings() throws {
        let drafts = SceneDrafts()
        let draft = try drafts.draft(for: try Self.rta(), defaultGrid: Self.grid)
        drafts.keep(try Self.moveBars(draft), for: "rta")
        let kept = try #require(drafts.draft("rta"))
        let cards = try #require(kept.doc["cards"]?.arrayValue)
        #expect(cards.first?["peak"] == .string("hold"))
        #expect(cards.last?["col"] == .integer(38))
    }

    @Test func anEditThenItsUndoIsNotUnsaved() throws {
        let drafts = SceneDrafts()
        let draft = try drafts.draft(for: try Self.rta(), defaultGrid: Self.grid)
        #expect(!draft.isUnsaved)
        drafts.keep(try Self.moveBars(draft), for: "rta")
        #expect(drafts.draft("rta")?.isUnsaved == true)
        drafts.keep(draft.layout, for: "rta")
        #expect(drafts.draft("rta")?.isUnsaved == false)
        #expect(drafts.unsaved([try Self.rta()]).isEmpty)
    }

    @Test func aDuplicateIsAnUnsavedEditableCopyNamedForTheScene() throws {
        let drafts = SceneDrafts()
        let rta = try Self.rta()
        let copy = drafts.duplicate(
            try drafts.draft(for: rta, defaultGrid: Self.grid), among: [rta])
        #expect(copy.name == "RTA copy")
        #expect(!copy.builtIn && !copy.fixed && copy.rev == nil)
        #expect(copy.doc["name"] == .string("RTA copy"))
        #expect(SceneDrafts.isCopy(copy.id))
        #expect(drafts.listing([rta]).map(\.id) == ["rta", copy.id])
        #expect(drafts.draft(copy.id)?.isUnsaved == true)
        #expect(drafts.unsaved([rta]).map(\.id) == [copy.id])
    }

    @Test func aDuplicateOfAnEditedSceneKeepsTheEditsAndTheSettings() throws {
        let drafts = SceneDrafts()
        let rta = try Self.rta()
        let draft = try drafts.draft(for: rta, defaultGrid: Self.grid)
        drafts.keep(try Self.moveBars(draft), for: "rta")
        let copy = drafts.duplicate(try #require(drafts.draft("rta")), among: [rta])
        let cards = try #require(copy.doc["cards"]?.arrayValue)
        #expect(cards.first?["peak"] == .string("hold"))
        #expect(cards.last?["col"] == .integer(38))
        let copied = try #require(drafts.draft(copy.id))
        #expect(copied.doc["cards"]?.arrayValue?.first?["peak"] == .string("hold"))
        #expect(copied.doc["name"] == .string("RTA copy"))
    }

    @Test func copiesAreNamedForTheFirstFreeNumber() throws {
        let drafts = SceneDrafts()
        let rta = try Self.rta()
        let draft = try drafts.draft(for: rta, defaultGrid: Self.grid)
        #expect(drafts.duplicate(draft, among: [rta]).name == "RTA copy")
        #expect(drafts.duplicate(draft, among: [rta]).name == "RTA copy 2")
        #expect(drafts.duplicate(draft, among: [rta]).name == "RTA copy 3")
    }

    /// The stored scene "Mine" at `rev`, with the bars at `barsCol`.
    static func mine(rev: Int, name: String = "Mine", barsCol: Int = 48) throws -> SceneDocument {
        let doc =
            #"{"name": "\#(name)", "grid": {"cols": 96, "rows": 36}, "cards": ["#
            + #"{"card": "meter", "col": 0, "row": 0, "colspan": 8, "rowspan": 8, "peak": "hold"},"#
            + #"{"card": "rta_bars", "col": \#(barsCol), "row": 0, "colspan": 48, "rowspan": 36}]}"#
        return SceneDocument(
            id: "u1", name: name, builtIn: false, fixed: false,
            doc: try JSONDecoder().decode(JSONValue.self, from: Data(doc.utf8)), rev: rev)
    }

    @Test func aSavedSceneIsNotUnsavedAndItsEditorKeepsPairing() throws {
        let drafts = SceneDrafts()
        let draft = try drafts.draft(for: try Self.mine(rev: 3), defaultGrid: Self.grid)
        let moved = try Self.moveBars(draft)
        drafts.keep(moved, for: "u1")
        drafts.saved(try Self.mine(rev: 4, barsCol: 38), was: "u1")
        let saved = try #require(drafts.draft("u1"))
        #expect(!saved.isUnsaved && saved.rev == 4)
        #expect(saved.layout == moved)
        let bars = try #require(moved.cards.last)
        drafts.keep(try moved.moving([bars.id], by: CellOffset(cols: -2, rows: 0)), for: "u1")
        let edited = try #require(drafts.draft("u1"))
        #expect(edited.isUnsaved)
        #expect(edited.doc["cards"]?.arrayValue?.first?["peak"] == .string("hold"))
        #expect(edited.doc["cards"]?.arrayValue?.last?["col"] == .integer(36))
    }

    @Test func aSavedCopyMovesToTheHostsID() throws {
        let drafts = SceneDrafts()
        let rta = try Self.rta()
        let copy = drafts.duplicate(
            try drafts.draft(for: rta, defaultGrid: Self.grid), among: [rta])
        let stored = SceneDocument(
            id: "u2", name: "RTA copy", builtIn: false, fixed: false, doc: copy.doc, rev: 1)
        drafts.saved(stored, was: copy.id)
        #expect(drafts.draft(copy.id) == nil)
        #expect(drafts.copies.isEmpty)
        #expect(drafts.draft("u2")?.isUnsaved == false)
    }

    @Test func aRenameKeepsAnUnsavedLayoutAndMovesTheBase() throws {
        let drafts = SceneDrafts()
        let draft = try drafts.draft(for: try Self.mine(rev: 3), defaultGrid: Self.grid)
        let moved = try Self.moveBars(draft)
        drafts.keep(moved, for: "u1")
        drafts.renamed("u1", to: try Self.mine(rev: 4, name: "Studio"))
        let renamed = try #require(drafts.draft("u1"))
        #expect(renamed.layout == moved && renamed.isUnsaved)
        #expect(renamed.rev == 4)
        #expect(renamed.doc["name"] == .string("Studio"))
        #expect(renamed.doc["cards"]?.arrayValue?.last?["col"] == .integer(38))
    }

    @Test func aCleanDraftIsReadAgainOnARename() throws {
        let drafts = SceneDrafts()
        _ = try drafts.draft(for: try Self.mine(rev: 3), defaultGrid: Self.grid)
        drafts.renamed("u1", to: try Self.mine(rev: 4, name: "Studio"))
        let renamed = try #require(drafts.draft("u1"))
        #expect(!renamed.isUnsaved && renamed.rev == 4 && renamed.name == "Studio")
    }

    @Test func aCopyIsRenamedInTheAppAlone() throws {
        let drafts = SceneDrafts()
        let rta = try Self.rta()
        let copy = drafts.duplicate(
            try drafts.draft(for: rta, defaultGrid: Self.grid), among: [rta])
        drafts.renameCopy(copy.id, to: "Wide")
        #expect(drafts.copies.first?.name == "Wide")
        #expect(drafts.draft(copy.id)?.doc["name"] == .string("Wide"))
        #expect(drafts.draft(copy.id)?.isUnsaved == true)
        drafts.discard(copy.id)
        #expect(drafts.copies.isEmpty && drafts.draft(copy.id) == nil)
    }

    /// Revision 3 of "Mine", saved as "My RTA", with the bars at column 20.
    static func revision3() throws -> SceneRevision {
        SceneRevision(
            rev: 3, savedAt: Date(timeIntervalSince1970: 0),
            doc: try mine(rev: 3, name: "My RTA", barsCol: 20).doc)
    }

    @Test func aLoadedVersionIsUnsavedUnderTheCurrentName() throws {
        let drafts = SceneDrafts()
        _ = try drafts.draft(for: try Self.mine(rev: 5, name: "Studio"), defaultGrid: Self.grid)
        try drafts.load(try Self.revision3(), for: "u1")
        let loaded = try #require(drafts.draft("u1"))
        #expect(loaded.layout == loaded.laidOut.layout)
        #expect(loaded.isUnsaved)
        #expect(loaded.rev == 5 && loaded.source == 3)
        #expect(loaded.doc["name"] == .string("Studio"))
        #expect(loaded.doc["cards"]?.arrayValue?.last?["col"] == .integer(20))
        #expect(loaded.doc["cards"]?.arrayValue?.first?["peak"] == .string("hold"))
    }

    @Test func aRevertAfterALoadIsANewParse() throws {
        let drafts = SceneDrafts()
        let current = try Self.mine(rev: 5, name: "Studio")
        _ = try drafts.draft(for: current, defaultGrid: Self.grid)
        try drafts.load(try Self.revision3(), for: "u1")
        let reverted = try #require(try drafts.revert("u1", to: current))
        #expect(reverted.newParse)
        #expect(drafts.draft("u1")?.isUnsaved == false)
        #expect(reverted.layout.cards.last?.cells.col == 48)
    }

    @Test func aRevertAfterAnEditIsTheSameParse() throws {
        let drafts = SceneDrafts()
        let current = try Self.mine(rev: 5)
        let draft = try drafts.draft(for: current, defaultGrid: Self.grid)
        drafts.keep(try Self.moveBars(draft), for: "u1")
        let reverted = try #require(try drafts.revert("u1", to: current))
        #expect(!reverted.newParse)
        #expect(reverted.layout == draft.laidOut.layout)
    }

    @Test func draftsAreKeptUntilForgotten() throws {
        let drafts = SceneDrafts()
        let rta = try Self.rta()
        _ = drafts.duplicate(try drafts.draft(for: rta, defaultGrid: Self.grid), among: [rta])
        drafts.forget()
        #expect(drafts.draft("rta") == nil)
        #expect(drafts.copies.isEmpty)
    }
}
