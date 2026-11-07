import Foundation
import Testing

@testable import ConsoleCore

/// `scene-gallery`, "Duplicate makes an unsaved copy", and edits kept until quit.
@MainActor
struct SceneDraftsTests {
    private static func laidOut() throws -> LaidOutScene {
        let doc =
            #"{"name": "RTA", "grid": {"cols": 96, "rows": 36}, "cards": ["#
            + #"{"card": "rta_bars", "col": 0, "row": 0, "colspan": 48, "rowspan": 36}]}"#
        let document = SceneDocument(
            id: "rta", name: "RTA", builtIn: true, fixed: false,
            doc: try JSONDecoder().decode(JSONValue.self, from: Data(doc.utf8)))
        return try LaidOutScene(document, defaultGrid: CellSize(cols: 64, rows: 36))
    }

    @Test func aDuplicateIsAnEditableCopyNamedForTheScene() throws {
        let drafts = SceneDrafts()
        let laid = try Self.laidOut()
        let copy = drafts.duplicate(laid)
        #expect(copy.name == "RTA copy")
        #expect(!copy.builtIn && !copy.fixed)
        #expect(copy.doc["name"] == .string("RTA copy"))
        #expect(SceneDrafts.isCopy(copy.id))
        #expect(drafts.listing([laid.document]).map(\.id) == ["rta", copy.id])
    }

    @Test func aDuplicateKeepsTheEdits() throws {
        let drafts = SceneDrafts()
        let laid = try Self.laidOut()
        let card = try #require(laid.layout.cards.first)
        drafts.keep(
            try laid.layout.moving([card.id], by: CellOffset(cols: 10, rows: 0)), for: "rta")
        let copy = drafts.duplicate(laid)
        #expect(copy.doc["cards"]?.arrayValue?.first?["col"] == .integer(10))
    }

    @Test func editsAreKeptUntilForgotten() throws {
        let drafts = SceneDrafts()
        let laid = try Self.laidOut()
        drafts.keep(laid.layout, for: "rta")
        #expect(drafts.layout(for: "rta") == laid.layout)
        _ = drafts.duplicate(laid)
        drafts.forget()
        #expect(drafts.layout(for: "rta") == nil)
        #expect(drafts.copies.isEmpty)
    }
}
