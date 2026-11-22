import Foundation
import Testing

@testable import ConsoleCore

/// `scene-settings`, "The inspector shows the scene's settings when no card is selected".
struct SceneSettingsTabTests {
    private static func facts(adding extra: [String: JSONValue] = [:]) throws -> SchemaFacts {
        let file = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "Fixtures/schema-trimmed.json")
        var schema = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: file))
        if var root = schema.objectValue, var definitions = root["$defs"]?.objectValue,
            var scene = definitions["scene"]?.objectValue,
            var properties = scene["properties"]?.objectValue
        {
            for (name, definition) in extra {
                definitions["block.\(name)"] = definition
                properties[name] = .object(["$ref": .string("#/$defs/block.\(name)")])
            }
            scene["properties"] = .object(properties)
            definitions["scene"] = .object(scene)
            root["$defs"] = .object(definitions)
            schema = .object(root)
        }
        return try #require(SchemaFacts(schema: schema))
    }

    @Test func theKnownBlocksFillThreeTabs() throws {
        let facts = try Self.facts()
        #expect(facts.settingsTabs == [.scene, .style, .analysis])
        #expect(
            facts.blocks(on: .scene).map(\.name) == ["backdrop", "glass", "grid", "display"])
        #expect(facts.blocks(on: .style).map(\.name) == ["colors", "type", "case"])
        #expect(facts.blocks(on: .analysis).map(\.name) == ["analysis"])
        #expect(facts.sceneSettings(with: "type").map(\.key) == ["typeface"])
        #expect(facts.sceneSettings(with: "colors").isEmpty)
        #expect(facts.sceneSettings(on: .style).isEmpty && facts.sceneSettings(on: .other).isEmpty)
    }

    /// "The case follows the sizes": a case for each settable role, ALL CAPS unless set.
    @Test func theCaseBlockSetsEachRoleToOneOfTwoCases() throws {
        let block = try #require(try Self.facts().block("case"))
        let settings = block.settings.settings
        #expect(settings.map(\.key) == ["title", "label", "caption", "notice"])
        for setting in settings {
            #expect(setting.shape == .choice([.string("all_caps"), .string("title_case")]))
            #expect(setting.label(of: .string("all_caps")) == "ALL CAPS")
            #expect(setting.label(of: .string("title_case")) == "Title Case")
            #expect(setting.defaultValue == .string("all_caps"))
        }
    }

    @Test func anUnknownBlockHasAnOtherTab() throws {
        let lighting = JSONValue.object([
            "type": .string("object"),
            "properties": .object(["level": .object(["type": .string("number")])]),
        ])
        let facts = try Self.facts(adding: ["lighting": lighting])
        #expect(facts.settingsTabs.last == .other)
        #expect(facts.blocks(on: .other).map(\.name) == ["lighting"])
    }
}
