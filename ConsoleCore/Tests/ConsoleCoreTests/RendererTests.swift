import Foundation
import Testing

@testable import ConsoleCore

/// `render-helper`, "The helper starts once the app is paired", and the phases Status shows.
@MainActor
struct RendererTests {
    @Test func nothingStartsUntilAsked() {
        let launcher = ScriptedLauncher { FakeRender.reply(to: $0) }
        let renderer = Renderer(launcher: launcher)
        #expect(renderer.phase == .idle)
        #expect(launcher.launches == 0)
    }

    @Test func startingAsksHelloThenPreparesAtThePreviewRate() async {
        let launcher = ScriptedLauncher { FakeRender.reply(to: $0) }
        let renderer = Renderer(launcher: launcher)
        await renderer.start()
        #expect(renderer.phase == .ready(digest: "d1"))
        #expect(renderer.queue != nil)
        #expect(launcher.requests.map { $0["op"] } == [.string("hello"), .string("prepare")])
        #expect(launcher.requests.last?["rate"] == .integer(48_000))
        #expect(launcher.requests.last?["analysis"] == .object([:]))
    }

    @Test func thePhasesWhileStarting() async throws {
        let launcher = ScriptedLauncher { request in
            request["op"] == .string("prepare")
                ? .held(#"{"ok": true, "runs": 1}"#) : FakeRender.reply(to: request)
        }
        let renderer = Renderer(launcher: launcher)
        let started = Task { await renderer.start() }
        for _ in 0..<200 where renderer.phase != .preparing {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(renderer.phase == .preparing)
        launcher.releaseHeld()
        await started.value
        #expect(renderer.phase == .ready(digest: "d1"))
    }

    @Test func aHelperThatEndsBeforeItsFirstRun() async {
        let launcher = ScriptedLauncher { request in
            request["op"] == .string("prepare") ? .end : FakeRender.reply(to: request)
        }
        let renderer = Renderer(launcher: launcher)
        await renderer.start()
        #expect(renderer.phase == .failed("The renderer stopped before its first frame."))
        #expect(renderer.queue == nil)
    }

    @Test func aBuildWithoutAHelperSaysWhy() async {
        let renderer = Renderer(
            launcher: nil, missing: HelperLocation.Missing.interpreter.description)
        await renderer.start()
        #expect(renderer.phase == .failed("This build carries no Python to run the renderer."))
    }

    @Test func aPreviewStartsNothing() async {
        let renderer = Renderer.app(environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"])
        await renderer.start()
        #expect(renderer.phase == .idle)
    }

    @Test func startingTwiceStartsOnce() async {
        let launcher = ScriptedLauncher { FakeRender.reply(to: $0) }
        let renderer = Renderer(launcher: launcher)
        await renderer.start()
        await renderer.start()
        #expect(launcher.requests.count == 2)
    }

    @Test func theCodeIsComparedOnceReadyAndForgotten() async throws {
        let launcher = ScriptedLauncher { FakeRender.reply(to: $0) }
        let renderer = Renderer(
            launcher: launcher, bundledManifest: CardManifest(digest: "d1", entries: [:]))
        let scenes = PanelScenes(
            address: try #require(HostAddress(parsing: "audio-vue")), host: nil,
            cards: CardCode(digest: "d1", source: .panel),
            client: HostClient(transport: FakeTransport([:])),
            access: (
                Pairing(hostID: "h", token: HostToken("t"), clientID: "c"), InMemoryTokenStore()
            ),
            images: ImageStore(), onUnpaired: {})
        await renderer.checkCode(with: scenes)
        #expect(renderer.verdict == nil)
        await renderer.start()
        await renderer.checkCode(with: scenes)
        #expect(renderer.verdict == .same)
        renderer.forgetCode()
        #expect(renderer.verdict == nil)
    }

    @Test func aManifestThatCannotBeReadIsUnreadable() async throws {
        let renderer = Renderer(
            launcher: ScriptedLauncher { FakeRender.reply(to: $0) },
            bundledManifest: CardManifest(digest: "d1", entries: [:]))
        let scenes = PanelScenes(
            address: try #require(HostAddress(parsing: "audio-vue")), host: nil,
            cards: CardCode(digest: "other", source: .panel),
            client: HostClient(
                transport: FakeTransport([.cardManifest: .status(200, #"{"digest": "x"}"#)])),
            access: (
                Pairing(hostID: "h", token: HostToken("t"), clientID: "c"), InMemoryTokenStore()
            ),
            images: ImageStore(), onUnpaired: {})
        await renderer.start()
        await renderer.checkCode(with: scenes)
        #expect(renderer.verdict == .unreadable)
    }
}
