import Foundation
import Testing

@testable import ConsoleCore

/// `scene-repair`: what a scene needs to pass the host's schema, and the wording of each change,
/// read from the trimmed copy of audio-vue's schema.
struct SceneShapeTests {
    private static let fixtures = URL(filePath: #filePath).deletingLastPathComponent()
        .appending(path: "Fixtures")

    private static func json(_ name: String) throws -> JSONValue {
        try JSONDecoder().decode(
            JSONValue.self, from: Data(contentsOf: fixtures.appending(path: name)))
    }

    private static func shape() throws -> SceneShape {
        SceneShape(schema: try json("schema-trimmed.json"))
    }

    private static func scene(_ text: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    }

    private static func repair(_ text: String) throws -> SceneRepair {
        try #require(try shape().repair(of: scene(text)))
    }

    @Test func theShippedRTASceneNeedsNoRepair() throws {
        #expect(try Self.shape().repair(of: Self.json("rta-scene.json")) == nil)
    }

    @Test func theRTAKeysTheAnalysisBlockLostAreRemoved() throws {
        let shipped = try Self.json("rta-scene.json")
        var stale = shipped.objectValue ?? [:]
        stale["analysis"] = .object([
            "rta_hold_s": .integer(1), "rta_peak_fall_db_s": .decimal(30),
            "rta_weighting": .string("F"),
        ])
        let repair = try #require(try Self.shape().repair(of: .object(stale)))
        #expect(repair.doc == .object(stale.merging(["analysis": .object([:])]) { $1 }))
        #expect(
            repair.lines == [
                "Analysis: rta_hold_s removed", "Analysis: rta_peak_fall_db_s removed",
                "Analysis: rta_weighting removed",
            ])
    }

    @Test func aGridSizeIsRemovedAndTheGapKept() throws {
        let repair = try Self.repair(
            #"{"grid": {"cols": 96, "rows": 36, "gap": 8}, "cards": [{"card": "rta_bars"}]}"#)
        #expect(repair.doc?["grid"] == .object(["gap": .integer(8)]))
    }

    @Test func aNumberPastItsBoundIsBroughtBackToIt() throws {
        let repair = try Self.repair(
            #"{"cards": [{"card": "rta_bars", "params": {"hold_s": 20}}]}"#)
        #expect(repair.doc?["cards"]?.arrayValue?.first?["params"]?["hold_s"] == .integer(10))
        #expect(repair.lines == ["rta bars (card 1): hold_s 20 → 10"])
    }

    @Test func aChoiceNoLongerOfferedIsUnset() throws {
        let repair = try Self.repair(
            #"{"cards": [{"card": "rta_bars", "params": {"release": "hold"}}]}"#)
        #expect(repair.doc?["cards"]?.arrayValue?.first?["params"] == .object([:]))
        #expect(repair.lines == ["rta bars (card 1): release hold → default"])
    }

    @Test func aCardTheHostDoesNotHaveIsRemoved() throws {
        let repair = try Self.repair(
            #"{"cards": [{"card": "spectrum_old"}, {"card": "rta_bars"}]}"#)
        #expect(repair.doc?["cards"] == .array([.object(["card": .string("rta_bars")])]))
        #expect(repair.removedCards == [0])
        #expect(repair.lines == ["spectrum old (card 1) removed"])
    }

    /// A scale's ends depend on each other, so a scale giving one is removed and its neighbours
    /// kept (`scene-repair`, "A repair removes an entry it cannot make whole").
    @Test func aScaleWithOneEndIsRemoved() throws {
        let repair = try Self.repair(
            #"""
            {"cards": [{"card": "meter", "params": {"scales": {
              "program_loudness": {"lo": -50}, "peak_to_loudness": {"lo": 0, "hi": 20}}}}]}
            """#)
        #expect(
            repair.doc?["cards"]?.arrayValue?.first?["params"]?["scales"]
                == .object(["peak_to_loudness": .object(["lo": .integer(0), "hi": .integer(20)])]))
        #expect(repair.changes.count == 1)
    }

    @Test func aSceneLeftWithNoCardCannotBeRepaired() throws {
        let repair = try Self.repair(#"{"cards": [{"card": "spectrum_old"}]}"#)
        #expect(!repair.canRepair)
    }

    @Test func aGradientLeftWithOneStopIsUnset() throws {
        let repair = try Self.repair(
            ##"{"backdrop": {"gradient": ["#000000", "nope"]}, "cards": [{"card": "rta_bars"}]}"##)
        #expect(repair.doc?["backdrop"] == .object([:]))
        #expect(repair.lines == ["Backdrop: gradient removed"])
    }

    @Test func everyKeywordTheExportUsesIsOneTheWalkKnows() throws {
        var used: Set<String> = []
        Self.keywords(in: try Self.json("schema-trimmed.json"), into: &used)
        #expect(used.subtracting(SceneShape.keywords).isEmpty)
    }

    /// The keywords of `schema` and of every schema inside it, past the names under `properties`
    /// and `$defs` and the values of annotations, choices and constants.
    private static func keywords(in schema: JSONValue, into used: inout Set<String>) {
        if let items = schema.arrayValue {
            for item in items { keywords(in: item, into: &used) }
            return
        }
        for (key, value) in schema.objectValue ?? [:] where !key.hasPrefix("x-") {
            used.insert(key)
            if ["properties", "$defs"].contains(key) {
                for inner in (value.objectValue ?? [:]).values {
                    keywords(in: inner, into: &used)
                }
            } else if !valueKeywords.contains(key) {
                keywords(in: value, into: &used)
            }
        }
    }

    private static let valueKeywords: Set<String> = [
        "default", "enum", "const", "required", "dependentRequired",
    ]
}
