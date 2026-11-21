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
            [(scene, scene.content)], context: RenderRequestTests.context, through: fixture.queue)
        await thumbnails.draw(
            [(scene, scene.content)], context: RenderRequestTests.context, through: fixture.queue)
        let image = try #require(thumbnails.images["s"])
        #expect(image.width == SceneThumbnails.width)
        #expect(fixture.launcher.requests.count == 1)
    }

    /// `scene-gallery`, "A new scene is the app's alone until it holds a card".
    @Test func aSceneWithNoCardsIsNotAskedFor() async throws {
        let fixture = try RenderingFixture()
        let drafts = SceneDrafts()
        let new = try drafts.new(on: CellSize(cols: 96, rows: 36), among: [])
        let draft = try #require(drafts.draft(new.id))
        await SceneThumbnails().draw(
            [(draft.laidOut, draft.content)], context: RenderRequestTests.context,
            through: fixture.queue)
        #expect(fixture.launcher.requests.isEmpty)
    }

    /// `scene-rendering`, "A scene too wide is drawn as boxes".
    @Test func aSceneTooWideIsNotAskedFor() async throws {
        let fixture = try RenderingFixture()
        let doc: JSONValue = .object([
            "name": .string("Wide"),
            "cards": .array([
                .object([
                    "card": .string("meter"), "col": .integer(80), "colspan": .integer(16),
                    "rowspan": .integer(8),
                ])
            ]),
        ])
        let wide = try LaidOutScene(
            SceneDocument(id: "w", name: "Wide", builtIn: false, fixed: false, doc: doc),
            panel: CellSize(cols: 64, rows: 36))
        await SceneThumbnails().draw(
            [(wide, wide.content)], context: RenderRequestTests.context, through: fixture.queue)
        #expect(fixture.launcher.requests.isEmpty)
    }

    /// `scene-rendering`, "Scenes and tiles are drawn ahead": a thumbnail drawn once is shown at
    /// the next launch with no request, and not for a scene or card code that has changed.
    @Test func aKeptThumbnailIsShownAtTheNextLaunchWithNoRequest() async throws {
        let fixture = try RenderingFixture()
        let scene = fixture.rendering.scene
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let cache = ThumbnailCache(directory: folder, digest: "c0de")
        await SceneThumbnails().draw(
            [(scene, scene.content)], context: RenderRequestTests.context, through: fixture.queue,
            keeping: cache)
        let sent = fixture.launcher.requests.count

        let next = SceneThumbnails()
        next.restore([(scene, scene.content)], context: RenderRequestTests.context, from: cache)
        #expect(next.images["s"]?.width == SceneThumbnails.width)
        #expect(fixture.launcher.requests.count == sent)

        // Other card code finds no thumbnail, and clears the folder of the old code's.
        let other = SceneThumbnails()
        other.restore(
            [(scene, scene.content)], context: RenderRequestTests.context,
            from: ThumbnailCache(directory: folder, digest: "0ther"))
        #expect(other.images.isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
        try FileManager.default.removeItem(at: folder)
    }

    @Test func aSceneTheHelperRefusesKeepsItsBoxes() async throws {
        let fixture = try RenderingFixture { request in
            request["op"] == .string("render")
                ? .answer(#"{"ok": false, "refused": "no"}"#) : FakeRender.reply(to: request)
        }
        let thumbnails = SceneThumbnails()
        let scene = fixture.rendering.scene
        await thumbnails.draw(
            [(scene, scene.content)], context: RenderRequestTests.context, through: fixture.queue)
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
