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

    private static func answers(sceneStatus: Int = 200) -> [FakeTransport.Route: FakeTransport
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

    private static func scenes(
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

    @Test func theCardCodeIsComparedOnlyWhenTheDigestsDiffer() async throws {
        let transport = FakeTransport(Self.answers())
        let scenes = try Self.scenes(transport)
        let bundled = CardManifest(digest: "d", entries: [:])
        #expect(await scenes.cardCode(helperDigest: "d", bundled: bundled) == .same)
        #expect(await transport.requests.isEmpty)
    }
}
