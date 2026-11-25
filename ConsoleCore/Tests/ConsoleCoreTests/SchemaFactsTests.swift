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

    @Test func theCaptureFormatsInTheSchemasOrder() throws {
        #expect(try SchemaFacts.inputFormats(Self.schema()) == ["S16_LE", "S32_LE"])
    }

    @Test func theCaptureFormatsDefault() throws {
        #expect(try SchemaFacts.inputFormatDefault(Self.schema()) == "S16_LE")
    }

    @Test func anInputWithNoFormatDeclaresNoFormats() {
        let input = JSONValue.object(["properties": .object([:])])
        let schema = JSONValue.object(["$defs": .object(["install.input": input])])
        #expect(SchemaFacts.inputFormats(schema) == nil)
    }

    /// `scene-settings`, "An unset setting the panel also holds shows the panel's value".
    @Test func anUnsetDisplaySettingTakesThePanels() throws {
        let facts = try Self.facts()
        let after = try #require(facts.block("display")?.settings["saver_after_min"])
        let stored = ["display": JSONValue.object(["saver_after_min": .integer(10)])]
        #expect(after.defaultValue == nil)
        #expect(after.inherits == .init(document: "install", block: "display"))
        #expect(facts.inheritedValue(of: after, scene: [:], installed: stored) == .integer(10))
        #expect(
            facts.inheritedValue(of: after, scene: [:], installed: [:])
                == facts.installSettings["display"]?["saver_after_min"]?.defaultValue)
        let saver = try #require(facts.block("display")?.settings["saver"])
        #expect(
            facts.inheritedValue(of: saver, scene: [:], installed: [:]) == .string("bounce"))
        let opacity = try #require(facts.block("glass")?.settings["opacity"])
        #expect(opacity.defaultValue?.numberValue == 0.6)
        #expect(facts.inheritedValue(of: opacity, scene: [:], installed: stored) == nil)
    }

    @Test func aNumberFromNoneToAllIsAnAmount() throws {
        let facts = try Self.facts()
        #expect(facts.block("glass")?.settings["opacity"]?.isAmount == true)
        #expect(facts.block("glass")?.settings["radius"]?.isAmount == false)
        #expect(facts.block("type")?.settings["title"]?.isAmount == false)
    }

    /// `scene-layout`, "A scene is laid out on the panel's grid": the schema's grid block holds
    /// only its gap, and the facts need no grid from it.
    @Test func theGridBlockHoldsOnlyItsGap() throws {
        #expect(try Self.facts().block("grid")?.settings.settings.map(\.key) == ["gap"])
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

    @Test func theMinimumsAreAsDeclared() throws {
        #expect(try Self.facts().minimums["waveform"] == CellSize(cols: 12, rows: 7))
    }

    @Test func aSchemaWithoutDefinitionsGivesNoFacts() {
        #expect(SchemaFacts(schema: .object([:])) == nil)
    }

    // MARK: Settings (`card-settings`, design D2)

    @Test func aVUMetersSettingsInDeclaredOrderWithTheirShapes() throws {
        let vu = try #require(try Self.facts().settings["vu_meter"])
        #expect(
            vu.settings.prefix(5).map(\.key) == [
                "channel", "alignment", "reference_dbfs", "lamp_hold_s", "show_face",
            ])
        #expect(
            vu.settings.prefix(5).map(\.label) == [
                "Channel", "Alignment", "0 VU at (custom)", "Lamp hold", "Scale and labels",
            ])
        #expect(vu.settings.dropFirst(5).first?.key == "series_color")
        #expect(vu.settings.last?.key == "shadow")
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

    @Test func rtaBarsColoursTakeARoleOrAColourAndHaveNoDefault() throws {
        let bars = try #require(try Self.facts().settings["rta_bars"])
        guard case .roleColour(let roles)? = bars["grid_major_color"]?.shape else {
            Issue.record("grid_major_color takes no role")
            return
        }
        #expect(roles.count == 17 && roles.contains("tick") && !roles.contains("ok"))
        #expect(bars["grid_major_color"]?.defaultValue == nil)
        #expect(bars["grid_major_color"]?.role == "grid_major")
        #expect(bars["major_weight_px"]?.shape == .integer(.init(minimum: 1, maximum: 8, step: 1)))
        #expect(bars.settings.first?.key == "floor_db")
        #expect(bars.settings.count == 26)
    }

    // MARK: Scene blocks (`scene-settings`, design D2)

    @Test func theScenesBlocksInTheInspectorsOrder() throws {
        let names = try Self.facts().blocks.map(\.name)
        #expect(names == SchemaFacts.blockOrder)
        #expect(names.first == "backdrop" && names.last == "analysis")
    }

    @Test func theColoursHoldEveryRoleAndStepWithItsDefaultAndTheShadow() throws {
        let colours = try #require(try Self.facts().block("colors")?.settings)
        #expect(colours.settings.count == 24)
        #expect(colours.settings.filter { $0.shape == .colour }.count == 23)
        #expect(colours.settings.allSatisfy { $0.defaultValue != nil })
        #expect(colours["track"]?.defaultValue == .string("#1e2944"))
        #expect(colours["shadow"]?.shape == .number(.init(minimum: 0, maximum: 1, step: 0.05)))
    }

    @Test func aTextRoleTakesASizeWithinItsOwnBounds() throws {
        let type = try #require(try Self.facts().block("type")?.settings)
        #expect(type.settings.map(\.key).first == "title" && type.settings.count == 7)
        #expect(type["title"]?.shape == .number(.init(minimum: 24, maximum: 75, step: 1)))
        #expect(type["title"]?.defaultValue?.numberValue == 45)
        #expect(type["title"]?.unit == "px")
    }

    @Test func theTypefaceIsTheScenesOwnSettingWithLabelledChoices() throws {
        let scene = try Self.facts().sceneSettings
        #expect(scene.settings.map(\.key) == ["typeface"])
        let typeface = try #require(scene["typeface"])
        #expect(typeface.defaultValue == .string("inter"))
        #expect(typeface.label(of: .string("oxanium")) == "Oxanium")
        #expect(typeface.label(of: .string("unknown")) == "unknown")
    }

    @Test func aGradientIsAListOfAtLeastTwoColours() throws {
        let backdrop = try #require(try Self.facts().block("backdrop")?.settings)
        #expect(backdrop["gradient"]?.shape == .colours(minimum: 2))
    }

    @Test func theCaptureRateIsAChainSettingWithNoDefault() throws {
        let rate = try #require(try Self.facts().block("analysis")?.settings["capture_rate"])
        #expect(rate.settingClass == "chain")
        #expect(rate.defaultValue == nil)
    }

    @Test func aCardWithNoSettingsReadsNone() throws {
        #expect(try Self.facts().settings["calibration"]?.settings.isEmpty == true)
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
