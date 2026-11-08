import Foundation
import Testing

@testable import ConsoleCore

/// Design D7: the scene, install, schema and image reads, each with the token.
struct HostClientScenesTests {
    private let token = HostToken("secret")

    private func address() throws -> HostAddress {
        try #require(HostAddress(parsing: "audio-vue"))
    }

    @Test func theScenesAreListed() async throws {
        let body =
            #"{"scenes": [{"id": "default", "name": "Default", "built_in": true},"#
            + #"{"id": "calibration", "built_in": true, "fixed": true},"#
            + #"{"id": "mine", "name": "Mine", "built_in": false, "rev": 3}]}"#
        let transport = FakeTransport([.scenes: .status(200, body)])
        let scenes = try await HostClient(transport: transport).scenes(
            at: try address(), token: token)
        #expect(scenes.map(\.id) == ["default", "calibration", "mine"])
        #expect(
            scenes[0] == SceneSummary(id: "default", name: "Default", builtIn: true, fixed: false))
        #expect(scenes[1].fixed)
        #expect(scenes[2].builtIn == false)
        let request = try #require(await transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    }

    @Test func aSceneIsReadWithItsDocument() async throws {
        let body =
            #"{"id": "rta", "name": "RTA", "built_in": true, "rev": null, "#
            + #""doc": {"grid": {"cols": 96, "rows": 36}, "cards": [{"card": "rta_bars", "col": 0}]}}"#
        let transport = FakeTransport([.scene("rta"): .status(200, body)])
        let scene = try await HostClient(transport: transport).scene(
            "rta", at: try address(), token: token)
        #expect(scene.name == "RTA")
        #expect(scene.builtIn && !scene.fixed)
        #expect(scene.doc["grid"]?["cols"] == .integer(96))
        #expect(scene.doc["cards"]?.arrayValue?.first?["card"] == .string("rta_bars"))
        #expect(scene.rev == nil)
    }

    @Test func aStoredSceneIsReadWithItsRevision() async throws {
        let body = #"{"id": "u1", "name": "Mine", "built_in": false, "rev": 3, "doc": {}}"#
        let transport = FakeTransport([.scene("u1"): .status(200, body)])
        let scene = try await HostClient(transport: transport).scene(
            "u1", at: try address(), token: token)
        #expect(scene.rev == 3)
    }

    @Test func aSceneTheHostLacks() async throws {
        let transport = FakeTransport([.scene("gone"): .status(404, #"{"detail": "no scene"}"#)])
        await #expect(throws: HostFailure.notFound) {
            _ = try await HostClient(transport: transport).scene(
                "gone", at: try address(), token: token)
        }
    }

    @Test func aScenesRevisionsAreReadNewestFirst() async throws {
        let body =
            #"{"revisions": [{"rev": 4, "saved_at": "2026-11-07T21:00:05+00:00", "doc": {"a": 1}},"#
            + #"{"rev": 3, "saved_at": "2026-11-06T09:30:00+00:00", "doc": {"a": 0}}]}"#
        let transport = FakeTransport([.revisions("u1"): .status(200, body)])
        let revisions = try await HostClient(transport: transport).sceneRevisions(
            "u1", at: try address(), token: token)
        #expect(revisions.map(\.rev) == [4, 3])
        #expect(revisions.first?.savedAt == Date(timeIntervalSince1970: 1_794_085_205))
        #expect(revisions.last?.doc["a"] == .integer(0))
    }

    @Test func aBuiltInKeepsNoRevisions() async throws {
        let transport = FakeTransport([.revisions("rta"): .status(200, #"{"revisions": []}"#)])
        let revisions = try await HostClient(transport: transport).sceneRevisions(
            "rta", at: try address(), token: token)
        #expect(revisions.isEmpty)
    }

    @Test func theInstallBlocksAreReadByName() async throws {
        let body =
            #"{"blocks": [{"block": "fonts", "rev": 0, "doc": {"value_px": 80.0}},"#
            + #"{"block": "input", "rev": 2, "doc": {"rate": 96000}}]}"#
        let transport = FakeTransport([.install: .status(200, body)])
        let blocks = try await HostClient(transport: transport).install(
            at: try address(), token: token)
        #expect(blocks["fonts"]?["value_px"] == .integer(80))
        #expect(blocks["input"]?["rate"] == .integer(96000))
    }

    @Test func theSchemaIsReadWhole() async throws {
        let body = #"{"x-schema-version": 4, "$defs": {"card.logo": {"x-placeable": true}}}"#
        let transport = FakeTransport([.schema: .status(200, body)])
        let schema = try await HostClient(transport: transport).schema(
            at: try address(), token: token)
        #expect(schema["$defs"]?["card.logo"]?["x-placeable"] == .bool(true))
    }

    @Test func anImageIsReadAsBytes() async throws {
        let transport = FakeTransport([
            .image("sky.png"): .status(200, "PNGBYTES", headers: ["Content-Type": "image/png"])
        ])
        let bytes = try await HostClient(transport: transport).image(
            "sky.png", at: try address(), token: token)
        #expect(bytes == Data("PNGBYTES".utf8))
    }

    @Test func anImageTheHostLacks() async throws {
        let transport = FakeTransport([
            .image("gone.png"): .status(404, #"{"detail": "no image"}"#)
        ])
        await #expect(throws: HostFailure.notFound) {
            _ = try await HostClient(transport: transport).image(
                "gone.png", at: try address(), token: token)
        }
    }
}
