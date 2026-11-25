import Foundation
import Testing

@testable import ConsoleCore

/// `library-setup`, "Changing a tile's setting redraws the tile": a set-up card's tile, one request
/// at its plain tile's size with the setup on its card (design D7).
@MainActor
struct LibraryTilesSetupTests {
    private static let meter = SchemaFacts.Card(
        name: "meter", minimum: CellSize(cols: 8, rows: 6), placeable: true)
    private static let bar: [String: JSONValue] = ["style": .string("bar")]

    /// A 64 × 36 scene in `colours` holding one meter.
    private static func draft(colours: String = "a") throws -> Draft {
        let doc: JSONValue = .object([
            "name": .string("A"), "colors": .string(colours),
            "cards": .array([.object(["card": .string("meter"), "colspan": .integer(8)])]),
        ])
        let document = SceneDocument(id: "A", name: "A", builtIn: false, fixed: false, doc: doc)
        return Draft(try LaidOutScene(document, panel: CellSize(cols: 64, rows: 36)))
    }

    private static func source(_ fixture: RenderingFixture, drift: CardDrift? = nil)
        -> LibraryTiles.Source
    {
        LibraryTiles.Source(
            cards: [meter], drift: drift, context: RenderRequestTests.context, queue: fixture.queue)
    }

    /// The renders sent whose one card carries settings.
    private static func setupRenders(_ fixture: RenderingFixture) -> [JSONValue] {
        fixture.launcher.requests.filter {
            $0["op"] == .string("render")
                && $0["scene"]?["cards"]?.arrayValue?.first?["params"] != nil
        }
    }

    /// The plain tiles of `draft`, drawn first, as the editor draws them before any setup.
    private static func tiles(_ draft: Draft, _ fixture: RenderingFixture) async -> LibraryTiles {
        let tiles = LibraryTiles()
        await tiles.draw(for: draft, from: source(fixture))
        return tiles
    }

    /// A fixture whose helper draws a set-up card unfit below `cols` columns, and any other whole.
    private static func fitting(from cols: Int) throws -> RenderingFixture {
        try RenderingFixture { request in
            let card = request["scene"]?["cards"]?.arrayValue?.first
            guard card?["params"] != nil else { return FakeRender.reply(to: request) }
            if request["op"] == .string("minimum") { return minimum(from: cols) }
            guard request["op"] == .string("render") else { return FakeRender.reply(to: request) }
            let wide = (card?["colspan"]?.intValue ?? 0) >= cols
            let unfit = wide ? "" : #""meter""#
            return .answer(
                #"{"ok": true, "layers": [{"kind": "plate", "placements": [0], "#
                    + #""rect": [0, 0, 1, 1], "unfit": [\#(unfit)], "bytes": 4}]}"#,
                payload: Data([10, 20, 30, 255]))
        }
    }

    /// A set-up meter's `minimum` answer: whole at its 8 × 6 minimum where it fits from 8 columns or
    /// fewer, at `cols` × 10 where it fits from up to the grid's 64, and nowhere beyond.
    private nonisolated static func minimum(from cols: Int) -> ScriptedReply {
        let sizes =
            cols <= minimumCols ? "[[8, 6]]" : cols <= gridCols ? "[[\(cols), 10]]" : "[]"
        return .answer(#"{"ok": true, "whole": \#(sizes), "readable": \#(sizes)}"#)
    }

    private nonisolated static let minimumCols = 8
    private nonisolated static let gridCols = 64

    /// "Setting the meter's style": a setup that fits at the minimum is drawn there, carrying it.
    @Test func aSetupThatFitsAtTheMinimumIsDrawnThere() async throws {
        let fixture = try Self.fitting(from: 0)
        let draft = try Self.draft()
        let tiles = await Self.tiles(draft, fixture)
        await tiles.drawSetup(
            Self.meter, settings: Self.bar, for: draft, from: Self.source(fixture))
        let card = try #require(
            Self.setupRenders(fixture).last?["scene"]?["cards"]?.arrayValue?.first)
        #expect(card["params"] == .object(Self.bar))
        #expect(tiles.setupTile("meter")?.size == Self.meter.minimum)
    }

    /// "A setup that needs more room": the first ladder size that fits, 12 × 10 from 8 × 6.
    @Test func aSetupThatNeedsRoomIsDrawnLarger() async throws {
        let fixture = try Self.fitting(from: 12)
        let draft = try Self.draft()
        let tiles = await Self.tiles(draft, fixture)
        await tiles.drawSetup(
            Self.meter, settings: Self.bar, for: draft, from: Self.source(fixture))
        let tile = try #require(tiles.setupTile("meter"))
        #expect(tile.size == CellSize(cols: 12, rows: 10))
        #expect(tile.unfit.isEmpty)
    }

    @Test func theSameSetupIsNotSearchedAgain() async throws {
        let fixture = try Self.fitting(from: 12)
        let draft = try Self.draft()
        let tiles = await Self.tiles(draft, fixture)
        await tiles.drawSetup(
            Self.meter, settings: Self.bar, for: draft, from: Self.source(fixture))
        let sent = Self.setupRenders(fixture).count
        await tiles.drawSetup(
            Self.meter, settings: Self.bar, for: draft, from: Self.source(fixture))
        #expect(Self.setupRenders(fixture).count == sent)
    }

