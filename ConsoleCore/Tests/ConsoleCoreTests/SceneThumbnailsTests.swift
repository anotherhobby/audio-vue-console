import Foundation
import Testing

@testable import ConsoleCore

/// `scene-gallery`, "A thumbnail is the scene as the helper draws it".
@MainActor
struct SceneThumbnailsTests {
    @Test func eachSceneIsDrawnOnceInTheThumbnailsLane() async throws {
        let fixture = try RenderingFixture()
        let thumbnails = SceneThumbnails()
        let scene = fixture.rendering.scene
        await thumbnails.draw(
            [(scene, scene.layout)], context: RenderRequestTests.context, through: fixture.queue)
        await thumbnails.draw(
            [(scene, scene.layout)], context: RenderRequestTests.context, through: fixture.queue)
        let image = try #require(thumbnails.images["s"])
        #expect(image.width == SceneThumbnails.width)
        #expect(fixture.launcher.requests.count == 1)
    }

    @Test func aSceneTheHelperRefusesKeepsItsBoxes() async throws {
        let fixture = try RenderingFixture { request in
            request["op"] == .string("render")
                ? .answer(#"{"ok": false, "refused": "no"}"#) : FakeRender.reply(to: request)
        }
        let thumbnails = SceneThumbnails()
        let scene = fixture.rendering.scene
        await thumbnails.draw(
            [(scene, scene.layout)], context: RenderRequestTests.context, through: fixture.queue)
        #expect(thumbnails.images.isEmpty)
    }

    @Test func aSavedCopysThumbnailMovesToItsNewID() async throws {
        let fixture = try RenderingFixture()
        await fixture.rendering.attach(fixture.queue)
        let thumbnails = SceneThumbnails()
        thumbnails.update("copy-1", from: fixture.rendering)
        thumbnails.move(from: "copy-1", to: "u2")
        #expect(thumbnails.images["copy-1"] == nil)
        #expect(thumbnails.images["u2"] != nil)
    }

    @Test func theOpenScenesThumbnailFollowsItsLayers() async throws {
        let fixture = try RenderingFixture()
        await fixture.rendering.attach(fixture.queue)
        let thumbnails = SceneThumbnails()
        thumbnails.update("s", from: fixture.rendering)
        #expect(thumbnails.images["s"] != nil)
    }
}
