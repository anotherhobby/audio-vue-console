import Foundation
import Testing

@testable import ConsoleCore

/// `scene-rendering`'s parked plates: kept when parked, drawn alone when they must be, and named
/// when too small (`card-parking`, design D7 and D11).
@MainActor
struct ParkedPlatesRenderingTests {
    /// The fixture's scene with its last card, `tiny`, parked 40 rows down.
    private static func parkingLast(_ fixture: RenderingFixture) throws -> SceneContent {
        let last = try #require(fixture.layout.cards.last)
        return try fixture.content(fixture.layout).dragging(
            [last.id], by: CellOffset(cols: 0, rows: 40), within: testPane)
    }

    /// `scene-rendering`, "A parked card keeps its plate": "Parking a card" and "Returning it".
    @Test func parkingKeepsThePlateAndReturningDrawsIt() async throws {
        let fixture = try RenderingFixture()
        await fixture.rendering.attach(fixture.queue)
        let last = try #require(fixture.layout.cards.last)
        let parked = try Self.parkingLast(fixture)
        await fixture.rendering.show(parked)
        #expect(fixture.launcher.requests.count == 1)
        #expect(fixture.rendering.parked.layers[[last.id]] != nil)
        #expect(fixture.rendering.plates.count == 2)
        await fixture.rendering.show(
            try parked.dragging([last.id], by: CellOffset(cols: 2, rows: -40), within: testPane))
        #expect(fixture.launcher.requests.count == 2)
        #expect(fixture.launcher.requests.last?["plates"] == .array([.integer(2)]))
        #expect(
            fixture.rendering.plates[[last.id]]?.cells
                == CellRect(col: 32, row: 0, cols: 4, rows: 4))
        #expect(fixture.rendering.parked.layers.isEmpty)
    }

    /// `scene-rendering`, "A parked plate is drawn again on its own": "A parked card's setting".
    @Test func aParkedCardsSettingDrawsItAlone() async throws {
        let fixture = try RenderingFixture()
        await fixture.rendering.attach(fixture.queue)
        let last = try #require(fixture.layout.cards.last)
        let parked = try Self.parkingLast(fixture)
        await fixture.rendering.show(parked)
        await fixture.rendering.show(parked.setting("floor_db", to: .integer(-80), on: [last.id]))
        #expect(fixture.launcher.requests.count == 2)
        let request = try #require(fixture.launcher.requests.last)
        #expect(request["plates"] == .array([.integer(0)]))
        #expect(request["backdrop"] == .bool(false))
        let cards = request["scene"]?["cards"]?.arrayValue ?? []
        #expect(cards.count == 1)
        #expect(cards.first?["card"] == .string("tiny"))
        #expect(cards.first?["col"] == .integer(0) && cards.first?["row"] == .integer(0))
        let kept = try #require(fixture.rendering.parked.layers[[last.id]])
        #expect(kept.settings[last.id] == ["floor_db": .integer(-80)])
        #expect(kept.cells == CellRect(col: 0, row: 0, cols: 4, rows: 4))
    }

    /// `scene-rendering`, "A parked plate is drawn again on its own": "The scene's typeface".
    @Test func aRestyleDrawsTheSceneAndTheParkedPlate() async throws {
        let fixture = try RenderingFixture()
        await fixture.rendering.attach(fixture.queue)
        var parked = try Self.parkingLast(fixture)
        await fixture.rendering.show(parked)
        parked.blocks["typeface"] = .string("Oxanium")
        await fixture.rendering.show(parked)
        #expect(fixture.launcher.requests.count == 3)
        let alone = fixture.launcher.requests.filter { $0["backdrop"] == .bool(false) }
        #expect(alone.count == 1)
    }

    /// `scene-rendering`, "A parked plate is drawn again on its own": "A parked card resized".
    @Test func aParkedResizeDrawsItAlone() async throws {
        let fixture = try RenderingFixture()
        await fixture.rendering.attach(fixture.queue)
        let last = try #require(fixture.layout.cards.last)
        let parked = try Self.parkingLast(fixture)
        await fixture.rendering.show(parked)
        let resized = try parked.resizing(
            last.id, edges: .right, by: CellOffset(cols: 2, rows: 0), minimum: .oneCell,
            within: testPane)
        await fixture.rendering.show(resized)
        #expect(fixture.launcher.requests.count == 2)
        let card = fixture.launcher.requests.last?["scene"]?["cards"]?.arrayValue?.first
        #expect(card?["colspan"] == .integer(6))
        #expect(fixture.rendering.parked.layers[[last.id]]?.cells.cols == 6)
    }

    /// `scene-rendering`, "A card that cannot show its reading is named": "A parked card made too
    /// small". The plate drawn alone is reported unfit.
    @Test func aParkedCardTooSmallIsNamed() async throws {
        let fixture = try RenderingFixture { request in
            guard request["backdrop"] == .bool(false) else { return FakeRender.reply(to: request) }
            return .answer(
                #"{"ok": true, "layers": [{"kind": "plate", "placements": [0], "#
                    + #""rect": [0, 0, 1, 1], "unfit": ["tiny"], "bytes": 4}]}"#,
                payload: Data([10, 20, 30, 255]))
        }
        await fixture.rendering.show(try Self.parkingLast(fixture))
        await fixture.rendering.attach(fixture.queue)
        #expect(fixture.rendering.unfit == ["tiny"])
        #expect(
            fixture.rendering.messages.contains { $0.hasPrefix("Too small to show its reading") })
    }

    /// A scene opened with a card already parked has no layer kept for it, so it is drawn alone.
    @Test func aParkedCardWithNoLayerIsDrawnAlone() async throws {
        let fixture = try RenderingFixture()
        let last = try #require(fixture.layout.cards.last)
        await fixture.rendering.show(try Self.parkingLast(fixture))
        await fixture.rendering.attach(fixture.queue)
        #expect(fixture.launcher.requests.count == 2)
        #expect(fixture.rendering.parked.layers[[last.id]] != nil)
        #expect(fixture.rendering.plates.count == 2)
    }
}
