import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Why a still or a clip could not be written.
public enum ExportFailure: Error, Sendable, Equatable, CustomStringConvertible {
    /// The picture could not be made into an image.
    case unusablePicture
    /// The file could not be written, and why.
    case failed(String)
    /// The user stopped it.
    case cancelled

    public var description: String {
        switch self {
        case .unusablePicture: "The renderer's picture could not be made into an image."
        case .failed(let reason): "The file could not be written. \(reason)"
        case .cancelled: "The export was cancelled."
        }
    }
}

extension TrackPicture {
    private static let bitsPerComponent = 8

    /// The picture as an image: 8 bits a component, no alpha, sRGB, as the panel's pixels are.
    public var image: CGImage? {
        guard width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB),
            let provider = CGDataProvider(data: rgb as CFData)
        else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: Self.bitsPerComponent,
            bitsPerPixel: Self.bitsPerComponent * Self.bytesPerPixel,
            bytesPerRow: width * Self.bytesPerPixel, space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}

/// A still: a picture saved as a PNG at its own size (`track-render`, "A still is the picture at its
/// moment as a PNG" and "Export Image saves the scene as the canvas draws it"; design D6).
public enum StillWriter {
    public static func write(_ picture: TrackPicture, to url: URL) throws(ExportFailure) {
        guard let image = picture.image else { throw .unusablePicture }
        try write(image, to: url)
    }

    public static func write(_ image: CGImage, to url: URL) throws(ExportFailure) {
        guard
            let destination = CGImageDestinationCreateWithURL(
                url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw .failed("The destination could not be opened.") }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw .failed("The PNG could not be finished.")
        }
    }
}
