import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import ConsoleCore

/// `track-render`, "A still is the picture at its moment as a PNG".
struct StillWriterTests {
    /// Red, green, blue, white along the top; black, grey, yellow, cyan along the bottom.
    private static let colours: [[UInt8]] = [
        [255, 0, 0], [0, 255, 0], [0, 0, 255], [255, 255, 255],
        [0, 0, 0], [128, 128, 128], [255, 255, 0], [0, 255, 255],
    ]

    @Test func aStillIsThePicturePixelForPixel() throws {
        let picture = TrackPicture(
            width: 4, height: 2, drawn: 0, rgb: Data(Self.colours.flatMap { $0 }))
        let directory = try TestTracks.directory()
        defer { DecodedTrack.discard(directory) }
        let url = directory.appending(path: "still.png")
        try StillWriter.write(picture, to: url)

        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 4)
        #expect(image.height == 2)
        #expect(try Self.rgb(of: image) == Self.colours)
    }

    @Test func aPictureOfNoSizeIsRefused() {
        let picture = TrackPicture(width: 0, height: 0, drawn: 0, rgb: Data())
        #expect(throws: ExportFailure.unusablePicture) {
            try StillWriter.write(picture, to: URL(filePath: "/tmp/never.png"))
        }
    }

    /// Each pixel of `image`, top row first, drawn into sRGB RGBA and read back without alpha.
    private static func rgb(of image: CGImage) throws -> [[UInt8]] {
        let bytesPerPixel = 4
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * bytesPerPixel)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        bytes.withUnsafeMutableBytes { raw in
            let context = CGContext(
                data: raw.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * bytesPerPixel, space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return stride(from: 0, to: bytes.count, by: bytesPerPixel).map {
            Array(bytes[$0..<$0 + 3])
        }
    }
}
