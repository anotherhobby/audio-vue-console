import Foundation
import Testing

@testable import ConsoleCore

/// `scene-rendering`: the library's tiles, each a card's plate alone at its minimum in the open
/// scene's settings (`library-render` design D1, D3 and D6).
@MainActor
struct LibraryTilesTests {
    private static let cards = [
        SchemaFacts.Card(name: "meter", minimum: CellSize(cols: 8, rows: 6), placeable: true),
        SchemaFacts.Card(name: "tiny", minimum: CellSize(cols: 4, rows: 4), placeable: true),
        SchemaFacts.Card(name: "waveform", minimum: CellSize(cols: 10, rows: 6), placeable: true),
    ]

    /// A 64 × 36 scene named `name` in `palette`, holding one meter away from the corner.
    private static func scene(_ name: String, palette: String = "a") throws -> LaidOutScene {
        let meter: JSONValue = .object([
            "card": .string("meter"), "col": .integer(20), "row": .integer(10),
            "colspan": .integer(8), "rowspan": .integer(8), "group": .string("g"),
        ])
        let doc: JSONValue = .object([
            "name": .string(name), "palette": .string(palette),
            "grid": .object(["cols": .integer(64), "rows": .integer(36)]),
            "cards": .array([meter]),
        ])
        let document = SceneDocument(id: name, name: name, builtIn: false, fixed: false, doc: doc)
        return try LaidOutScene(document, defaultGrid: CellSize(cols: 64, rows: 36))
    }

    private static func renders(_ fixture: RenderingFixture) -> [JSONValue] {
        fixture.launcher.requests.filter { $0["op"] == .string("render") }
    }

    /// The card a tile request asks for.
    private nonisolated static func card(of request: JSONValue) -> String? {
        request["scene"]?["cards"]?.arrayValue?.first?["card"]?.stringValue
    }

    private func draw(
        _ tiles: LibraryTiles, _ scene: LaidOutScene, in fixture: RenderingFixture,
        cards: [SchemaFacts.Card] = cards, drift: CardDrift? = nil
    ) async {
        await tiles.draw(
            for: scene, cards: cards, drift: drift, context: RenderRequestTests.context,
            through: fixture.queue)
    }

    @Test func aTileIsOneCardAtTheCornerInTheScenesSettings() async throws {
        let fixture = try RenderingFixture()
        let tiles = LibraryTiles()
        await draw(tiles, try Self.scene("A"), in: fixture)

        let request = try #require(Self.renders(fixture).first { Self.card(of: $0) == "meter" })
        let entry: JSONValue = .object([
            "card": .string("meter"), "col": .integer(0), "row": .integer(0),
            "colspan": .integer(8), "rowspan": .integer(6),
        ])
        #expect(request["scene"]?["cards"] == .array([entry]))
        #expect(request["scene"]?["palette"] == .string("a"))
        #expect(request["scene"]?["name"] == .string("A"))
        #expect(request["plates"] == .array([.integer(0)]))
        #expect(request["backdrop"] == .bool(false))
        #expect(Set(tiles.tiles.keys) == ["meter", "tiny", "waveform"])
    }

    @Test func aSceneWithTheSameSettingsSendsNothing() async throws {
        let fixture = try RenderingFixture()
        let tiles = LibraryTiles()
        await draw(tiles, try Self.scene("A"), in: fixture)
        await draw(tiles, try Self.scene("B"), in: fixture)
        #expect(Self.renders(fixture).count == Self.cards.count)
        #expect(tiles.tiles.count == Self.cards.count)
    }

