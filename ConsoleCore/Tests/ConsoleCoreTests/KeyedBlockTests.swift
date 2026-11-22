import Foundation
import Testing

@testable import ConsoleCore

/// `card-settings`, "A keyed block is edited row by row", "A keyed block's span is checked before it
/// is stored", "A cleared row removes its key and an empty block is unset", and "A keyed block is
/// edited on every selected card as one step", read from audio-vue's exported `card.meter`.
@MainActor struct KeyedBlockTests {
    private static func definition() throws -> JSONValue {
        let file = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "Fixtures/meter-schema.json")
        return try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: file))
    }

    private static func block() throws -> KeyedBlock {
        let group = SettingGroup(definition: try definition())
        guard case .keyed(let block) = group["scales"]?.shape else {
            throw KeyedBlockFailure.notKeyed
        }
        return block
    }

    private enum KeyedBlockFailure: Error { case notKeyed }

    /// The refusal `result` carries, or nil where it stores.
    private static func refusal(_ result: Result<JSONValue?, SpanRefusal>) -> SpanRefusal? {
        if case .failure(let refusal) = result { return refusal }
        return nil
    }

    @Test func theScalesBlockIsKeyedInTheExportsOrder() throws {
        let block = try Self.block()
        #expect(block.keys.count == 22)
        #expect(block.keys.first?.name == "program_loudness")
        let correlation = try #require(block[key: "correlation"])
        #expect(correlation.range == [-1, 1])
        #expect(correlation.anchor == 0)
        #expect(correlation.settings.settings.map(\.key) == ["lo", "hi", "anchor"])
        #expect(correlation.required == ["lo", "hi"])
    }

    @Test func aMissingEndIsRefused() throws {
        let block = try Self.block()
        #expect(
            Self.refusal(block.edit(nil, key: "correlation", lo: 0.2, hi: nil, anchor: nil))
                == .missingEnd)
        #expect(SpanRefusal.missingEnd.text == "a scale needs both a low and a high end")
    }

    @Test func aHighNotAboveTheLowIsRefused() throws {
        let block = try Self.block()
        #expect(
            Self.refusal(block.edit(nil, key: "correlation", lo: 0.5, hi: 0.2, anchor: nil))
                == .notAbove(low: 0.5))
        #expect(SpanRefusal.notAbove(low: 0.5).text == "must be above the low end 0.5")
    }

    /// The card checks the anchor it draws with, so a blank anchor the new span excludes is refused
    /// with the product's value (alignment F1, match the card).
    @Test func aBlankAnchorTheSpanExcludesIsRefusedWithTheProductsValue() throws {
        let block = try Self.block()
        #expect(
            Self.refusal(block.edit(nil, key: "correlation", lo: 0.2, hi: 1, anchor: nil))
                == .anchorOutside(anchor: 0, low: 0.2, high: 1))
        #expect(
            SpanRefusal.anchorOutside(anchor: 0, low: 0.2, high: 1).text
                == "the anchor 0.0 is outside 0.2 to 1.0")
    }

    @Test func anAnchorSetOutsideTheSpanIsRefused() throws {
        let block = try Self.block()
        #expect(
            Self.refusal(block.edit(nil, key: "correlation", lo: -0.5, hi: 0.5, anchor: 0.9))
                == .anchorOutside(anchor: 0.9, low: -0.5, high: 0.5))
    }

    @Test func aValidSpanIsStoredWithItsEnds() throws {
        let block = try Self.block()
        let stored = try block.edit(nil, key: "correlation", lo: -0.5, hi: 0.5, anchor: nil).get()
        #expect(
            stored
                == .object(["correlation": .object(["lo": .decimal(-0.5), "hi": .decimal(0.5)])]))
    }

    @Test func aWholeEndIsStoredAsAnInteger() throws {
        let block = try Self.block()
        let stored = try block.edit(nil, key: "correlation", lo: -1, hi: 1, anchor: 0.5).get()
        let span = KeyedBlock.span(of: "correlation", in: stored)
        #expect(span == KeyedBlock.Span(lo: -1, hi: 1, anchor: 0.5))
        #expect(stored?["correlation"]?["lo"] == .integer(-1))
    }

    @Test func clearingBothEndsRemovesOnlyThatKey() throws {
        let block = try Self.block()
        let held: JSONValue = .object([
            "correlation": .object(["lo": .integer(0), "hi": .integer(1)]),
            "program_loudness": .object(["lo": .integer(-50), "hi": .integer(-5)]),
        ])
        let kept = try block.edit(held, key: "correlation", lo: nil, hi: nil, anchor: nil).get()
        #expect(
            kept
                == .object(["program_loudness": .object(["lo": .integer(-50), "hi": .integer(-5)])])
        )
    }

    @Test func clearingTheLastKeyLeavesTheBlockUnset() throws {
        let block = try Self.block()
        let held: JSONValue = .object([
            "correlation": .object(["lo": .integer(0), "hi": .integer(1)])
        ])
        let cleared = try block.edit(held, key: "correlation", lo: nil, hi: nil, anchor: nil).get()
        #expect(cleared == nil)
    }

    @Test func aKeyTheBlockDoesNotTakeIsRefused() throws {
        let block = try Self.block()
        #expect(
            Self.refusal(block.edit(nil, key: "not_a_field", lo: 0, hi: 1, anchor: nil))
                == .unknownKey("not_a_field"))
    }

    /// Each card takes the span on its own block, so the cards keep their other keys, and one undo
    /// reverses the change on both (design D3).
    @Test func aChangeOnTwoCardsKeepsEachCardsOtherKeysAndUndoesAsOneStep() throws {
        let block = try Self.block()
        let manager = UndoManager()
        manager.groupsByEvent = false
        let first = LayoutCard(
            kind: "meter", cells: rect(0, 0, 4, 4),
            settings: [
                "scales": .object([
                    "program_loudness": .object(["lo": .integer(-50), "hi": .integer(-5)])
                ])
            ])
        let second = LayoutCard(
            kind: "meter", cells: rect(4, 0, 4, 4),
            settings: [
                "scales": .object([
                    "peak_to_loudness": .object(["lo": .integer(0), "hi": .integer(20)])
                ])
            ])
        let editor = SceneEditor(layout: try layout([first, second]), undoManager: manager)
        editor.select(first.id)
        editor.toggle(second.id)

        editor.editSetting("scales", label: "Scales", on: [first.id, second.id]) { current in
            switch block.edit(current, key: "correlation", lo: 0, hi: 0.5, anchor: nil) {
            case .success(let next): next
            case .failure: current
            }
        }

        #expect(manager.undoActionName == "Change Scales")
        let scalesA = editor.layout.card(first.id)?.settings["scales"]
        let scalesB = editor.layout.card(second.id)?.settings["scales"]
        #expect(scalesA?["program_loudness"]?["lo"] == .integer(-50))
        #expect(scalesA?["correlation"]?["hi"] == .decimal(0.5))
        #expect(scalesB?["peak_to_loudness"]?["hi"] == .integer(20))
        #expect(scalesB?["correlation"]?["hi"] == .decimal(0.5))
        #expect(scalesB?["program_loudness"] == nil)

        manager.undo()
        #expect(editor.layout.card(first.id)?.settings["scales"]?["correlation"] == nil)
        #expect(editor.layout.card(second.id)?.settings["scales"]?["correlation"] == nil)
        #expect(
            editor.layout.card(second.id)?.settings["scales"]?["peak_to_loudness"]?["hi"]
                == .integer(20))
    }

    /// A row whose span is already stored changes nothing, so it adds no undo step (design D3).
    @Test func aChangeThatChangesNothingAddsNoStep() throws {
        let manager = UndoManager()
        manager.groupsByEvent = false
        let held = LayoutCard(
            kind: "meter", cells: rect(0, 0, 4, 4),
            settings: [
                "scales": .object(["correlation": .object(["lo": .integer(0), "hi": .integer(1)])])
            ])
        let editor = SceneEditor(layout: try layout([held]), undoManager: manager)
        editor.editSetting("scales", label: "Scales", on: [held.id]) { $0 }
        #expect(manager.canUndo == false)
    }

    /// `card-settings`, "A keyed block shows the rows of the keys its cards pick": the picking setting
    /// the export names, and the keys the cards pick by it, each card's unset pick taking its default.
    @Test func theScalesBlockNamesFieldAsItsPickingSetting() throws {
        let block = try Self.block()
        #expect(block.keyedBy == "field")
    }

    @Test func aBlockWithNoPickingSettingIsNotKeyed() {
        let property = JSONValue.object(["type": .string("object"), "x-keys": .array([])])
        #expect(KeyedBlock(property: property) == nil)
    }

    @Test func eachCardsPickedKeyShowsItsRowOnceInTheBlocksOrder() throws {
        let block = try Self.block()
        let groups = ["meter": SettingGroup(definition: try Self.definition())]
        let cards = [
            LayoutCard(
                kind: "meter", cells: rect(0, 0, 4, 4), settings: ["field": .string("correlation")]),
            LayoutCard(kind: "meter", cells: rect(4, 0, 4, 4)),
            LayoutCard(
                kind: "meter", cells: rect(8, 0, 4, 4), settings: ["field": .string("correlation")]),
        ]
        let picked = KeyedBlock.picked(by: block.keyedBy, across: cards, declaredBy: groups)
        #expect(picked == ["correlation", "program_loudness"])
        #expect(block.keys(picked: picked).map(\.name) == ["program_loudness", "correlation"])
    }
}
