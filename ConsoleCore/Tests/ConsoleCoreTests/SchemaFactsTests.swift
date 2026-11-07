import Foundation
import Testing

@testable import ConsoleCore

/// `scene-canvas` and `scene-layout`: the cards and minimums the schema declares, and the grid's
/// defaults, read from a trimmed copy of audio-vue's exported schema.
struct SchemaFactsTests {
    private static func facts() throws -> SchemaFacts {
        let file = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "Fixtures/schema-trimmed.json")
        let schema = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: file))
        return try #require(SchemaFacts(schema: schema))
    }

    @Test func theGridsDefaults() throws {
        #expect(try Self.facts().defaultGrid == CellSize(cols: 64, rows: 36))
    }

    @Test func onlyPlaceableCardsAreOffered() throws {
        let names = try Self.facts().placeable.map(\.name)
        #expect(names == ["logo", "peak_rms_vertical", "waveform"])
    }

    @Test func eachCardsMinimum() throws {
        let facts = try Self.facts()
        #expect(facts.cards["waveform"]?.minimum == CellSize(cols: 12, rows: 7))
        #expect(facts.cards["calibration"]?.placeable == false)
    }

    @Test func aMinimumScalesByRowsRoundingUp() {
        let minimum = CellSize(cols: 17, rows: 10)
        #expect(SchemaFacts.scaled(minimum, toRows: 36) == minimum)
        #expect(SchemaFacts.scaled(minimum, toRows: 72) == CellSize(cols: 34, rows: 20))
        #expect(SchemaFacts.scaled(minimum, toRows: 24) == CellSize(cols: 12, rows: 7))
    }

    @Test func aSchemaWithoutTheGridsDefaults() {
        #expect(SchemaFacts(schema: .object(["$defs": .object([:])])) == nil)
    }
}