    @Test func aSceneWithOtherSettingsEmptiesTheTilesAndDrawsAgain() async throws {
        // Palette b's tiles are refused, so the tiles left show what was emptied.
        let fixture = try RenderingFixture { request in
            request["scene"]?["palette"] == .string("b")
                ? .answer(#"{"ok": false, "refused": "no"}"#) : FakeRender.reply(to: request)
        }
        let tiles = LibraryTiles()
        await draw(tiles, try Self.scene("A"), in: fixture)
        #expect(tiles.tiles.count == Self.cards.count)
        await draw(tiles, try Self.scene("C", palette: "b"), in: fixture)
        #expect(Self.renders(fixture).count == 2 * Self.cards.count)
        #expect(tiles.tiles.isEmpty)
    }

    @Test func aDrawForOtherSettingsDropsTheFirstsAnswers() async throws {
        // The first request is held; each answer names its palette in `unfit`.
        let first = AtomicFlag()
        let fixture = try RenderingFixture { request in
            guard request["op"] == .string("render") else { return FakeRender.reply(to: request) }
            let palette = request["scene"]?["palette"]?.stringValue ?? ""
            let header =
                #"{"ok": true, "layers": [{"kind": "plate", "placements": [0], "#
                + #""rect": [0, 0, 1, 1], "unfit": ["\#(palette)"], "bytes": 4}]}"#
            let pixel = Data([10, 20, 30, 255])
            return first.setOnce()
                ? .heldWith(header, payload: pixel) : .answer(header, payload: pixel)
        }
        let tiles = LibraryTiles()
        let older = Task { await draw(tiles, try Self.scene("A"), in: fixture) }
        for _ in 0..<200 where fixture.queue.waiting < Self.cards.count - 1 {
            try await Task.sleep(for: .milliseconds(5))
        }
        // The newer draw leaves out the meter, whose older answer is held, and adds a logo: its
        // two tiles replace the older ones waiting, and the logo waits behind them.
        let logo = SchemaFacts.Card(
            name: "logo", minimum: CellSize(cols: 6, rows: 4), placeable: true)
        let newer = Task {
            await draw(
                tiles, try Self.scene("C", palette: "b"), in: fixture,
                cards: Self.cards.dropFirst() + [logo])
        }
        for _ in 0..<200 where fixture.queue.waiting < Self.cards.count {
            try await Task.sleep(for: .milliseconds(5))
        }
        fixture.launcher.releaseHeld()
        try await older.value
        try await newer.value

        #expect(Set(tiles.tiles.keys) == ["logo", "tiny", "waveform"])
        #expect(tiles.tiles.values.allSatisfy { $0.unfit == ["b"] })
    }

    @Test func aCardOffTheGridSendsNoRequest() async throws {
        let fixture = try RenderingFixture()
        let tiles = LibraryTiles()
        let wide = SchemaFacts.Card(
            name: "wide", minimum: CellSize(cols: 80, rows: 6), placeable: true)
        await draw(tiles, try Self.scene("A"), in: fixture, cards: Self.cards + [wide])
        #expect(!Self.renders(fixture).contains { Self.card(of: $0) == "wide" })
        #expect(Set(tiles.tiles.keys) == ["meter", "tiny", "waveform"])
    }

    @Test func aRefusedCardHasNoTile() async throws {
        let fixture = try RenderingFixture { request in
            Self.card(of: request) == "waveform"
                ? .answer(#"{"ok": false, "refused": "no"}"#) : FakeRender.reply(to: request)
        }
        let tiles = LibraryTiles()
        await draw(tiles, try Self.scene("A"), in: fixture)
        #expect(Set(tiles.tiles.keys) == ["meter", "tiny"])
    }

    @Test func aDriftedCardIsSkipped() async throws {
        let cards = [
            "meter": "src/cards/meter", "tiny": "src/cards/tiny",
            "waveform": "src/cards/waveform",
        ]
        let drift = CardDrift.between(
            bundled: CardManifest(
                digest: "a",
                entries: [
                    "src/cards/meter": "1", "src/cards/tiny": "1", "src/cards/waveform": "1",
                ],
                cards: cards),
            host: CardManifest(
                digest: "b",
                entries: [
                    "src/cards/meter": "1", "src/cards/tiny": "1", "src/cards/waveform": "2",
                ],
                cards: cards),
            source: .panel)
        let fixture = try RenderingFixture()
        let tiles = LibraryTiles()
        await draw(tiles, try Self.scene("A"), in: fixture, drift: drift)
        #expect(!Self.renders(fixture).contains { Self.card(of: $0) == "waveform" })
        #expect(Set(tiles.tiles.keys) == ["meter", "tiny"])

        // The code made the same again, the waveform is drawn; differing again, it is dropped.
        await draw(tiles, try Self.scene("A"), in: fixture)
        #expect(Set(tiles.tiles.keys) == ["meter", "tiny", "waveform"])
        await draw(tiles, try Self.scene("A"), in: fixture, drift: drift)
        #expect(Set(tiles.tiles.keys) == ["meter", "tiny"])
        #expect(Self.renders(fixture).count == Self.cards.count)
    }

    @Test func aCardTooSmallKeepsItsUnfitName() async throws {
        let fixture = try RenderingFixture()
        let tiles = LibraryTiles()
        await draw(tiles, try Self.scene("A"), in: fixture)
        #expect(tiles.tiles["tiny"]?.unfit == ["tiny"])
        #expect(tiles.tiles["meter"]?.unfit == [])
    }

    @Test func theBackdropArrivingRestacksEveryTileWithNoRequest() async throws {
        let fixture = try RenderingFixture()
        await fixture.rendering.attach(fixture.queue)
        let backdrop = try #require(fixture.rendering.backdrop)
        let tiles = LibraryTiles()
        await draw(tiles, try Self.scene("A"), in: fixture)
        let meter = try #require(tiles.tiles["meter"])
        #expect(meter.image === meter.layer.image)

        let sent = fixture.launcher.requests.count
        tiles.show(backdrop: backdrop)
        let stacked = try #require(tiles.tiles["meter"])
        #expect(stacked.image !== stacked.layer.image)
        #expect(fixture.launcher.requests.count == sent)
    }

    @Test func aTileArrivingWithTheBackdropHeldIsStackedAtOnce() async throws {
        let fixture = try RenderingFixture()
        await fixture.rendering.attach(fixture.queue)
        let backdrop = try #require(fixture.rendering.backdrop)
        let tiles = LibraryTiles()
        let scene = try Self.scene("A")
        await draw(tiles, scene, in: fixture, cards: [Self.cards[0]])
        tiles.show(backdrop: backdrop)
        await draw(tiles, scene, in: fixture)
        let waveform = try #require(tiles.tiles["waveform"])
        #expect(waveform.image !== waveform.layer.image)
    }

    @Test func aChangeOfSettingsClearsTheBackdrop() async throws {
        let fixture = try RenderingFixture()
        await fixture.rendering.attach(fixture.queue)
        let tiles = LibraryTiles()
        await draw(tiles, try Self.scene("A"), in: fixture)
        tiles.show(backdrop: try #require(fixture.rendering.backdrop))
        await draw(tiles, try Self.scene("C", palette: "b"), in: fixture)
        #expect(tiles.backdrop == nil)
    }
}
