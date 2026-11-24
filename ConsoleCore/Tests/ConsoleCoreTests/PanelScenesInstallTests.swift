import Foundation
import Testing

@testable import ConsoleCore

/// `panel-display` and `track-native-logo` design D2: `PanelScenes` holds the install blocks with
/// their revisions and writes them, the app's one copy.
@MainActor
struct PanelScenesInstallTests {
    /// `panel-display`, "A scene shows the panel's idle settings as written": the display block is
    /// written on the revision held, and a scene's unset timeout takes the written value at once.
    @Test func anInstallWriteIsHeldForTheScenes() async throws {
        let transport = FakeTransport(PanelScenesTests.answers())
        let scenes = try PanelScenesTests.scenes(transport)
        await scenes.load()
        let after = SettingDeclaration(
            key: "saver_after_min",
            property: .object([
                "type": .string("number"), "x-inherits": .string("install.display"),
            ]))
        let facts = try #require(scenes.facts)
        #expect(
            facts.inheritedValue(of: after, scene: [:], installed: scenes.installed)
                == .integer(10))
        await transport.answer(
            .writeInstall("display"),
            with: .status(200, #"{"block": "display", "rev": 3, "applies": "on_start"}"#))
        let written = try await scenes.writeInstall(
            ["saver_after_min": .integer(2)], block: "display")
        #expect(written.applies == .onStart)
        #expect(
            facts.inheritedValue(of: after, scene: [:], installed: scenes.installed)
                == .integer(2))
        _ = try await scenes.writeInstall([:], block: "display")
        let bodies = try await transport.requests(to: .writeInstall("display")).map(
            PanelScenesTests.sent)
        #expect(bodies.map { $0["base_rev"] } == [.integer(2), .integer(3)])
        #expect(bodies.last?["doc"] == .object([:]))
    }

    /// `panel-display`, "Changed on another Mac": a stale write stores nothing, and the block is
    /// read again so the host's values are shown.
    @Test func aStaleInstallWriteHoldsTheHostsBlock() async throws {
        let transport = FakeTransport(PanelScenesTests.answers())
        let scenes = try PanelScenesTests.scenes(transport)
        await scenes.load()
        await transport.answer(
            .writeInstall("display"),
            with: .status(409, #"{"detail": "moved on", "current_rev": 4}"#))
        await transport.answer(
            .install,
            with: .status(
                200,
                #"{"blocks": [{"block": "display", "rev": 4, "doc": {"sleep_after_min": 30}}]}"#))
        await #expect(throws: HostFailure.stale(currentRev: 4)) {
            _ = try await scenes.writeInstall(["saver_after_min": .integer(2)], block: "display")
        }
        #expect(scenes.installed["display"] == .object(["sleep_after_min": .integer(30)]))
        #expect(scenes.state == .loaded)
    }
}
