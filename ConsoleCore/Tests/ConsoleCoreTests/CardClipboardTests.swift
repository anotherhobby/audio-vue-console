import Foundation
import Testing

@testable import ConsoleCore

/// `card-clipboard`, "Copy takes the selected cards as they are" (design D1): copied cards travel
/// as their scene's entries and come back as new cards.
struct CardClipboardTests {
    private static let panel = CellSize(cols: 64, rows: 36)

    /// A scene of a meter, with a plate and a setting, grouped with a readout beside it, and a
    /// waveform on its own.
    private static func scene() throws -> LaidOutScene {
        let doc = ##"""
            {"cards": [
              {"card": "meter", "col": 0, "row": 0, "colspan": 8, "rowspan": 6, "group": "g",
               "plate": "#123456", "params": {"floor_db": -60}},
              {"card": "readout", "col": 8, "row": 0, "colspan": 8, "rowspan": 6, "group": "g"},
              {"card": "waveform", "col": 20, "row": 10, "colspan": 17, "rowspan": 10}
            ]}
            """##
        return try LaidOutScene(
            SceneDocument(
                id: "s", name: "S", builtIn: false, fixed: false,
                doc: try JSONDecoder().decode(JSONValue.self, from: Data(doc.utf8))),
            panel: panel)
    }

    @Test func aGroupMemberCopiesItsGroup() throws {
        let laid = try Self.scene()
        let meter = try #require(laid.layout.cards.first)
        let copied = try #require(CopiedCards([meter.id], of: laid.content, in: laid))
        #expect(copied.entries.map { $0["card"] } == [.string("meter"), .string("readout")])
    }

    @Test func aRoundTripKeepsEverythingButTheIDs() throws {
        let laid = try Self.scene()
        let meter = try #require(laid.layout.cards.first)
        let copied = try #require(CopiedCards([meter.id], of: laid.content, in: laid))
        let read = try #require(CopiedCards(data: copied.data))
        #expect(read == copied)
        let pasting = try read.cards(on: Self.panel)
        let pasted = try #require(pasting.cards.first)
        #expect(pasted.kind == "meter" && pasted.cells == meter.cells && pasted.group == "g")
        #expect(pasted.settings == ["floor_db": .integer(-60)])
        #expect(pasted.id != meter.id)
        #expect(pasting.entries[pasted.id]?["plate"] == .string("#123456"))
    }

    @Test func aParkedCardIsCopied() throws {
        let laid = try Self.scene()
        let waveform = try #require(laid.layout.cards.last)
        let pane = CellRect(col: 0, row: 0, cols: 64, rows: 72)
        let parked = try laid.content.dragging(
            [waveform.id], by: CellOffset(cols: 0, rows: 30), within: pane)
        let copied = try #require(CopiedCards([waveform.id], of: parked, in: laid))
        #expect(copied.entries.first?["card"] == .string("waveform"))
    }

    @Test func eachReadHasNewIDs() throws {
        let laid = try Self.scene()
        let meter = try #require(laid.layout.cards.first)
        let copied = try #require(CopiedCards([meter.id], of: laid.content, in: laid))
        let (first, second) = (try copied.cards(on: Self.panel), try copied.cards(on: Self.panel))
        #expect(Set(first.cards.map(\.id)).isDisjoint(with: second.cards.map(\.id)))
        #expect(first.cards.map(\.cells) == second.cards.map(\.cells))
    }

    @Test func anUnreadableEntryIsRefused() {
        #expect(throws: LayoutRefusal.unreadableCard) {
            try CopiedCards(entries: [.object(["col": .integer(0)])]).cards(on: Self.panel)
        }
    }

    @Test func nothingSelectedCopiesNothing() throws {
        let laid = try Self.scene()
        #expect(CopiedCards([], of: laid.content, in: laid) == nil)
    }

    @Test func dataThatIsNotCardsReadsAsNothing() {
        #expect(CopiedCards(data: Data("hello".utf8)) == nil)
        #expect(CopiedCards(data: Data("[]".utf8)) == nil)
    }
}
