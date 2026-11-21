import Testing

@testable import ConsoleCore

/// `scene-settings`, "The backdrop is one source" and "A gradient's stops and angle are edited"
/// (design D3).
struct BackdropSourceTests {
    private static let background = "#04060E"
    private static let gradient = JSONValue.object([
        "gradient": .array([.string("#112233"), .string("#445566")]), "angle": .integer(90),
    ])

    @Test func aGradientSwitchedToColourHoldsItsFirstStopAndNoAngle() throws {
        let source = BackdropSource(block: Self.gradient)
        let colour = try #require(source.switched(to: .colour, background: Self.background))
        #expect(colour.written(over: Self.gradient) == ["color": .string("#112233")])
    }

    @Test func aColourSwitchedToGradientEndsInTheBackground() throws {
        let block = JSONValue.object(["color": .string("#112233")])
        let gradient = BackdropSource(block: block).switched(
            to: .gradient, background: Self.background)
        #expect(gradient == .gradient(["#112233", Self.background]))
    }

    @Test func noneRemovesTheBlockBlurAndAll() {
        let block = JSONValue.object(["color": .string("#112233"), "blur": .integer(8)])
        #expect(BackdropSource.unset.written(over: block).isEmpty)
    }

    @Test func noneWithNothingElseEmptiesTheBlock() {
        let block = JSONValue.object(["color": .string("#112233")])
        #expect(BackdropSource.unset.written(over: block).isEmpty)
        #expect(BackdropSource(block: nil) == .unset)
    }

    @Test func aGradientKeepsItsAngleAndBlur() {
        let block = JSONValue.object([
            "gradient": .array([.string("#000000"), .string("#FFFFFF")]), "angle": .integer(90),
            "blur": .integer(8),
        ])
        let fields = BackdropSource.gradient(["#111111", "#FFFFFF"]).written(over: block)
        #expect(fields["angle"] == .integer(90) && fields["blur"] == .integer(8))
    }

    @Test func imageChangesNothingUntilOneIsChosen() {
        let source = BackdropSource(block: Self.gradient)
        #expect(source.switched(to: .image, background: Self.background) == nil)
        #expect(
            BackdropSource.image("abc").written(over: Self.gradient) == ["image": .string("abc")])
    }

    /// `scene-settings`, "A gradient returns to the default backdrop's".
    @Test func theDefaultsGradientReplacesTheStopsAndAngleAndKeepsTheBlur() {
        let standard = JSONValue.object([
            "gradient": .array([.string("#2a1a6e"), .string("#0e4a6a")]), "angle": .integer(120),
            "blur": .integer(24),
        ])
        let held = JSONValue.object([
            "gradient": .array([.string("#000000"), .string("#ffffff")]), "blur": .integer(4),
        ])
        let fields = BackdropSource.gradient(of: standard, over: held)
        #expect(fields?["gradient"] == standard["gradient"])
        #expect(fields?["angle"] == .integer(120) && fields?["blur"] == .integer(4))
        #expect(BackdropSource.gradient(of: standard, over: fields.map(JSONValue.object)) == nil)
        #expect(
            BackdropSource.gradient(of: .object(["color": .string("#000000")]), over: held) == nil)
    }

    @Test func aGradientKeepsTwoStops() throws {
        let two = BackdropSource.gradient(["#000000", "#FFFFFF"])
        #expect(two.removingStop(at: 0) == nil)
        let three = try #require(two.addingStop())
        #expect(three == .gradient(["#000000", "#FFFFFF", "#FFFFFF"]))
        #expect(three.removingStop(at: 0) == .gradient(["#FFFFFF", "#FFFFFF"]))
        #expect(two.movingStop(at: 0, by: 1) == .gradient(["#FFFFFF", "#000000"]))
        #expect(two.movingStop(at: 1, by: 1) == nil)
        #expect(two.settingStop(at: 1, to: "#FF0000") == .gradient(["#000000", "#FF0000"]))
    }
}

/// `scene-settings`, "The backdrop is one source": a source chosen again is as it was (design D3).
@MainActor struct BackdropMemoryTests {
    private static let background = "#04060E"
    private static let threeStops = JSONValue.object([
        "gradient": .array([.string("#112233"), .string("#445566"), .string("#778899")]),
        "angle": .integer(90), "blur": .integer(8),
    ])

    private func editor() throws -> SceneEditor {
        let layout = try SceneLayout(grid: CellSize(cols: 64, rows: 36), cards: [])
        return SceneEditor(
            content: SceneContent(layout: layout, blocks: ["backdrop": Self.threeStops]))
    }

    @Test func aGradientComesBackWithItsStopsAndAngle() throws {
        let editor = try editor()
        #expect(editor.switchBackdrop(to: .colour, background: Self.background))
        #expect(
            editor.content.blocks["backdrop"]
                == .object(["color": .string("#112233"), "blur": .integer(8)]))
        #expect(editor.switchBackdrop(to: .gradient, background: Self.background))
        #expect(editor.content.blocks["backdrop"] == Self.threeStops)
    }

    @Test func aChosenImageComesBackWithNoPicker() throws {
        let editor = try editor()
        editor.setBackdrop(.image("sky.jpg"))
        #expect(
            editor.content.blocks["backdrop"]
                == .object(["image": .string("sky.jpg"), "blur": .integer(8)]))
        #expect(editor.switchBackdrop(to: .gradient, background: Self.background))
        #expect(editor.content.blocks["backdrop"] == Self.threeStops)
        #expect(editor.switchBackdrop(to: .image, background: Self.background))
        #expect(editor.content.blocks["backdrop"]?["image"] == .string("sky.jpg"))
    }

    @Test func noneThenGradientBringsBackTheBlurToo() throws {
        let editor = try editor()
        #expect(editor.switchBackdrop(to: .unset, background: Self.background))
        #expect(editor.content.blocks["backdrop"] == nil)
        #expect(editor.switchBackdrop(to: .gradient, background: Self.background))
        #expect(editor.content.blocks["backdrop"] == Self.threeStops)
    }

    @Test func noImageYetAsksForOne() throws {
        let editor = try editor()
        #expect(!editor.switchBackdrop(to: .image, background: Self.background))
        #expect(editor.content.blocks["backdrop"] == Self.threeStops)
    }
}
