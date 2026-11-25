import Foundation
import Testing

@testable import ConsoleCore

/// `scene-rendering`, "A library tile is drawn at its card's whole minimum": each tile is one
/// `minimum` and one render, at the whole size the helper answers (`card-minimum` design D3).
@MainActor
struct LibraryTilesMinimumTests {
    private static let meter = SchemaFacts.Card(
        name: "meter", minimum: CellSize(cols: 8, rows: 6), placeable: true)

    private static func draft() throws -> Draft {
        let doc: JSONValue = .object([
            "name": .string("A"), "cards": .array([.object(["card": .string("meter")])]),
        ])
        let document = SceneDocument(id: "A", name: "A", builtIn: false, fixed: false, doc: doc)
        return Draft(try LaidOutScene(document, panel: CellSize(cols: 64, rows: 36)))
    }

    /// The meter's tiles drawn with `minimum` as the helper's answer to the meter's `minimum`.
    private static func draw(answering minimum: String) async throws -> (LibraryTiles, [JSONValue])
    {
        let fixture = try RenderingFixture { request in
            request["op"] == .string("minimum") ? .answer(minimum) : FakeRender.reply(to: request)
        }
        let tiles = LibraryTiles()
        await tiles.draw(
            for: try draft(),
            from: LibraryTiles.Source(
                cards: [meter], drift: nil, context: RenderRequestTests.context,
                queue: fixture.queue))
        let renders = fixture.launcher.requests.filter {
            $0["op"] == .string("render") && $0["backdrop"] == .bool(false)
        }
        return (tiles, renders)
    }

    /// "A readout drawn whole above its minimum", here the meter, answered whole first at 10 × 8.
    @Test func aTileIsDrawnOnceAtItsWholeSize() async throws {
        let (tiles, renders) = try await Self.draw(
            answering: #"{"ok": true, "whole": [[10, 8], [14, 6]], "readable": [[8, 6]]}"#)
        #expect(tiles.tiles["meter"]?.size == CellSize(cols: 10, rows: 8))
        #expect(renders.count == 1)
        #expect(renders.first?["scene"]?["cards"]?.arrayValue?.first?["colspan"] == .integer(10))
    }

    /// With no answer, the declared minimum stands in (`card-minimum`, "The declared minimum stands
    /// in until an answer is held").
    @Test func noAnswerDrawsTheDeclaredMinimum() async throws {
        let (tiles, renders) = try await Self.draw(answering: #"{"ok": false, "refused": "no"}"#)
        #expect(tiles.tiles["meter"]?.size == Self.meter.minimum)
        #expect(renders.count == 1)
    }
}
