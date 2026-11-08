import Foundation
import Testing

@testable import ConsoleCore

/// Design D7: a paired panel's scenes and what drawing them needs.
@MainActor
struct PanelScenesTests {
    private static let pairing = Pairing(hostID: "h1", token: HostToken("secret"), clientID: "c1")

    private static let schema =
        #"{"$defs": {"block.grid": {"properties": {"cols": {"default": 64}, "#
        + #""rows": {"default": 36}}}, "card.meter": {"x-min-cells": [8, 6], "x-placeable": true}}}"#

    static func answers(sceneStatus: Int = 200) -> [FakeTransport.Route: FakeTransport
        .Answer]
    {
        [
            .scenes: .status(
                200,
                #"{"scenes": [{"id": "default", "built_in": true}, "#
                    + #"{"id": "calibration", "built_in": true, "fixed": true}]}"#),
            .scene("default"): sceneStatus == 200
                ? .status(
                    200,
                    #"{"id": "default", "name": "Default", "built_in": true, "#
                        + #""doc": {"backdrop": {"image": "sky.png", "blur": 24}, "cards": []}}"#)
                : .status(sceneStatus, #"{"detail": "no scene"}"#),
            .scene("calibration"): .status(
                200,
                #"{"id": "calibration", "built_in": true, "fixed": true, "doc": {"cards": []}}"#),
            .install: .status(
                200,
                #"{"blocks": [{"block": "fonts", "rev": 1, "doc": {"value_px": 90.5}},"#
                    + #"{"block": "input", "rev": 0, "doc": {}}]}"#),
            .schema: .status(200, schema),
            .image("sky.png"): .status(200, "PNG", headers: ["Content-Type": "image/png"]),
        ]
    }

    static func scenes(
        _ transport: FakeTransport, host: HostIdentity? = nil,
        onUnpaired: @escaping @MainActor () -> Void = {}
    ) throws -> PanelScenes {
        PanelScenes(
            address: try #require(HostAddress(parsing: "audio-vue")), host: host,
            cards: CardCode(digest: "d", source: .panel), client: HostClient(transport: transport),
            access: (pairing, InMemoryTokenStore()),
            images: ImageStore(
                directory: FileManager.default.temporaryDirectory.appending(path: "\(UUID())"),
                client: HostClient(transport: transport)),
            onUnpaired: onUnpaired)
    }

    @Test func everythingIsLoaded() async throws {
        let transport = FakeTransport(Self.answers())
        let host = HostIdentity(id: "h1", name: "audio-vue", widthPx: 1920, heightPx: 720)
        let scenes = try Self.scenes(transport, host: host)
        await scenes.load()
        #expect(scenes.state == .loaded)
        #expect(scenes.scenes.map(\.id) == ["default"])
        #expect(scenes.facts?.placeable.map(\.name) == ["meter"])
        #expect(scenes.context.display == PixelSize(width: 1920, height: 720))
        #expect(scenes.context.fonts["value_px"] == .decimal(90.5))
        #expect(scenes.context.fallback["image"] == .string("sky.png"))
        let paths = await transport.requests.compactMap { $0.url?.path }
        #expect(paths.contains("/v1/images/sky.png"))
    }

    @Test func aPanelOfUnknownSizeIsDrawnAtTheStandIn() async throws {
        let scenes = try Self.scenes(FakeTransport(Self.answers()))
        #expect(scenes.display == nil)
        #expect(scenes.context.display == .unknownPanel)
    }

    @Test func aRefusedTokenUnpairs() async throws {
        var unpaired = false
        let scenes = try Self.scenes(
            FakeTransport([.scenes: .status(401, #"{"detail": "token"}"#)])
        ) {
            unpaired = true
        }
        await scenes.load()
        #expect(scenes.state == .unpaired)
        #expect(unpaired)
    }

    @Test func aSceneThatCannotBeReadFailsTheLoad() async throws {
        let scenes = try Self.scenes(FakeTransport(Self.answers(sceneStatus: 404)))
        await scenes.load()
        #expect(scenes.state == .failed(.notFound))
    }

    /// The stored scene "Mine" at `rev`: a meter with a setting of its own.
    static func mine(rev: Int, name: String = "Mine", col: Int = 0) -> FakeTransport.Answer {
        .status(
            200,
            #"{"id": "u1", "name": "\#(name)", "built_in": false, "rev": \#(rev), "doc": "#
                + #"{"name": "\#(name)", "grid": {"cols": 64, "rows": 36}, "cards": [{"card": "#
                + #""meter", "col": \#(col), "row": 0, "colspan": 8, "rowspan": 8, "peak": "hold"}]}}"#
        )
    }

    static let listingWithMine = FakeTransport.Answer.status(
        200,
        #"{"scenes": [{"id": "default", "built_in": true}, "#
            + #"{"id": "u1", "name": "Mine", "built_in": false, "rev": 3}]}"#)

    static let written =
        #"{"id": "u1", "rev": 4, "applies": "on_reload", "#
        + #""analysis_changed": false}"#

    /// Loaded scenes holding "Mine" at revision 3, and the transport they read.
    static func loadedWithMine() async throws -> (PanelScenes, FakeTransport) {
        var answers = Self.answers()
        answers[.scenes] = listingWithMine
        answers[.scene("u1")] = mine(rev: 3)
        let transport = FakeTransport(answers)
        let scenes = try Self.scenes(transport)
        await scenes.load()
        return (scenes, transport)
    }

    /// The draft of the scene `id` with its first card moved ten columns right.
    static func movedDraft(_ id: String, in scenes: PanelScenes, drafts: SceneDrafts)
        throws -> Draft
    {
        let document = try #require(scenes.scenes.first { $0.id == id })
        let draft = try drafts.draft(for: document, defaultGrid: CellSize(cols: 64, rows: 36))
        let card = try #require(draft.layout.cards.first)
        drafts.keep(try draft.layout.moving([card.id], by: CellOffset(cols: 10, rows: 0)), for: id)
        return try #require(drafts.draft(id))
    }

    static func sent(_ request: URLRequest?) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: try #require(request?.httpBody))
    }

    @Test func aSaveWritesOnTheHeldRevisionAndHoldsTheNext() async throws {
        let (scenes, transport) = try await Self.loadedWithMine()
        let draft = try Self.movedDraft("u1", in: scenes, drafts: SceneDrafts())
        await transport.answer(.writeScene("u1"), with: .status(200, Self.written))
        await transport.answer(.scene("u1"), with: Self.mine(rev: 4, col: 10))
        let saved = try await scenes.save(draft)
        #expect(saved.rev == 4)
        #expect(scenes.scenes.first { $0.id == "u1" }?.rev == 4)
        let body = try Self.sent(await transport.requests(to: .writeScene("u1")).first)
        #expect(body["base_rev"] == .integer(3))
        #expect(body["doc"]?["cards"]?.arrayValue?.first?["col"] == .integer(10))
        #expect(body["doc"]?["cards"]?.arrayValue?.first?["peak"] == .string("hold"))
    }

    @Test func aCopysSaveCreatesItAndListsTheNewID() async throws {
        let (scenes, transport) = try await Self.loadedWithMine()
        let drafts = SceneDrafts()
        let mine = try #require(scenes.scenes.last)
        let copy = drafts.duplicate(
            try drafts.draft(for: mine, defaultGrid: CellSize(cols: 64, rows: 36)),
            among: scenes.scenes)
        let created = #"{"id": "u2", "rev": 1, "applies": "on_reload", "analysis_changed": false}"#
        await transport.answer(.createScene, with: .status(201, created))
        await transport.answer(
            .scene("u2"),
            with: .status(
                200,
                #"{"id": "u2", "name": "Mine copy", "built_in": false, "rev": 1, "doc": {}}"#))
        await transport.answer(
            .scenes,
            with: .status(
                200,
                #"{"scenes": [{"id": "default", "built_in": true}, "#
                    + #"{"id": "u1", "name": "Mine", "built_in": false}, "#
                    + #"{"id": "u2", "name": "Mine copy", "built_in": false}]}"#))
        let saved = try await scenes.save(try #require(drafts.draft(copy.id)))
        #expect(saved.id == "u2")
        #expect(scenes.scenes.map(\.id) == ["default", "u1", "u2"])
        let body = try Self.sent(await transport.requests(to: .createScene).first)
        #expect(body["doc"]?["name"] == .string("Mine copy"))
    }

    @Test func aStaleSaveSaysTheCurrentRevisionAndCanSaveOverIt() async throws {
        let (scenes, transport) = try await Self.loadedWithMine()
        let draft = try Self.movedDraft("u1", in: scenes, drafts: SceneDrafts())
        await transport.answer(
            .writeScene("u1"), with: .status(409, #"{"detail": "moved on", "current_rev": 4}"#))
        await #expect(throws: HostFailure.stale(currentRev: 4)) {
            _ = try await scenes.save(draft)
        }
        #expect(scenes.state == .loaded)
        await transport.answer(.writeScene("u1"), with: .status(200, Self.written))
        await transport.answer(.scene("u1"), with: Self.mine(rev: 5, col: 10))
        _ = try await scenes.save(draft, overRev: 4)
        let body = try Self.sent(await transport.requests(to: .writeScene("u1")).last)
        #expect(body["base_rev"] == .integer(4))
    }

    @Test func aRenameWritesTheHostsDocumentNotTheDraft() async throws {
        let (scenes, transport) = try await Self.loadedWithMine()
        _ = try Self.movedDraft("u1", in: scenes, drafts: SceneDrafts())
        await transport.answer(.writeScene("u1"), with: .status(200, Self.written))
        await transport.answer(.scene("u1"), with: Self.mine(rev: 4, name: "Studio"))
        let renamed = try await scenes.rename("u1", to: "  Studio ")
        #expect(renamed.name == "Studio")
        let body = try Self.sent(await transport.requests(to: .writeScene("u1")).first)
        #expect(body["doc"]?["name"] == .string("Studio"))
        #expect(body["doc"]?["cards"]?.arrayValue?.first?["col"] == .integer(0))
        #expect(body["base_rev"] == .integer(3))
    }

    @Test func aStaleRenameIsReadAgainAndWrittenOnce() async throws {
        let (scenes, transport) = try await Self.loadedWithMine()
        await transport.answer(
            .writeScene("u1"), with: .status(409, #"{"detail": "moved on", "current_rev": 4}"#))
        await transport.answer(.scene("u1"), with: Self.mine(rev: 4, col: 20))
        await #expect(throws: HostFailure.stale(currentRev: 4)) {
            _ = try await scenes.rename("u1", to: "Studio")
        }
        let writes = await transport.requests(to: .writeScene("u1"))
        #expect(writes.count == 2)
        let retry = try Self.sent(writes.last)
        #expect(retry["base_rev"] == .integer(4))
        #expect(retry["doc"]?["cards"]?.arrayValue?.first?["col"] == .integer(20))
    }

    @Test func anEmptyNameIsRefusedWithNoRequest() async throws {
        let (scenes, transport) = try await Self.loadedWithMine()
        let before = await transport.requests.count
        let refusal = HostFailure.invalid([
            DocumentFailure(place: "name", message: PanelScenes.needsAName)
        ])
        await #expect(throws: refusal) {
            _ = try await scenes.rename("u1", to: "   ")
        }
        #expect(await transport.requests.count == before)
    }

    @Test func aRefusedDeleteKeepsTheScene() async throws {
        let (scenes, transport) = try await Self.loadedWithMine()
        await transport.answer(
            .deleteScene("u1"), with: .status(409, #"{"detail": "the scene is on screen"}"#))
        await #expect(throws: HostFailure.conflict("the scene is on screen")) {
            try await scenes.delete("u1")
        }
        #expect(scenes.scenes.map(\.id) == ["default", "u1"])
        await transport.answer(.deleteScene("u1"), with: .status(204, ""))
        try await scenes.delete("u1")
        #expect(scenes.scenes.map(\.id) == ["default"])
    }

    @Test func theCardCodeIsComparedOnlyWhenTheDigestsDiffer() async throws {
        let transport = FakeTransport(Self.answers())
        let scenes = try Self.scenes(transport)
        let bundled = CardManifest(digest: "d", entries: [:])
        #expect(await scenes.cardCode(helperDigest: "d", bundled: bundled) == .same)
        #expect(await transport.requests.isEmpty)
    }
}
