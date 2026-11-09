import Foundation
import Testing

@testable import ConsoleCore

/// `scene-canvas` and `scene-layout`: the cards and minimums the schema declares, their categories,
/// and the grid's defaults, read from a trimmed copy of audio-vue's exported schema.
struct SchemaFactsTests {
    private static func schema() throws -> JSONValue {
        let file = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "Fixtures/schema-trimmed.json")
        return try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: file))
    }

    private static func facts() throws -> SchemaFacts {
        try #require(SchemaFacts(schema: schema()))
    }

    /// `capture-input`: the rates come from the host's schema, lowest first.
    @Test func theInputsRatesAsTheHostDeclaresThem() throws {
        #expect(try SchemaFacts.inputRates(Self.schema()) == [44100, 48000, 88200, 96000, 192000])
    }

    @Test func aRateWithNoChoicesDeclaresNoRates() {
        let rate = JSONValue.object(["type": .string("integer"), "default": .integer(48_000)])
        let input = JSONValue.object(["properties": .object(["rate": rate])])
        let schema = JSONValue.object(["$defs": .object(["install.input": input])])
        #expect(SchemaFacts.inputRates(schema) == nil)
    }

    @Test func theGridsDefaults() throws {
        #expect(try Self.facts().defaultGrid == CellSize(cols: 64, rows: 36))
    }

    @Test func onlyPlaceableCardsAreOfferedInTheLibrarysOrder() throws {
        let names = try Self.facts().placeable.map(\.name)
        #expect(names == ["vu_meter", "peak_rms_vertical", "waveform", "logo"])
    }

    @Test func theCategoriesInThePanelsOrder() throws {
        let categories = try Self.facts().categories
        #expect(categories.map(\.id) == ["level", "waveform", "calibration", "audio-vue"])
        #expect(categories.map(\.label) == ["Level", "Waveform", "Calibration", "audio-vue"])
    }

    /// `scene-canvas`, "The library offers the host's placeable cards", "Grouped as the panel
    /// declares" and "A category with nothing to place".
    @Test func theLibraryGroupsCardsInThePanelsOrder() throws {
        let library = try Self.facts().library
        #expect(library.map(\.category.label) == ["Level", "Waveform", "audio-vue"])
        #expect(library.first?.cards.map(\.name) == ["vu_meter", "peak_rms_vertical"])
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
