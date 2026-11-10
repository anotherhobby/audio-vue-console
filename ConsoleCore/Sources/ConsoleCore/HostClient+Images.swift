import Foundation
import HostAPI
import OpenAPIRuntime

/// An image a scene's backdrop may name, as the host lists it (`scene-settings`, design D4).
public struct HostImage: Sendable, Equatable, Identifiable {
    /// What a scene names it by.
    public let id: String
    /// Whether it ships with audio-vue, rather than being uploaded.
    public let shipped: Bool
    /// Its size in bytes, where the host gives it.
    public let bytes: Int?
    /// Its size in pixels, where the host gives it.
    public let width: Int?
    public let height: Int?
    /// When it was uploaded, where the host gives it.
    public let addedAt: Date?

    public init(
        id: String, shipped: Bool, bytes: Int? = nil, width: Int? = nil, height: Int? = nil,
        addedAt: Date? = nil
    ) {
        self.id = id
        self.shipped = shipped
        self.bytes = bytes
        self.width = width
        self.height = height
        self.addedAt = addedAt
    }

    /// `images` as the picker lists them: shipped first, then uploads, newest first.
    public static func listed(_ images: [HostImage]) -> [HostImage] {
        images.filter(\.shipped)
            + images.filter { !$0.shipped }.sorted { first, second in
                (first.addedAt ?? .distantPast) > (second.addedAt ?? .distantPast)
            }
    }
}

/// The file types the host takes for an image.
public enum ImageType: Sendable, Equatable {
    case png
    case jpeg
}

/// Why the host refused an upload, with its own words for it.
public enum ImageRefusal: Sendable, Equatable, CustomStringConvertible {
    /// 413: over the host's size limit.
    case tooLarge(String)
    /// 415: not a PNG or a JPEG.
    case notPNGOrJPEG(String)
    /// 422: the host could not read it as an image it takes.
    case unreadable(String)

    public var description: String {
        switch self {
        case .tooLarge(let detail): "The image is too large for the host. \(detail)"
        case .notPNGOrJPEG(let detail): "The host takes only PNG and JPEG images. \(detail)"
        case .unreadable(let detail): "The host couldn't read the image. \(detail)"
        }
    }
}

/// The host's backdrop images, listed and uploaded with a token.
extension HostClient {
    /// `GET /v1/images`: every image a scene may name, uploads and shipped ones.
    public func images(at address: HostAddress, token: HostToken) async throws(HostFailure)
        -> [HostImage]
    {
        let output = try await call(at: address, token: token) {
            try await $0.imagesListedV1ImagesGet()
        }
        guard case .ok(let ok) = output else { throw .unexpectedAnswer }
        return try Self.body { try ok.body.json }.images.map {
            HostImage(
                id: $0.id, shipped: $0.shipped, bytes: $0.bytes, width: $0.width,
                height: $0.height, addedAt: $0.addedAt.flatMap(Self.date))
        }
    }

    /// `POST /v1/images`: uploads `data`, the file's bytes untouched, as `type`, and answers the
    /// id the host stores it by.
    public func upload(_ data: Data, type: ImageType, at address: HostAddress, token: HostToken)
        async throws(HostFailure) -> String
    {
        let body: Operations.UploadV1ImagesPost.Input.Body =
            switch type {
            case .png: .png(HTTPBody(data))
            case .jpeg: .jpeg(HTTPBody(data))
            }
        let output = try await call(at: address, token: token) {
            try await $0.uploadV1ImagesPost(body: body)
        }
        switch output {
        case .created(let created): return try Self.body { try created.body.json }.id
        case .contentTooLarge(let refused):
            throw .imageRefused(.tooLarge(try Self.body { try refused.body.json }.detail))
        case .unsupportedMediaType(let refused):
            throw .imageRefused(.notPNGOrJPEG(try Self.body { try refused.body.json }.detail))
        case .unprocessableContent(let refused):
            throw .imageRefused(.unreadable(try Self.body { try refused.body.json }.detail))
        case .unauthorized, .undocumented: throw .unexpectedAnswer
        }
    }
}
