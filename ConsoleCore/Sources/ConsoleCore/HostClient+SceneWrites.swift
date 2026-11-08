import Foundation
import HostAPI
import OpenAPIRuntime

/// The host's scene writes (`scene-saving`, design D2): create, write on a base revision, and
/// delete. A refusal comes back as the `HostFailure` the host's answer names.
extension HostClient {
    /// `POST /v1/scenes`: stores `doc` as a new scene, answering the id the host gave it and its
    /// first revision.
    public func createScene(doc: JSONValue, at address: HostAddress, token: HostToken)
        async throws(HostFailure) -> (id: String, rev: Int)
    {
        let body: Components.Schemas.NewScene = try Self.request(["doc": doc])
        let output = try await call(at: address, token: token) {
            try await $0.createV1ScenesPost(body: .json(body))
        }
        switch output {
        case .created(let created):
            let written = try Self.body { try created.body.json }
            return (written.id, written.rev)
        case .unprocessableContent(let invalid):
            throw Self.invalid(try Self.body { try invalid.body.json })
        case .unauthorized, .undocumented: throw .unexpectedAnswer
        }
    }

    /// `PUT /v1/scenes/{scene_id}`: stores `doc` as the scene's next revision, made from `baseRev`,
    /// answering the revision stored.
    public func writeScene(
        _ id: String, doc: JSONValue, baseRev: Int, at address: HostAddress, token: HostToken
    ) async throws(HostFailure) -> Int {
        let body: Components.Schemas.Edit = try Self.request([
            "doc": doc, "base_rev": .integer(baseRev),
        ])
        let output = try await call(at: address, token: token) {
            try await $0.writeSceneV1ScenesSceneIdPut(path: .init(sceneId: id), body: .json(body))
        }
        switch output {
        case .ok(let ok): return try Self.body { try ok.body.json }.rev
        case .conflict(let stale):
            throw .stale(currentRev: try Self.body { try stale.body.json }.currentRev)
        case .unprocessableContent(let invalid):
            throw Self.invalid(try Self.body { try invalid.body.json })
        case .notFound: throw .notFound
        case .unauthorized, .undocumented: throw .unexpectedAnswer
        }
    }

    /// `DELETE /v1/scenes/{scene_id}`: deletes a stored scene with its revisions, or says why not.
    public func deleteScene(_ id: String, at address: HostAddress, token: HostToken)
        async throws(HostFailure)
    {
        let output = try await call(at: address, token: token) {
            try await $0.deleteSceneV1ScenesSceneIdDelete(path: .init(sceneId: id))
        }
        switch output {
        case .noContent: return
        case .conflict(let refused): throw .conflict(try Self.body { try refused.body.json }.detail)
        case .notFound: throw .notFound
        case .unauthorized, .unprocessableContent, .undocumented: throw .unexpectedAnswer
        }
    }

    private static func invalid(_ body: Components.Schemas.Invalid) -> HostFailure {
        .invalid(body.failures.map { DocumentFailure(place: $0.place, message: $0.message) })
    }

    /// A request body built from `fields` as JSON, which the generated types read as the host
    /// would. It fails only for a document that is not a JSON object.
    static func request<Body: Decodable>(_ fields: [String: JSONValue]) throws(HostFailure)
        -> Body
    {
        do {
            return try JSONDecoder().decode(Body.self, from: JSONValue.object(fields).encoded())
        } catch {
            throw .invalid([DocumentFailure(place: "", message: "The scene is not a document.")])
        }
    }
}
