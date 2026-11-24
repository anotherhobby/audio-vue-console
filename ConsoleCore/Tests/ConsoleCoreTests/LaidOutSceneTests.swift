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

    /// `scene-layout`, "An unset span covers the grid" and "A scene is laid out on the panel's
    /// grid".
    @Test func anUnsetSpanCoversThePanelsGrid() throws {
        let wide = CellSize(cols: 96, rows: 36)
        let laid = try LaidOutScene(Self.scene(#"{"cards": [{"card": "logo"}]}"#), panel: wide)
        #expect(laid.layout.grid == wide)
        #expect(laid.layout.cards.first?.cells == CellRect(col: 0, row: 0, cols: 96, rows: 36))
    }

    /// `scene-layout`, "A scene too wide for the panel is laid out on its reach".
    @Test func aSceneTooWideIsLaidOutOnItsReach() throws {
        let laid = try LaidOutScene(
            Self.scene(#"{"cards": [{"card": "meter", "col": 80, "colspan": 16, "rowspan": 8}]}"#),
            panel: Self.defaults)
        #expect(laid.layout.grid == CellSize(cols: 96, rows: 36))
        #expect(laid.isTooWide(laid.content))
        let card = try #require(laid.layout.cards.first)
        let moved = try laid.layout.moving([card.id], by: CellOffset(cols: -32, rows: 0))
        #expect(!laid.isTooWide(laid.content.with(layout: moved)))
        #expect(moved.grid.cols == 96)
    }

    /// `scene-saving`, "An unset span is kept until its card is resized".
    @Test func anUnsetSpanIsKeptUntilItsCardIsResized() throws {
        let laid = try LaidOutScene(
            Self.scene(#"{"name": "S", "cards": [{"card": "rta_bars"}]}"#), panel: Self.defaults)
        let untouched = try #require(laid.doc(for: laid.content)["cards"]?.arrayValue?.first)
        #expect(untouched["colspan"] == nil && untouched["rowspan"] == nil)
        let half = try SceneLayout(
            grid: Self.defaults,
            cards: laid.layout.cards.map {
                LayoutCard(
                    id: $0.id, kind: $0.kind,
                    cells: CellRect(col: 0, row: 0, cols: 32, rows: 36))
            })
        let resized = try #require(laid.doc(for: half)["cards"]?.arrayValue?.first)
        #expect(resized["colspan"] == .integer(32) && resized["rowspan"] == nil)
    }

    @Test func aSceneThatFitsIsOnThePanelsGrid() throws {
        let laid = try LaidOutScene(
            Self.scene(#"{"cards": [{"card": "meter", "col": 4, "colspan": 8}]}"#),
            panel: Self.defaults)
        #expect(laid.layout.grid == Self.defaults)
        #expect(laid.layout.cards.first?.cells == CellRect(col: 4, row: 0, cols: 8, rows: 36))
    }

    @Test func paramsAndPlatePassThroughAMove() throws {
        let laid = try LaidOutScene(
            Self.scene(
                #"{"name": "S", "cards": [{"card": "meter", "col": 0, "row": 0, "colspan": 8, "#
                    + ##""rowspan": 6, "plate": "#123456", "params": {"floor_db": -60.5}}]}"##),
            panel: Self.defaults)
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
        let laid = try LaidOutScene(Self.scene(#"{"cards": []}"#), panel: Self.defaults)
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
            panel: Self.defaults)
        let grouped = try laid.layout.grouping(Set(laid.layout.cards.map(\.id)))
        let entries = try #require(laid.doc(for: grouped)["cards"]?.arrayValue)
        #expect(entries.map { $0["group"] } == [.string("group-1"), .string("group-1")])
        let ungrouped = grouped.ungrouping(Set(grouped.cards.map(\.id)))
        #expect(
            laid.doc(for: ungrouped)["cards"]?.arrayValue?.allSatisfy { $0["group"] == nil } == true
        )
    }

    // MARK: Settings (`card-settings`, design D1)

    private static func rta() throws -> LaidOutScene {
        let file = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "Fixtures/rta-scene.json")
        let doc = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: file))
        let document = SceneDocument(id: "rta", name: "RTA", builtIn: false, fixed: false, doc: doc)
        return try LaidOutScene(document, panel: defaults)
    }

    @Test func aCardReadsItsParamsAsSettings() throws {
        let card = try #require(Self.rta().layout.cards.first)
        #expect(card.kind == "rta_bars")
        #expect(card.settings.count == 9)
        #expect(card.settings["release"] == .string("fall"))
        #expect(card.settings["floor_db"] == .integer(-80))
        #expect(card.settings["grid_major_color"] == .string("#2a3550"))
    }

    @Test func anUnchangedLayoutWritesTheDocumentAsRead() throws {
        let laid = try Self.rta()
        #expect(laid.doc(for: laid.layout) == laid.document.doc)
    }

    // MARK: Content (`scene-settings`, design D1)

    @Test func theRTAsDocumentRoundTripsThroughItsContent() throws {
        let laid = try Self.rta()
        #expect(laid.content.blocks["cards"] == nil && laid.content.blocks["name"] == nil)
        #expect(laid.doc(for: laid.content) == laid.document.doc)
    }

    @Test func aChangedBlockIsWrittenAndTheOthersKeptAsRead() throws {
        let laid = try Self.rta()
        var content = laid.content
        content.blocks["backdrop"] = JSONValue.object(["color": .string("#102030")])
        let doc = laid.doc(for: content)
        #expect(doc["backdrop"] == .object(["color": .string("#102030")]))
        #expect(doc["grid"] == laid.document.doc["grid"])
        #expect(doc["cards"] == laid.document.doc["cards"])
    }

    /// `scene-saving`, "A saved scene declares no grid size": a scene stored with one opens as
    /// stored, not unsaved, and keeps it until it is repaired (`scene-repair`).
    @Test func aStoredGridSizeIsKeptUntilTheSceneIsRepaired() throws {
        let doc =
            #"{"name": "S", "grid": {"cols": 96, "rows": 36, "gap": 8}, "cards": ["#
            + #"{"card": "meter", "colspan": 8}]}"#
        let laid = try LaidOutScene(Self.scene(doc), panel: Self.defaults)
        #expect(!Draft(laid).isUnsaved)
        #expect(laid.doc(for: laid.content)["grid"] == laid.document.doc["grid"])
    }

    /// `scene-saving`, "A saved scene declares no grid size".
    @Test func noGridSizeIsWritten() throws {
        let laid = try LaidOutScene(
            Self.scene(#"{"name": "S", "cards": [{"card": "meter", "colspan": 8}]}"#),
            panel: Self.defaults)
        #expect(laid.doc(for: laid.content)["grid"] == nil)
        var gapped = laid.content
        gapped.blocks["grid"] = JSONValue.object(["gap": .decimal(0.5)])
        #expect(laid.doc(for: gapped)["grid"] == .object(["gap": .decimal(0.5)]))
    }

    @Test func aChangedSettingIsWrittenBesideThePlateAndAlternate() throws {
        let laid = try LaidOutScene(
            Self.scene(
                ##"{"cards": [{"card": "meter", "colspan": 8, "rowspan": 6, "plate": "#123456", "##
                    + #""alternate": {"card": "logo"}, "params": {"floor_db": -60}}]}"#),
            panel: Self.defaults)
        let id = try #require(laid.layout.cards.first?.id)
        let changed = laid.layout.setting("floor_db", to: .integer(-80), on: [id])
        let entry = try #require(laid.doc(for: changed)["cards"]?.arrayValue?.first)
        #expect(entry["params"] == .object(["floor_db": .integer(-80)]))
        #expect(entry["plate"] == .string("#123456"))
        #expect(entry["alternate"] == .object(["card": .string("logo")]))
    }

    @Test func emptyingACardsSettingsDropsItsParams() throws {
        let laid = try LaidOutScene(
            Self.scene(#"{"cards": [{"card": "meter", "params": {"floor_db": -60}}]}"#),
            panel: Self.defaults)
        let id = try #require(laid.layout.cards.first?.id)
        let emptied = laid.layout.unsetting("floor_db", on: [id])
        let entry = try #require(laid.doc(for: emptied)["cards"]?.arrayValue?.first)
        #expect(entry["params"] == nil)
    }

    @Test func aCopyKeepsEachCardsSettings() throws {
        let laid = try Self.rta()
        let document = SceneDocument(
            id: "copy", name: "Copy", builtIn: false, fixed: false, doc: laid.document.doc)
        let copied = laid.copy(laid.content, as: document)
        #expect(copied.layout.cards.first?.settings == laid.layout.cards.first?.settings)
        #expect(copied.doc(for: copied.layout)["cards"] == laid.document.doc["cards"])
    }

    /// An empty scene, and its content holding one pasted card with an entry from another scene.
    private struct Pasted {
        let laid: LaidOutScene
        let content: SceneContent
        let id: UUID
    }

    private static func pasted() throws -> Pasted {
        let laid = try LaidOutScene(Self.scene(#"{"cards": []}"#), panel: Self.defaults)
        let card = LayoutCard(
            kind: "meter", cells: CellRect(col: 2, row: 3, cols: 8, rows: 6),
            settings: ["floor_db": .integer(-60)])
        let entry: JSONValue = .object([
            "card": .string("meter"), "col": .integer(40), "row": .integer(20),
            "plate": .string("#123456"), "params": .object(["floor_db": .integer(-60)]),
        ])
        let layout = try SceneLayout(grid: laid.layout.grid, cards: [card])
        let content = SceneContent(layout: layout, entries: [card.id: entry])
        return Pasted(laid: laid, content: content, id: card.id)
    }

    /// `card-clipboard` design D2: a pasted card is written with its source entry's fields and
    /// its own cells.
    @Test func aPastedCardKeepsItsEntryFields() throws {
        let pasted = try Self.pasted()
        let entry = try #require(pasted.laid.doc(for: pasted.content)["cards"]?.arrayValue?.first)
        #expect(entry["plate"] == .string("#123456"))
        #expect(entry["col"] == .integer(2) && entry["row"] == .integer(3))
        #expect(entry["params"]?["floor_db"] == .integer(-60))
    }

    @Test func aPastedCardKeepsItsEntryWhenMoved() throws {
        let pasted = try Self.pasted()
        let moved = pasted.content.with(
            layout: try pasted.content.layout.moving([pasted.id], by: CellOffset(cols: 5, rows: 0)))
        let entry = try #require(pasted.laid.doc(for: moved)["cards"]?.arrayValue?.first)
        #expect(entry["plate"] == .string("#123456") && entry["col"] == .integer(7))
    }

    @Test func aCopyKeepsAPastedCardsEntry() throws {
        let pasted = try Self.pasted()
        let document = SceneDocument(
            id: "copy", name: "Copy", builtIn: false, fixed: false, doc: pasted.laid.document.doc)
        let copied = pasted.laid.copy(pasted.content, as: document)
        let entry = try #require(copied.doc(for: copied.layout)["cards"]?.arrayValue?.first)
        #expect(entry["plate"] == .string("#123456"))
    }

    @Test func aRemovedPastedCardDropsItsEntry() throws {
        let pasted = try Self.pasted()
        #expect(pasted.content.removing([pasted.id]).entries.isEmpty)
    }

    @Test func paramsThatAreNotAnObject() throws {
        #expect(throws: LayoutRefusal.unreadableCard) {
            try LaidOutScene(
                Self.scene(#"{"cards": [{"card": "meter", "params": [1]}]}"#),
                panel: Self.defaults)
        }
    }

    @Test func aCardWithNoName() throws {
        #expect(throws: LayoutRefusal.unreadableCard) {
            try LaidOutScene(Self.scene(#"{"cards": [{"col": 0}]}"#), panel: Self.defaults)
        }
    }
}
