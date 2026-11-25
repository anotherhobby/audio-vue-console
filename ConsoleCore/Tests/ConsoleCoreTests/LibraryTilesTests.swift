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

    /// A 64 × 36 scene named `name` in `colours`, holding one meter away from the corner.
    private static func scene(
        _ name: String, colours: String = "a", display: JSONValue? = nil
    ) throws -> LaidOutScene {
        let meter: JSONValue = .object([
            "card": .string("meter"), "col": .integer(20), "row": .integer(10),
            "colspan": .integer(8), "rowspan": .integer(8), "group": .string("g"),
        ])
        var fields: [String: JSONValue] = [
            "name": .string(name), "colors": .string(colours), "cards": .array([meter]),
        ]
        fields["display"] = display
        let doc = JSONValue.object(fields)
        let document = SceneDocument(id: name, name: name, builtIn: false, fixed: false, doc: doc)
        return try LaidOutScene(document, panel: CellSize(cols: 64, rows: 36))
    }

    /// The renders one draw of the three cards makes: one each, at the size its `minimum` answer
    /// gives (`scene-rendering`, "A library tile is drawn at its card's whole minimum").
    private static let rendersPerDraw = cards.count

    private static func renders(_ fixture: RenderingFixture) -> [JSONValue] {
        fixture.launcher.requests.filter { $0["op"] == .string("render") }
    }

    /// The card a tile request asks for.
    private nonisolated static func card(of request: JSONValue) -> String? {
        request["scene"]?["cards"]?.arrayValue?.first?["card"]?.stringValue
    }

    private static func source(
        _ fixture: RenderingFixture, cards: [SchemaFacts.Card] = cards, drift: CardDrift? = nil
    ) -> LibraryTiles.Source {
        LibraryTiles.Source(
            cards: cards, drift: drift, context: RenderRequestTests.context, queue: fixture.queue)
    }

    /// `scene-rendering`, "Scenes and tiles are drawn ahead": a scene's tiles and backdrop drawn
    /// ahead are shown with no request once it is opened, and so is a scene opened again.
    @Test func tilesDrawnAheadAreShownWithNoRequest() async throws {
        let fixture = try RenderingFixture()
        let tiles = LibraryTiles()
        let (first, second) = (try Self.scene("A"), try Self.scene("B", colours: "b"))
        await tiles.prepare(for: Draft(first), from: Self.source(fixture))
        await tiles.prepare(for: Draft(second), from: Self.source(fixture))
        #expect(tiles.tiles.isEmpty && tiles.backdrop == nil)
        let sent = Self.renders(fixture).count
        #expect(sent == 2 * (Self.rendersPerDraw + 1))

        await draw(tiles, first, in: fixture)
        #expect(tiles.tiles.count == Self.cards.count && tiles.backdrop != nil)
        await draw(tiles, second, in: fixture)
        await draw(tiles, first, in: fixture)
        #expect(tiles.tiles.count == Self.cards.count)
        #expect(Self.renders(fixture).count == sent)
    }

    @Test func onlyTheLastScenesTilesAreKept() async throws {
        let fixture = try RenderingFixture()
        let tiles = LibraryTiles()
        let first = try Self.scene("first", colours: "first")
        await tiles.prepare(for: Draft(first), from: Self.source(fixture))
        for index in 0..<LibraryTiles.kept {
            let scene = try Self.scene("s\(index)", colours: "c\(index)")
            await tiles.prepare(for: Draft(scene), from: Self.source(fixture))
        }
        let sent = Self.renders(fixture).count
        await draw(tiles, first, in: fixture)
        #expect(Self.renders(fixture).count == sent + Self.rendersPerDraw)
    }

    private func draw(
        _ tiles: LibraryTiles, _ scene: LaidOutScene, in fixture: RenderingFixture,
        cards: [SchemaFacts.Card] = cards, drift: CardDrift? = nil
    ) async {
        await draw(tiles, Draft(scene), in: fixture, cards: cards, drift: drift)
    }

    private func draw(
        _ tiles: LibraryTiles, _ draft: Draft, in fixture: RenderingFixture,
        cards: [SchemaFacts.Card] = cards, drift: CardDrift? = nil
    ) async {
        await tiles.draw(for: draft, from: Self.source(fixture, cards: cards, drift: drift))
    }

    // MARK: The scene as edited (`scene-settings`, design D6)

    @Test func editedColoursDrawTheTilesAgainInThem() async throws {
        let fixture = try RenderingFixture()
        let tiles = LibraryTiles()
        var draft = Draft(try Self.scene("A"))
        await draw(tiles, draft, in: fixture)
        #expect(Self.renders(fixture).count == Self.rendersPerDraw)
        draft.content.blocks["colors"] = .string("b")
        await draw(tiles, draft, in: fixture)
        #expect(Self.renders(fixture).count == 2 * Self.rendersPerDraw)
        #expect(Self.renders(fixture).last?["scene"]?["colors"] == .string("b"))
    }

    @Test func aLayoutEditDrawsNoTile() async throws {
        let fixture = try RenderingFixture()
        let tiles = LibraryTiles()
        var draft = Draft(try Self.scene("A"))
        await draw(tiles, draft, in: fixture)
        let meter = try #require(draft.layout.cards.first)
        draft.content.layout = try draft.layout.moving([meter.id], by: CellOffset(cols: 4, rows: 0))
        await draw(tiles, draft, in: fixture)
        #expect(Self.renders(fixture).count == Self.rendersPerDraw)
    }

    @Test func aTileIsOneCardAtTheCornerInTheScenesSettings() async throws {
        let fixture = try RenderingFixture()
        let tiles = LibraryTiles()
        await draw(tiles, try Self.scene("A"), in: fixture)

        // The tile is the last request for the meter: the search's probes come before it.
        let request = try #require(Self.renders(fixture).last { Self.card(of: $0) == "meter" })
        let entry: JSONValue = .object([
            "card": .string("meter"), "col": .integer(0), "row": .integer(0),
            "colspan": .integer(8), "rowspan": .integer(6),
        ])
        #expect(request["scene"]?["cards"] == .array([entry]))
        #expect(request["scene"]?["colors"] == .string("a"))
        #expect(request["scene"]?["name"] == .string("A"))
        #expect(request["plates"] == .array([.integer(0)]))
        #expect(request["backdrop"] == .bool(false))
        #expect(Set(tiles.tiles.keys) == ["meter", "tiny", "waveform"])
    }

    /// `track-native-logo` design D7: the display block draws nothing, so the tiles are kept.
    @Test func aDisplayChangeKeepsTheTiles() async throws {
        let fixture = try RenderingFixture()
        let tiles = LibraryTiles()
        await draw(tiles, try Self.scene("A"), in: fixture)
        let timeout = JSONValue.object(["saver_after_min": .integer(2)])
        await draw(tiles, try Self.scene("A", display: timeout), in: fixture)
        #expect(Self.renders(fixture).count == Self.rendersPerDraw)
        #expect(tiles.tiles.count == Self.cards.count)
    }

    @Test func aSceneWithTheSameSettingsSendsNothing() async throws {
        let fixture = try RenderingFixture()
        let tiles = LibraryTiles()
        await draw(tiles, try Self.scene("A"), in: fixture)
        await draw(tiles, try Self.scene("B"), in: fixture)
        #expect(Self.renders(fixture).count == Self.rendersPerDraw)
        #expect(tiles.tiles.count == Self.cards.count)
    }

    @Test func aSceneWithOtherSettingsEmptiesTheTilesAndDrawsAgain() async throws {
        // Colours b's tiles are refused, so the tiles left show what was emptied.
        let fixture = try RenderingFixture { request in
            request["scene"]?["colors"] == .string("b")
                ? .answer(#"{"ok": false, "refused": "no"}"#) : FakeRender.reply(to: request)
        }
        let tiles = LibraryTiles()
        await draw(tiles, try Self.scene("A"), in: fixture)
        #expect(tiles.tiles.count == Self.cards.count)
        await draw(tiles, try Self.scene("C", colours: "b"), in: fixture)
        // A refused probe ends the card's search: one render per card, none drawn.
        #expect(Self.renders(fixture).count == Self.rendersPerDraw + Self.cards.count)
        #expect(tiles.tiles.isEmpty)
    }

    @Test func aDrawForOtherSettingsDropsTheFirstsAnswers() async throws {
        // The first request is held; each answer names its colours in `unfit`.
        let first = AtomicFlag()
        let fixture = try RenderingFixture { request in
            guard request["op"] == .string("render") else { return FakeRender.reply(to: request) }
            let colours = request["scene"]?["colors"]?.stringValue ?? ""
            let header =
                #"{"ok": true, "layers": [{"kind": "plate", "placements": [0], "#
                + #""rect": [0, 0, 1, 1], "unfit": ["\#(colours)"], "bytes": 4}]}"#
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
                tiles, try Self.scene("C", colours: "b"), in: fixture,
                cards: Self.cards.dropFirst() + [logo])
        }
        for _ in 0..<200 where fixture.queue.waiting < Self.cards.count {
            try await Task.sleep(for: .milliseconds(5))
        }
        try await fixture.launcher.untilHolding()
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
        #expect(Self.renders(fixture).count == Self.rendersPerDraw)
    }

    @Test func aCardTooSmallKeepsItsUnfitName() async throws {
        let fixture = try RenderingFixture()
        let tiles = LibraryTiles()
        await draw(tiles, try Self.scene("A"), in: fixture)
        #expect(tiles.tiles["tiny"]?.unfit == ["tiny"])
        #expect(tiles.tiles["meter"]?.unfit == [])
    }

    /// `scene-gallery`, "A new scene is the app's alone until it holds a card": its backdrop is
    /// asked for once, around a card of the library's, naming no plate.
    @Test func aSceneWithNoCardsHasItsBackdropAskedForOnce() async throws {
        let fixture = try RenderingFixture()
        let drafts = SceneDrafts()
        let new = try drafts.new(on: CellSize(cols: 64, rows: 36), among: [])
        let draft = try #require(drafts.draft(new.id))
        let tiles = LibraryTiles()
        await draw(tiles, draft, in: fixture)
        await draw(tiles, draft, in: fixture)
        let asked = Self.renders(fixture).filter { $0["backdrop"] == .bool(true) }
        #expect(asked.count == 1)
        #expect(asked.first?["plates"] == .array([]))
        #expect(asked.first?["scene"]?["cards"]?.arrayValue?.count == 1)
        #expect(tiles.backdrop != nil)
        let meter = try #require(tiles.tiles["meter"])
        #expect(meter.image !== meter.layer.image)
    }

    @Test func aSceneWithCardsLeavesItsBackdropToTheCanvas() async throws {
        let fixture = try RenderingFixture()
        let tiles = LibraryTiles()
        await draw(tiles, try Self.scene("A"), in: fixture)
        #expect(Self.renders(fixture).allSatisfy { $0["backdrop"] == .bool(false) })
        #expect(tiles.backdrop == nil)
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
        await draw(tiles, try Self.scene("C", colours: "b"), in: fixture)
        #expect(tiles.backdrop == nil)
    }
}
