import Foundation
import Synchronization
import Testing

@testable import ConsoleCore

/// A helper's render, faked: a 2 x 2 backdrop when asked for, and a 1 x 1 layer per plate asked
/// for, every plate when none is named. A card named `tiny` is reported as not fitting.
enum FakeRender {
    static func reply(to request: JSONValue, notice: String? = nil) -> ScriptedReply {
        guard request["op"] == .string("render") else {
            return .answer(#"{"ok": true, "cards": "d1", "runs": 1}"#)
        }
        let cards = request["scene"]?["cards"]?.arrayValue ?? []
        let named = request["plates"]?.arrayValue?.compactMap(\.intValue)
        var layers: [String] = []
        var payload = Data()
        if request["backdrop"] != .bool(false) {
            layers.append(
                #"{"kind": "backdrop", "placements": [], "rect": [0, 0, 2, 2], "#
                    + #""unfit": [], "bytes": 16}"#)
            payload.append(Data(repeating: 255, count: 16))
        }
        for plate in plates(of: cards)
        where named.map({ $0.contains(where: plate.contains) }) ?? true {
            let tiny = plate.contains { cards[$0]["card"] == .string("tiny") }
            let unfit = tiny ? #"["tiny"]"# : "[]"
            let placements = plate.map(String.init).joined(separator: ", ")
            layers.append(
                #"{"kind": "plate", "placements": [\#(placements)], "rect": [0, 0, 1, 1], "#
                    + #""unfit": \#(unfit), "bytes": 4}"#)
            payload.append(Data([10, 20, 30, 255]))
        }
        let noticeField = notice.map { #""\#($0)""# } ?? "null"
        let list = layers.joined(separator: ", ")
        return .answer(
            #"{"ok": true, "notice": \#(noticeField), "layers": [\#(list)]}"#, payload: payload)
    }

    /// Each plate as the placement indices it holds: a card in no group alone, a group together.
    private static func plates(of cards: [JSONValue]) -> [[Int]] {
        var groups: [String: [Int]] = [:]
        var plates: [[Int]] = []
        for (index, card) in cards.enumerated() {
            if let group = card["group"]?.stringValue {
                groups[group, default: []].append(index)
            } else {
                plates.append([index])
            }
        }
        return plates + groups.keys.sorted().compactMap { groups[$0] }
    }
}

/// A rendering of a three-card scene, its scripted helper, and the queue that reaches it.
@MainActor
struct RenderingFixture {
    private static let doc =
        #"{"grid": {"cols": 64, "rows": 36}, "cards": ["#
        + #"{"card": "meter", "col": 0, "row": 0, "colspan": 8, "rowspan": 8},"#
        + #"{"card": "waveform", "col": 8, "row": 0, "colspan": 8, "rowspan": 8},"#
        + #"{"card": "tiny", "col": 30, "row": 0, "colspan": 4, "rowspan": 4}]}"#

    let rendering: SceneRendering
    let launcher: ScriptedLauncher
    let queue: RenderQueue

    init(
        displayKnown: Bool = true,
        _ script: @escaping @Sendable (JSONValue) -> ScriptedReply = { FakeRender.reply(to: $0) }
    ) throws {
        let document = SceneDocument(
            id: "s", name: "S", builtIn: false, fixed: false,
            doc: try JSONDecoder().decode(JSONValue.self, from: Data(Self.doc.utf8)))
        let scene = try LaidOutScene(document, defaultGrid: CellSize(cols: 64, rows: 36))
        launcher = ScriptedLauncher(script)
        rendering = SceneRendering(
            scene: scene, context: RenderRequestTests.context, displayKnown: displayKnown)
        queue = RenderQueue(helper: RenderHelper(launcher: launcher))
    }

    var layout: SceneLayout { rendering.scene.layout }
}

/// `scene-rendering`: the first drawing, what an edit draws again, and what the canvas says.
@MainActor
struct SceneRenderingTests {
    @Test func nothingIsDrawnUntilTheRendererIsReady() throws {
        let fixture = try RenderingFixture()
        #expect(fixture.rendering.status == .waiting)
        #expect(fixture.rendering.showsBoxes)
        #expect(fixture.rendering.messages == ["The renderer is starting."])
        #expect(fixture.launcher.requests.isEmpty)
    }

    @Test func theFirstDrawingHoldsTheBackdropAndEveryPlate() async throws {
        let fixture = try RenderingFixture()
        await fixture.rendering.attach(fixture.queue)
        #expect(fixture.rendering.status == .drawn)
        #expect(fixture.rendering.backdrop != nil)
        #expect(fixture.rendering.plates.count == 3)
        #expect(fixture.launcher.requests.count == 1)
        #expect(fixture.launcher.requests.first?["backdrop"] == .bool(true))
        #expect(fixture.rendering.unfit == ["tiny"])
    }

    @Test func aMoveDrawsOnlyTheMovedPlate() async throws {
        let fixture = try RenderingFixture()
        await fixture.rendering.attach(fixture.queue)
        let last = try #require(fixture.layout.cards.last)
        await fixture.rendering.show(
            try fixture.layout.moving([last.id], by: CellOffset(cols: 4, rows: 0)))
        #expect(fixture.launcher.requests.count == 2)
        let request = try #require(fixture.launcher.requests.last)
        #expect(request["plates"] == .array([.integer(2)]))
        #expect(request["backdrop"] == .bool(false))
        let moved = fixture.rendering.plates[[last.id]]?.cells
        #expect(moved == CellRect(col: 34, row: 0, cols: 4, rows: 4))
        #expect(fixture.rendering.plates.count == 3)
    }

    @Test func aDeleteSendsNoRequest() async throws {
        let fixture = try RenderingFixture()
        await fixture.rendering.attach(fixture.queue)
        let gone = try #require(fixture.layout.cards.first)
        await fixture.rendering.show(fixture.layout.removing([gone.id]))
        #expect(fixture.launcher.requests.count == 1)
        #expect(fixture.rendering.plates[[gone.id]] == nil)
        #expect(fixture.rendering.plates.count == 2)
    }

    @Test func groupingDrawsOneLayerForTheGroup() async throws {
        let fixture = try RenderingFixture()
        await fixture.rendering.attach(fixture.queue)
        let pair = Set(fixture.layout.cards.prefix(2).map(\.id))
        await fixture.rendering.show(try fixture.layout.grouping(pair))
        #expect(fixture.launcher.requests.count == 2)
        #expect(fixture.rendering.plates[pair] != nil)
        #expect(fixture.rendering.plates.count == 2)
    }

    @Test func aRefusedSceneIsBoxesWithTheReason() async throws {
        let reason = "names a card that does not exist"
        let fixture = try RenderingFixture { request in
            request["op"] == .string("render")
                ? .answer(#"{"ok": false, "refused": "\#(reason)"}"#)
                : FakeRender.reply(to: request)
        }
        await fixture.rendering.attach(fixture.queue)
        #expect(fixture.rendering.status == .refused(reason))
        #expect(fixture.rendering.showsBoxes)
        #expect(fixture.rendering.messages.first?.hasSuffix(reason) == true)
    }

    @Test func aHelperThatEndsIsBoxesThenStartsAgain() async throws {
        let first = AtomicFlag()
        let fixture = try RenderingFixture { request in
            first.setOnce() ? .end : FakeRender.reply(to: request)
        }
        await fixture.rendering.attach(fixture.queue)
        #expect(fixture.rendering.status == .failed)
        #expect(fixture.rendering.showsBoxes)
        await fixture.rendering.show(fixture.layout)
        #expect(fixture.rendering.status == .drawn)
        #expect(fixture.launcher.launches == 2)
    }

    @Test func aMissingImageIsSaid() async throws {
        let fixture = try RenderingFixture {
            FakeRender.reply(to: $0, notice: "BACKDROP IMAGE MISSING")
        }
        await fixture.rendering.attach(fixture.queue)
        let missing = "The backdrop image is missing, so the default is shown."
        #expect(fixture.rendering.messages.contains(missing))
    }

    @Test func aStandInSizeAndTheCardsTooSmallAreSaid() async throws {
        let fixture = try RenderingFixture(displayKnown: false)
        await fixture.rendering.attach(fixture.queue)
        #expect(
            fixture.rendering.messages == [
                "The panel's display size isn't known, so this is drawn at 1920 by 720.",
                "Too small to show its reading: tiny.",
            ])
    }

    @Test func noRendererIsSaid() throws {
        let fixture = try RenderingFixture()
        fixture.rendering.unavailable("This build carries no renderer.")
        #expect(fixture.rendering.status == .noRenderer("This build carries no renderer."))
        #expect(fixture.rendering.messages == ["This build carries no renderer."])
    }
}

/// A flag set by the first caller to ask, so a script can fail only its first request.
final class AtomicFlag: Sendable {
    private let state = Mutex(false)

    /// True for the first call only.
    func setOnce() -> Bool {
        state.withLock { wasSet in
            defer { wasSet = true }
            return !wasSet
        }
    }
}
