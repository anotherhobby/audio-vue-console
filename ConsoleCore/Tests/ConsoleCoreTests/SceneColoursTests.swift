import Foundation
import Testing

@testable import ConsoleCore

/// `scene-settings`, design D8, and `card-settings`, "A setting shows the scene's value or the
/// card's default": a card's colour resolved by lookup from the copy of audio-vue's schema.
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

    private static func setting(_ card: String, _ key: String) throws -> SettingDeclaration {
        try #require(try facts().settings[card]?[key])
    }

    @Test func aRoleTheSceneLeavesTakesItsDefault() throws {
        let colours = try Self.colours()
        #expect(colours.colour(of: "grid_minor", in: [:])?.hex == "#6D7485")
        let blocks = ["colors": JSONValue.object(["grid_minor": .string("#112233")])]
        #expect(colours.colour(of: "grid_minor", in: blocks)?.hex == "#112233")
        #expect(colours.colour(of: "grid_major", in: blocks)?.hex == "#6D7485")
        #expect(colours.colour(of: "ok", in: [:]) == nil)
    }

    @Test func rolesAndScalesComeInDeclaredOrder() throws {
        let colours = try Self.colours()
        #expect(colours.roles.count == 17)
        #expect(colours.roles.prefix(3).map(\.id) == ["card", "title", "value"])
        #expect(colours.role("track")?.group == "lines")
        #expect(colours.role("grid_minor")?.label == "Grid minor")
        #expect(colours.scales.map(\.label) == ["Status", "Stereo phase"])
        #expect(colours.scales.first?.steps == ["ok", "caution", "alert"])
    }

    @Test func theColoursAreListedByGroupThenByScale() throws {
        let facts = try Self.facts()
        let settings = try #require(facts.block("colors")?.settings)
        let groups = facts.colours.groups(of: settings)
        #expect(
            groups.map(\.label)
                == ["Background", "Text", "Lines", "Signal", "Status", "Stereo phase"])
        #expect(groups.first?.settings.map(\.label) == ["Card"])
        #expect(groups.last?.settings.map(\.key) == ["centred", "wide", "anti_phase"])
        #expect(facts.colours.ungrouped(of: settings).map(\.key) == ["shadow"])
    }

    @Test func anUnsetCardColourIsTheScenesForItsRole() throws {
        let facts = try Self.facts()
        let minor = try Self.setting("rta_bars", "grid_minor_color")
        let plain = try #require(minor.drawnColour(nil, in: [:], colours: facts.colours))
        #expect(plain.colour.hex == "#6D7485")
        #expect(plain.caption == "Uses the scene's Grid minor colour")
        let blocks = ["colors": JSONValue.object(["grid_minor": .string("#ABCDEF")])]
        #expect(minor.drawnColour(nil, in: blocks, colours: facts.colours)?.colour.hex == "#ABCDEF")
    }

    @Test func aCardColourSetToAnotherRoleIsThatRolesColour() throws {
        let facts = try Self.facts()
        let minor = try Self.setting("rta_bars", "grid_minor_color")
        let blocks = ["colors": JSONValue.object(["track": .string("#010203")])]
        let drawn = try #require(
            minor.drawnColour(.string("track"), in: blocks, colours: facts.colours))
        #expect(drawn.colour.hex == "#010203" && drawn.role?.id == "track")
    }

    @Test func aCardColourSetToAColourIsItsOwn() throws {
        let facts = try Self.facts()
        let minor = try Self.setting("rta_bars", "grid_minor_color")
        let drawn = try #require(
            minor.drawnColour(.string("#445566"), in: [:], colours: facts.colours))
        #expect(drawn.colour.hex == "#445566" && drawn.role == nil && drawn.caption == nil)
    }

    @Test func aCardsOwnColourTakesItsOwnDefault() throws {
        let facts = try Self.facts()
        let crest = try Self.setting("dynamics_gauge", "crest_color")
        let own = try #require(crest.drawnColour(nil, in: [:], colours: facts.colours))
        #expect(own.colour.hex == "#7AA2FF" && own.role == nil)
        let ratio = try Self.setting("dynamics_gauge", "psr_color")
        let blocks = ["colors": JSONValue.object(["value": .string("#0A0B0C")])]
        let followed = try #require(ratio.drawnColour(nil, in: blocks, colours: facts.colours))
        #expect(followed.colour.hex == "#0A0B0C" && followed.role?.id == "value")
    }

    /// audio-vue `logo`: the logo card's four colours are its own, each a role or a colour.
    @Test func theLogosColoursAreItsOwn() throws {
        let facts = try Self.facts()
        let own = [
            "wordmark_color": "#D4DCEA", "bar_foot_color": "#1AD9CC", "bar_top_color": "#F2528C",
            "hold_color": "#FFF2C7",
        ]
        for (key, hex) in own {
            let colour = try Self.setting("logo", key)
            #expect(colour.shape == .roleColour(roles: Self.roles), "\(key)")
            #expect(colour.role == nil && colour.ownDefault?.uppercased() == hex)
            let drawn = try #require(colour.drawnColour(nil, in: [:], colours: facts.colours))
            #expect(drawn.colour.hex == hex && drawn.role == nil && drawn.caption == nil)
        }
    }

    /// audio-vue `screensaver`: a scene's display block sets the screensaver's four colours, each
    /// a role resolved on the scene or a colour, unset the logo's own, and chooses its backdrop
    /// and plate (`scene-settings`, "A colour in a scene block takes one of the scene's colours or
    /// its own").
    @Test func theScenesScreensaverColoursAreTheLogosOwnUntilSet() throws {
        let facts = try Self.facts()
        let display = try #require(facts.block("display")?.settings)
        let foot = try #require(display["saver_bar_foot_color"])
        #expect(foot.shape == .roleColour(roles: Self.roles) && foot.inherits == nil)
        let unset = try #require(foot.drawnColour(nil, in: [:], colours: facts.colours))
        #expect(unset.colour.hex == "#1AD9CC" && unset.role == nil)
        let blocks = ["colors": JSONValue.object(["bar_body": .string("#FFFF00")])]
        let role = try #require(
            foot.drawnColour(.string("bar_body"), in: blocks, colours: facts.colours))
        #expect(role.colour.hex == "#FFFF00" && role.caption == "Uses the scene's Bar body colour")
        for key in ["saver_wordmark_color", "saver_bar_top_color", "saver_hold_color"] {
            #expect(display[key]?.ownDefault != nil && display[key]?.role == nil, "\(key)")
        }
        for key in ["saver_scene_backdrop", "saver_scene_plate"] {
            #expect(display[key]?.shape == .boolean && display[key]?.defaultValue == .bool(false))
        }
    }

    /// The roles a card's colour may take, in the schema's order.
    private static let roles = [
        "card", "title", "value", "label", "unit", "scale", "caption", "notice", "grid_major",
        "grid_minor", "outline", "tick", "track", "series", "bar_body", "bar_tip", "peak_hold",
    ]

    @Test func aSettingThatIsNoCardColourDrawsNone() throws {
        let facts = try Self.facts()
        let floor = try Self.setting("rta_bars", "floor_db")
        #expect(floor.drawnColour(nil, in: [:], colours: facts.colours) == nil)
    }

    @Test func aCardsUnsetShadowIsTheScenes() throws {
        let facts = try Self.facts()
        let shadow = try Self.setting("vu_meter", "shadow")
        #expect(shadow.inherits == .init(document: "scene", block: "colors"))
        #expect(
            facts.inheritedValue(of: shadow, scene: [:], installed: [:])?.numberValue == 1)
        let blocks = ["colors": JSONValue.object(["shadow": .decimal(0.4)])]
        #expect(facts.inheritedValue(of: shadow, scene: blocks, installed: [:]) == .decimal(0.4))
        let floor = try Self.setting("rta_bars", "floor_db")
        #expect(facts.inheritedValue(of: floor, scene: blocks, installed: [:]) == nil)
    }

    @Test func aBlockSettingIsItsOwnOrTheDefault() throws {
        let title = try #require(try Self.facts().block("colors")?.settings["title"])
        #expect(title.value(in: nil) == .same(.string("#a8bad6"), isSet: false))
        let block = JSONValue.object(["title": .string("#00FF88")])
        #expect(title.value(in: block) == .same(.string("#00FF88"), isSet: true))
    }
}
