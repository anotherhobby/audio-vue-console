import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

/// The gallery's thumbnails kept on disk between launches, so the gallery shows them before the
/// helper has started (`scene-rendering`, "Scenes and tiles are drawn ahead"). A thumbnail is
/// filed under a digest of everything it was drawn from: its render request, which holds the
/// scene, the display, the viewing and the styles, and the card code's digest. A scene or code
/// that has changed finds no file and is drawn again.
public struct ThumbnailCache: Sendable {
    public let directory: URL
    /// The digest of the card code the panel draws with.
    public let digest: String

    public init(
        directory: URL = URL.cachesDirectory.appending(path: "SceneThumbnails"), digest: String
    ) {
        self.directory = directory
        self.digest = digest
    }

    /// The file holding what `request` draws, or nil where the request cannot be written out.
    func file(for request: RenderRequest) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let message: Data
        do {
            message = try encoder.encode(request.message)
        } catch {
            return nil
        }
        var hash = SHA256()
        hash.update(data: message)
        hash.update(data: Data(digest.utf8))
        let name = hash.finalize().map { String(format: "%02x", $0) }.joined()
        return directory.appending(path: "\(name).png")
    }

    /// The thumbnail in `file`, or nil where none is kept or it cannot be read.
    func image(at file: URL) -> CGImage? {
        CGImageSourceCreateWithURL(file as CFURL, nil).flatMap {
            CGImageSourceCreateImageAtIndex($0, 0, nil)
        }
    }

    /// Keeps `image` in `file`. A thumbnail that cannot be written is drawn again next launch.
    func keep(_ image: CGImage, in file: URL) {
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
        } catch {
            return
        }
        guard
            let destination = CGImageDestinationCreateWithURL(
                file as CFURL, Self.png as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }

    /// Removes every kept thumbnail but those named in `names`, so the folder holds only the
    /// scenes the panel has now.
    func prune(keeping names: Set<String>) {
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil)
        } catch {
            return
        }
        for file in files where !names.contains(file.lastPathComponent) {
            do {
                try FileManager.default.removeItem(at: file)
            } catch {
                continue
            }
        }
    }

    private static let png = "public.png"
}
