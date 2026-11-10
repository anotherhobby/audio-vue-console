import Foundation
import Testing

@testable import ConsoleCore

/// `scene-settings`, design D8, and `card-settings`, "A setting shows the scene's value or the
/// card's default": an element's colour resolved by lookup from the trimmed copy of audio-vue's
/// schema.
struct SceneColoursTests {
    private static func facts() throws -> SchemaFacts {
        let file = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "Fixtures/schema-trimmed.json")
        let schema = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: file))
        return try #require(SchemaFacts(schema: schema))
    }

    private static func colours() throws -> SceneColours {
        try facts().colours
    }

    @Test func anElementTheSceneLeavesTakesItsSwatchsDefault() throws {
        let colours = try Self.colours()
        #expect(colours.colour(of: "grid_minor", in: [:])?.hex == "#6D7485")
        #expect(colours.swatch(of: "grid_minor", in: [:])?.label == "Line")
    }

    @Test func aRepointedElementTakesItsNewSwatch() throws {
        let colours = try Self.colours()
        let pointer = JSONValue.object(["grid_minor": .string("accent")])
        let repointed = ["elements": pointer]
        #expect(colours.colour(of: "grid_minor", in: repointed)?.hex == "#7AA2FF")
        var recoloured = repointed
        recoloured["palette"] = .object(["accent": .string("#112233")])
        #expect(colours.colour(of: "grid_minor", in: recoloured)?.hex == "#112233")
        #expect(colours.colour(of: "grid_major", in: recoloured)?.hex == "#6D7485")
    }

    @Test func swatchesAndElementsComeInDeclaredOrderWithTheirFamilies() throws {
        let colours = try Self.colours()
        #expect(colours.swatches.count == 21)
        #expect(colours.swatches.prefix(3).map(\.name) == ["signal", "signal_alt", "signal_3"])
        #expect(colours.swatch("track")?.family == "structure")
        #expect(colours.elements.count == 35)
        #expect(colours.elements.first?.name == "title")
        #expect(colours.element("over")?.family == "status")
        #expect(colours.element("bar_tip")?.swatch == "signal_alt")
    }

    @Test func thePaletteIsGroupedByFamilyInDeclaredOrder() throws {
        let facts = try Self.facts()
        let palette = try #require(facts.block("palette")?.settings)
        let families = try #require(facts.colours.families(of: palette, in: "palette"))
        #expect(families.map(\.name).first == "identity")
        #expect(families.first?.settings.map(\.label) == ["Signal", "Signal alt", "Signal 3"])
        #expect(families.flatMap(\.settings).count == 21)
        #expect(facts.colours.families(of: palette, in: "glass") == nil)
    }

    @Test func anUnsetCardColourFollowsThePalette() throws {
        let facts = try Self.facts()
        let minor = try #require(facts.settings["rta_bars"]?["minor_color"])
        let plain = try #require(minor.inheritedColour(in: [:], colours: facts.colours))
        #expect(plain.colour.hex == "#6D7485")
        #expect(plain.caption == "Uses Grid minor, in Line")
        let blocks = ["palette": JSONValue.object(["line": .string("#ABCDEF")])]
        #expect(minor.inheritedColour(in: blocks, colours: facts.colours)?.colour.hex == "#ABCDEF")
        #expect(
            facts.settings["rta_bars"]?["floor_db"]?.inheritedColour(
                in: [:], colours: facts.colours) == nil)
    }

    @Test func aBlockSettingIsItsOwnOrTheDefault() throws {
        let signal = try #require(try Self.facts().block("palette")?.settings["signal"])
        #expect(signal.value(in: nil) == .same(.string("#1ad9cc"), isSet: false))
        let block = JSONValue.object(["signal": .string("#00FF88")])
        #expect(signal.value(in: block) == .same(.string("#00FF88"), isSet: true))
    }

    @Test func aCardColourNamesItsElement() throws {
        let bars = try #require(try Self.facts().settings["rta_bars"])
        #expect(bars["minor_color"]?.element == "grid_minor")
        #expect(bars["floor_db"]?.element == nil)
    }
}
