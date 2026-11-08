import Foundation
import Testing

@testable import ConsoleCore

/// Design D2: the scene writes send the document and its base with the token, and each refusal
/// comes back as the failure the host names.
struct HostClientSceneWritesTests {
    private let token = HostToken("secret")
    private let doc = JSONValue.object(["name": .string("Studio"), "cards": .array([])])
    private static let written =
        #"{"id": "u1", "rev": 4, "applies": "on_reload", "#
        + #""analysis_changed": false}"#

    private func address() throws -> HostAddress {
        try #require(HostAddress(parsing: "audio-vue"))
    }

    /// The request's JSON body.
    private static func body(of request: URLRequest) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: try #require(request.httpBody))
    }

    @Test func aCreateSendsTheDocumentAndAnswersTheNewID() async throws {
        let transport = FakeTransport([.createScene: .status(201, Self.written)])
        let created = try await HostClient(transport: transport).createScene(
            doc: doc, at: try address(), token: token)
        #expect(created.id == "u1" && created.rev == 4)
        let request = try #require(await transport.requests.first)
        #expect(try Self.body(of: request) == .object(["doc": doc]))
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(request.value(forHTTPHeaderField: "Origin") == nil)
    }

    @Test func aWriteSendsTheDocumentOnItsBase() async throws {
        let transport = FakeTransport([.writeScene("u1"): .status(200, Self.written)])
        let rev = try await HostClient(transport: transport).writeScene(
            "u1", doc: doc, baseRev: 3, at: try address(), token: token)
        #expect(rev == 4)
        let request = try #require(await transport.requests.first)
        #expect(try Self.body(of: request) == .object(["doc": doc, "base_rev": .integer(3)]))
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(request.value(forHTTPHeaderField: "Origin") == nil)
    }

    @Test func aStaleWriteSaysTheCurrentRevision() async throws {
        let body = #"{"detail": "the scene has moved on", "current_rev": 4}"#
        let transport = FakeTransport([.writeScene("u1"): .status(409, body)])
        await #expect(throws: HostFailure.stale(currentRev: 4)) {
            _ = try await HostClient(transport: transport).writeScene(
                "u1", doc: doc, baseRev: 3, at: try address(), token: token)
        }
    }

    @Test func anInvalidWriteNamesEveryFailure() async throws {
        let body =
            #"{"detail": "invalid", "failures": [{"place": "", "message": "needs a card"},"#
            + #"{"place": "cards[0].col", "message": "is off the grid"}]}"#
        let transport = FakeTransport([.writeScene("u1"): .status(422, body)])
        let failures = [
            DocumentFailure(place: "", message: "needs a card"),
            DocumentFailure(place: "cards[0].col", message: "is off the grid"),
        ]
        await #expect(throws: HostFailure.invalid(failures)) {
            _ = try await HostClient(transport: transport).writeScene(
                "u1", doc: doc, baseRev: 3, at: try address(), token: token)
        }
    }

    @Test func anInvalidCreateNamesItsFailure() async throws {
        let body = #"{"detail": "invalid", "failures": [{"place": "grid", "message": "too big"}]}"#
        let transport = FakeTransport([.createScene: .status(422, body)])
        let failure = DocumentFailure(place: "grid", message: "too big")
        await #expect(throws: HostFailure.invalid([failure])) {
            _ = try await HostClient(transport: transport).createScene(
                doc: doc, at: try address(), token: token)
        }
    }

    @Test func aWriteToASceneTheHostLacks() async throws {
        let transport = FakeTransport([.writeScene("gone"): .status(404, #"{"detail": "no"}"#)])
        await #expect(throws: HostFailure.notFound) {
            _ = try await HostClient(transport: transport).writeScene(
                "gone", doc: doc, baseRev: 1, at: try address(), token: token)
        }
    }

    @Test func aRefusedTokenOnAWrite() async throws {
        let transport = FakeTransport([.writeScene("u1"): .status(401, #"{"detail": "no"}"#)])
        await #expect(throws: HostFailure.tokenRefused) {
            _ = try await HostClient(transport: transport).writeScene(
                "u1", doc: doc, baseRev: 1, at: try address(), token: token)
        }
    }

    @Test func aDeleteIsDone() async throws {
        let transport = FakeTransport([.deleteScene("u1"): .status(204, "")])
        try await HostClient(transport: transport).deleteScene(
            "u1", at: try address(), token: token)
        let request = try #require(await transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    }

    @Test func aRefusedDeleteSaysWhy() async throws {
        let body = #"{"detail": "the scene is on screen"}"#
        let transport = FakeTransport([.deleteScene("u1"): .status(409, body)])
        await #expect(throws: HostFailure.conflict("the scene is on screen")) {
            try await HostClient(transport: transport).deleteScene(
                "u1", at: try address(), token: token)
        }
    }

    @Test func aDeleteOfASceneTheHostLacks() async throws {
        let transport = FakeTransport([.deleteScene("gone"): .status(404, #"{"detail": "no"}"#)])
        await #expect(throws: HostFailure.notFound) {
            try await HostClient(transport: transport).deleteScene(
                "gone", at: try address(), token: token)
        }
    }
}
