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

    // MARK: Settings (`card-settings`, design D2)

    @Test func aVUMetersSettingsInDeclaredOrderWithTheirShapes() throws {
        let vu = try #require(try Self.facts().settings["vu_meter"])
        #expect(
            vu.settings.map(\.key) == [
                "channel", "alignment", "reference_dbfs", "lamp_hold_s", "show_face",
            ])
        #expect(
            vu.settings.map(\.label) == [
                "Channel", "Alignment", "0 VU at (custom)", "Lamp hold", "Scale and labels",
            ])
        #expect(vu["channel"]?.shape == .choice([.string("left"), .string("right")]))
        #expect(vu["channel"]?.settingClass == "chain")
        #expect(
            vu["alignment"]?.standard
                == .document("ITU-R BS.1726", values: [.string("ebu"), .string("smpte")]))
        #expect(vu["reference_dbfs"]?.standard == .governedByNone)
        #expect(
            vu["lamp_hold_s"]?.shape
                == .number(.init(minimum: 0.15, maximum: 5, step: 0.05)))
        #expect(vu["lamp_hold_s"]?.unit == "s")
        #expect(vu["lamp_hold_s"]?.defaultValue == .decimal(0.9))
        #expect(vu["show_face"]?.shape == .boolean)
        #expect(vu["show_face"]?.standard == .notApplicable)
        #expect(vu["show_face"]?.help == "Show the scale and its labels.")
    }

    @Test func rtaBarsColoursHaveNoDefault() throws {
        let bars = try #require(try Self.facts().settings["rta_bars"])
        #expect(bars["major_color"]?.shape == .colour)
        #expect(bars["major_color"]?.defaultValue == nil)
        #expect(bars["major_weight_px"]?.shape == .integer(.init(minimum: 1, maximum: 8, step: 1)))
        #expect(bars.settings.first?.key == "floor_db")
        #expect(bars.settings.count == 11)
    }

    @Test func aCardWithNoSettingsReadsNone() throws {
        #expect(try Self.facts().settings["logo"]?.settings.isEmpty == true)
        #expect(SettingGroup(definition: .object(["type": .string("object")])).settings.isEmpty)
    }

    @Test func anUnknownShapeReadsAsOther() {
        let colours = JSONValue.object([
            "type": .string("array"), "items": .object(["type": .string("string")]),
            "x-label": .string("Colours"),
        ])
        let definition = JSONValue.object(["properties": .object(["colours": colours])])
        #expect(SettingGroup(definition: definition)["colours"]?.shape == .other)
    }

    @Test func aKeyLeftOutOfTheOrderStillFollows() {
        let flag = JSONValue.object(["type": .string("boolean")])
        let definition = JSONValue.object([
            "properties": .object(["b": flag, "a": flag, "c": flag]),
            "x-settings": .array([.string("c")]),
        ])
        #expect(SettingGroup(definition: definition).settings.map(\.key) == ["c", "a", "b"])
    }
}
