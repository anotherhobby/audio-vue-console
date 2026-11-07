import Foundation
import Testing

@testable import ConsoleCore

/// Design D6: a scene document read as a layout and written back changing only cells and groups.
struct LaidOutSceneTests {
    private static let defaults = CellSize(cols: 64, rows: 36)

    private static func scene(_ doc: String) throws -> SceneDocument {
        SceneDocument(
            id: "s", name: "S", builtIn: false, fixed: false,
            doc: try JSONDecoder().decode(JSONValue.self, from: Data(doc.utf8)))
    }

    @Test func anUnsetSpanCoversTheGrid() throws {
        let laid = try LaidOutScene(
            Self.scene(#"{"grid": {"cols": 96, "rows": 36}, "cards": [{"card": "logo"}]}"#),
            defaultGrid: Self.defaults)
        #expect(laid.layout.grid == CellSize(cols: 96, rows: 36))
        #expect(laid.layout.cards.first?.cells == CellRect(col: 0, row: 0, cols: 96, rows: 36))
    }

    @Test func anUnsetGridTakesTheDefaults() throws {
        let laid = try LaidOutScene(
            Self.scene(#"{"cards": [{"card": "meter", "col": 4, "colspan": 8}]}"#),
            defaultGrid: Self.defaults)
        #expect(laid.layout.grid == Self.defaults)
        #expect(laid.layout.cards.first?.cells == CellRect(col: 4, row: 0, cols: 8, rows: 36))
    }

    @Test func paramsAndPlatePassThroughAMove() throws {
        let laid = try LaidOutScene(
            Self.scene(
                #"{"name": "S", "cards": [{"card": "meter", "col": 0, "row": 0, "colspan": 8, "#
                    + ##""rowspan": 6, "plate": "#123456", "params": {"floor_db": -60.5}}]}"##),
            defaultGrid: Self.defaults)
        let id = try #require(laid.layout.cards.first?.id)
        let moved = try laid.layout.moving([id], by: CellOffset(cols: 3, rows: 1))
        let entry = try #require(laid.doc(for: moved)["cards"]?.arrayValue?.first)
        #expect(entry["col"] == .integer(3))
        #expect(entry["row"] == .integer(1))
        #expect(entry["plate"] == .string("#123456"))
        #expect(entry["params"]?["floor_db"] == .decimal(-60.5))
        #expect(laid.doc(for: moved)["name"] == .string("S"))
    }

    @Test func aNewCardHoldsOnlyItsCells() throws {
        let laid = try LaidOutScene(Self.scene(#"{"cards": []}"#), defaultGrid: Self.defaults)
        let added = try laid.layout.adding(
            kind: "waveform", size: CellSize(cols: 17, rows: 10), centredOn: Cell(col: 20, row: 10))
        let entry = try #require(laid.doc(for: added)["cards"]?.arrayValue?.first)
        #expect(
            entry
                == .object([
                    "card": .string("waveform"), "col": .integer(12), "row": .integer(5),
                    "colspan": .integer(17), "rowspan": .integer(10),
                ]))
    }

    @Test func aGroupIsWrittenToEachMember() throws {
        let laid = try LaidOutScene(
            Self.scene(
                #"{"cards": [{"card": "a", "col": 0, "row": 0, "colspan": 4, "rowspan": 4},"#
                    + #"{"card": "b", "col": 4, "row": 0, "colspan": 4, "rowspan": 4}]}"#),
            defaultGrid: Self.defaults)
        let grouped = try laid.layout.grouping(Set(laid.layout.cards.map(\.id)))
        let entries = try #require(laid.doc(for: grouped)["cards"]?.arrayValue)
        #expect(entries.map { $0["group"] } == [.string("group-1"), .string("group-1")])
        let ungrouped = grouped.ungrouping(Set(grouped.cards.map(\.id)))
        #expect(
            laid.doc(for: ungrouped)["cards"]?.arrayValue?.allSatisfy { $0["group"] == nil } == true
        )
    }

    @Test func aCardWithNoName() throws {
        #expect(throws: LayoutRefusal.unreadableCard) {
            try LaidOutScene(Self.scene(#"{"cards": [{"col": 0}]}"#), defaultGrid: Self.defaults)
        }
    }
}
