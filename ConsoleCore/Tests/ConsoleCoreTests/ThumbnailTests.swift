import CoreGraphics
import Foundation
import Testing

@testable import ConsoleCore

/// `scene-gallery`: layers stacked premultiplied "over", as audio-vue's `scene_layers.stack` does.
struct ThumbnailTests {
    private static func layer(_ kind: RenderedLayer.Kind, _ pixel: [UInt8], at rect: CGRect)
        throws -> RenderedLayer
    {
        let count = Int(rect.width * rect.height)
        let bytes = Data((0..<count).flatMap { _ in pixel })
        let image = try #require(
            RenderedLayer.image(bytes, width: Int(rect.width), height: Int(rect.height)))
        return RenderedLayer(kind: kind, cardIDs: [], rect: rect, unfit: [], image: image)
    }

    /// The RGBA of `image`'s pixel at `x`, `top`, counted from the top left.
    private static func pixel(_ image: CGImage, x: Int, top: Int) throws -> [Int] {
        let data = try #require(image.dataProvider?.data as Data?)
        let start = top * image.bytesPerRow + x * 4
        return data[start..<(start + 4)].map(Int.init)
    }

    @Test func aHalfAlphaLayerOverAnOpaqueOne() throws {
        let display = PixelSize(width: 2, height: 2)
        let backdrop = try Self.layer(
            .backdrop, [255, 0, 0, 255], at: CGRect(x: 0, y: 0, width: 2, height: 2))
        let plate = try Self.layer(
            .plate, [0, 0, 128, 128], at: CGRect(x: 1, y: 0, width: 1, height: 1))
        let image = try #require(
            Thumbnail.flatten(layers: [backdrop, plate], display: display, width: 2))
        // out = rgb + under * (1 - a / 255): 255 * (127 / 255) = 127 red, 128 blue.
        let over = try Self.pixel(image, x: 1, top: 0)
        #expect(abs(over[0] - 127) <= 1 && over[1] == 0 && abs(over[2] - 128) <= 1)
        #expect(try Self.pixel(image, x: 0, top: 0) == [255, 0, 0, 255])
        #expect(try Self.pixel(image, x: 1, top: 1) == [255, 0, 0, 255])
    }

    @Test func aThumbnailKeepsTheDisplaysShape() throws {
        let backdrop = try Self.layer(
            .backdrop, [0, 0, 0, 255], at: CGRect(x: 0, y: 0, width: 16, height: 6))
        let image = try #require(
            Thumbnail.flatten(
                layers: [backdrop], display: PixelSize(width: 16, height: 6), width: 8))
        #expect(image.width == 8 && image.height == 3)
    }
}
