import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import ConsoleCore

/// `track-render`, "Export Image saves the scene as the canvas draws it".
@MainActor
struct SceneRenderingPictureTests {
    @Test func beforeTheSceneIsDrawnThereIsNoPicture() throws {
        let fixture = try RenderingFixture()
        #expect(fixture.rendering.picture == nil)
        #expect(fixture.rendering.pictureUnavailable == "The scene isn't drawn yet")
    }

    @Test func aDrawnSceneIsAPictureAtTheDisplaysSize() async throws {
        let fixture = try RenderingFixture()
        await fixture.rendering.attach(fixture.queue)
        let picture = try #require(fixture.rendering.picture)
        #expect(picture.width == RenderRequestTests.context.display.width)
        #expect(picture.height == RenderRequestTests.context.display.height)
        #expect(picture.bitsPerComponent == 16)
    }

    @Test func thePictureIsSavedAsASixteenBitPNG() async throws {
        let fixture = try RenderingFixture()
        await fixture.rendering.attach(fixture.queue)
        let directory = try TestTracks.directory()
        defer { DecodedTrack.discard(directory) }
        let url = directory.appending(path: "scene.png")
        try StillWriter.write(try #require(fixture.rendering.picture), to: url)
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let saved = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(saved.bitsPerComponent == 16)
        #expect(saved.width == RenderRequestTests.context.display.width)
    }
}