    /// A setup that fits at no size on the grid is drawn at the minimum and says so.
    @Test func aSetupThatFitsNowhereIsDrawnAtTheMinimum() async throws {
        let fixture = try Self.fitting(from: 1000)
        let draft = try Self.draft()
        let tiles = await Self.tiles(draft, fixture)
        await tiles.drawSetup(
            Self.meter, settings: Self.bar, for: draft, from: Self.source(fixture))
        let tile = try #require(tiles.setupTile("meter"))
        #expect(tile.size == Self.meter.minimum && tile.unfit == ["meter"])
    }

    /// A fixture that holds the first set-up tile's render, not its `minimum`, until released.
    private static func holdingFirstSetup() throws -> RenderingFixture {
        let first = AtomicFlag()
        return try RenderingFixture { request in
            let isSetup = request["scene"]?["cards"]?.arrayValue?.first?["params"] != nil
            guard isSetup, request["op"] == .string("render"), first.setOnce() else {
                return FakeRender.reply(to: request)
            }
            return .heldWith(
                #"{"ok": true, "layers": [{"kind": "plate", "placements": [0], "#
                    + #""rect": [0, 0, 1, 1], "unfit": [], "bytes": 4}]}"#,
                payload: Data([10, 20, 30, 255]))
        }
    }

    /// A change made while the last one's answer is on its way: the newer setup's tile is kept.
    @Test func theLastSetupWins() async throws {
        let fixture = try Self.holdingFirstSetup()
        let draft = try Self.draft()
        let tiles = await Self.tiles(draft, fixture)
        let needle: [String: JSONValue] = ["style": .string("needle")]
        let older = Task {
            await tiles.drawSetup(
                Self.meter, settings: Self.bar, for: draft, from: Self.source(fixture))
        }
        try await fixture.launcher.untilHolding()
        let newer = Task {
            await tiles.drawSetup(
                Self.meter, settings: needle, for: draft, from: Self.source(fixture))
        }
        for _ in 0..<200 where fixture.queue.waiting < 1 {
            try await Task.sleep(for: .milliseconds(5))
        }
        fixture.launcher.releaseHeld()
        await older.value
        await newer.value
        let key = LibraryTiles.Key(draft.laidOut, draft.content)
        #expect(tiles.sets[key]?.setups["meter"]?.settings == needle)
    }

    /// A setup cleared while its tile's answer is on its way keeps no tile.
    @Test func aSetupClearedInFlightKeepsNoTile() async throws {
        let fixture = try Self.holdingFirstSetup()
        let draft = try Self.draft()
        let tiles = await Self.tiles(draft, fixture)
        let older = Task {
            await tiles.drawSetup(
                Self.meter, settings: Self.bar, for: draft, from: Self.source(fixture))
        }
        try await fixture.launcher.untilHolding()
        await tiles.drawSetup(Self.meter, settings: [:], for: draft, from: Self.source(fixture))
        fixture.launcher.releaseHeld()
        await older.value
        #expect(tiles.setupTile("meter") == nil)
    }

    /// "Changing the scene's colours": the set-up tile is drawn again in the new settings.
    @Test func newSceneSettingsDrawTheSetupAgain() async throws {
        let fixture = try RenderingFixture()
        let tiles = await Self.tiles(try Self.draft(), fixture)
        await tiles.drawSetup(
            Self.meter, settings: Self.bar, for: try Self.draft(), from: Self.source(fixture))
        let recoloured = try Self.draft(colours: "b")
        await tiles.draw(for: recoloured, from: Self.source(fixture))
        await tiles.drawSetup(
            Self.meter, settings: Self.bar, for: recoloured, from: Self.source(fixture))
        #expect(Self.setupRenders(fixture).last?["scene"]?["colors"] == .string("b"))
        #expect(tiles.setupTile("meter") != nil)
    }

    /// "Marked and cleared": an empty setup shows the plain tile, with no request.
    @Test func clearingTheSetupShowsThePlainTile() async throws {
        let fixture = try RenderingFixture()
        let draft = try Self.draft()
        let tiles = await Self.tiles(draft, fixture)
        await tiles.drawSetup(
            Self.meter, settings: Self.bar, for: draft, from: Self.source(fixture))
        let sent = Self.setupRenders(fixture).count
        await tiles.drawSetup(Self.meter, settings: [:], for: draft, from: Self.source(fixture))
        #expect(tiles.setupTile("meter") == nil)
        #expect(Self.setupRenders(fixture).count == sent)
    }

    @Test func aDriftedCardIsNotDrawn() async throws {
        let fixture = try RenderingFixture()
        let draft = try Self.draft()
        let tiles = await Self.tiles(draft, fixture)
        let cards = ["meter": "src/cards/meter"]
        let drift = CardDrift.between(
            bundled: CardManifest(digest: "a", entries: ["src/cards/meter": "1"], cards: cards),
            host: CardManifest(digest: "b", entries: ["src/cards/meter": "2"], cards: cards),
            source: .panel)
        await tiles.drawSetup(
            Self.meter, settings: Self.bar, for: draft, from: Self.source(fixture, drift: drift))
        #expect(Self.setupRenders(fixture).isEmpty && tiles.setupTile("meter") == nil)
    }
}
