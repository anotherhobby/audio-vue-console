import Foundation
import HostAPI
import OpenAPIRuntime

/// A scene as the host lists it.
public struct SceneSummary: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String?
    public let builtIn: Bool
    /// A built-in for a process, the calibration scene: not offered to pick or duplicate.
    public let fixed: Bool

    public init(id: String, name: String?, builtIn: Bool, fixed: Bool) {
        self.id = id
        self.name = name
        self.builtIn = builtIn
        self.fixed = fixed
    }
}

/// The host's scenes, install settings, settings schema and images, each read with a token.
extension HostClient {
    /// `GET /v1/scenes`: every scene the host holds, built in or stored.
    public func scenes(at address: HostAddress, token: HostToken) async throws(HostFailure)
        -> [SceneSummary]
    {
        let output = try await call(at: address, token: token) { try await $0.listingV1ScenesGet() }
        guard case .ok(let ok) = output else { throw .unexpectedAnswer }
        return try Self.body { try ok.body.json }.scenes.map {
            SceneSummary(id: $0.id, name: $0.name, builtIn: $0.builtIn, fixed: $0.fixed ?? false)
        }
    }

    /// `GET /v1/scenes/{scene_id}`: one scene, its document as the host's store holds it.
    public func scene(_ id: String, at address: HostAddress, token: HostToken)
        async throws(HostFailure) -> SceneDocument
    {
        let output = try await call(at: address, token: token) {
            try await $0.readSceneV1ScenesSceneIdGet(path: .init(sceneId: id))
        }
        switch output {
        case .ok(let ok):
            let body = try Self.body { try ok.body.json }
            return SceneDocument(
                id: body.id, name: body.name, builtIn: body.builtIn, fixed: body.fixed ?? false,
                doc: try Self.json(body.doc))
        case .notFound: throw .notFound
        case .unauthorized, .unprocessableContent, .undocumented: throw .unexpectedAnswer
        }
    }

    /// `GET /v1/install`: each install block's document, by the block's name.
    public func install(at address: HostAddress, token: HostToken) async throws(HostFailure)
        -> [String: JSONValue]
    {
        let output = try await call(at: address, token: token) {
            try await $0.readInstallV1InstallGet()
        }
        guard case .ok(let ok) = output else { throw .unexpectedAnswer }
        var blocks: [String: JSONValue] = [:]
        for block in try Self.body({ try ok.body.json }).blocks {
            blocks[block.block] = try Self.json(block.doc)
        }
        return blocks
    }

    /// `GET /v1/schema`: the settings' declarations as JSON Schema, whole.
    public func schema(at address: HostAddress, token: HostToken) async throws(HostFailure)
        -> JSONValue
    {
        let output = try await call(at: address, token: token) { try await $0.schemaV1SchemaGet() }
        guard case .ok(let ok) = output else { throw .unexpectedAnswer }
        return try Self.json(try Self.body { try ok.body.json })
    }

    /// `GET /v1/images/{image_id}`: an image's bytes, PNG or JPEG.
    public func image(_ id: String, at address: HostAddress, token: HostToken)
        async throws(HostFailure) -> Data
    {
        let output = try await call(at: address, token: token) {
            try await $0.imageV1ImagesImageIdGet(path: .init(imageId: id))
        }
        switch output {
        case .ok(let ok):
            let body: HTTPBody =
                switch ok.body {
                case .png(let png): png
                case .jpeg(let jpeg): jpeg
                }
            return try await Self.bytes(of: body)
        case .notFound: throw .notFound
        case .unauthorized, .unprocessableContent, .undocumented: throw .unexpectedAnswer
        }
    }

    /// The largest image the app takes, 64 MiB, well over any backdrop a panel shows.
    static let imageLimit = 67_108_864

    private static func bytes(of body: HTTPBody) async throws(HostFailure) -> Data {
        do {
            return try await Data(collecting: body, upTo: imageLimit)
        } catch {
            throw .unexpectedAnswer
        }
    }

    /// A container the generated client decoded, read as JSON.
    static func json(_ container: some Encodable) throws(HostFailure) -> JSONValue {
        do {
            return try JSONValue(container)
        } catch {
            throw .unexpectedAnswer
        }
    }
}
