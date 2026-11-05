import Foundation
import Testing

@testable import ConsoleCore

/// `host-connection`: reading the version, no `Origin` header, and the kinds of failure.
struct HostClientTests {
    private let address = HostAddress(parsing: "audio-vue")

    @Test func theRequestIsAGetOfTheVersionWithNoOrigin() async throws {
        let transport = FakeTransport.version()
        _ = try await HostClient(transport: transport).version(at: try #require(address))
        let request = try #require(await transport.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "http://audio-vue:19200/v1/version")
        #expect(request.value(forHTTPHeaderField: "Origin") == nil)
        #expect(await transport.requests.count == 1)
    }

    @Test func thePanelAnswering() async throws {
        let version = try await HostClient(transport: FakeTransport.version("1.0.0", schema: "3"))
            .version(at: try #require(address))
        #expect(version.api.description == "1.0.0")
        #expect(version.schema == 3)
    }

    @Test(arguments: [
        #"{"api": "1.0.0", "schema": null}"#,
        #"{"api": "1.0.0"}"#,
        #"{"api": "1.0.0", "schema": null, "since": "2026-11-03"}"#,
    ])
    func thePanelNotAnswering(body: String) async throws {
        let version = try await HostClient(transport: FakeTransport(.status(200, body)))
            .version(at: try #require(address))
        #expect(version.api.description == "1.0.0")
        #expect(version.schema == nil)
    }

    @Test(arguments: [
        URLError.Code.timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
        .networkConnectionLost, .notConnectedToInternet,
    ])
    func nothingAtTheAddress(code: URLError.Code) async throws {
        await expectFailure(.unreachable, from: FakeTransport(.failure(URLError(code))))
    }

    @Test func theHostRefuses() async throws {
        await expectFailure(.refused, from: FakeTransport(.status(403, #"{"detail": "origin"}"#)))
    }

    @Test(arguments: [
        (404, #"{"detail": "Not Found"}"#),
        (500, "Internal Server Error"),
        (401, #"{"detail": "token"}"#),
        (200, "<html>a web server</html>"),
        (200, #"{"version": "1.0.0"}"#),
        (200, #"{"api": "one", "schema": 1}"#),
        (200, #"{"api": 1, "schema": 1}"#),
        (200, #"{"api": "1.0.0", "schema": "1"}"#),
    ])
    func somethingElseAnswers(status: Int, body: String) async throws {
        await expectFailure(.unexpectedAnswer, from: FakeTransport(.status(status, body)))
    }

    @Test func aBrokenAnswerIsUnexpected() async throws {
        await expectFailure(
            .unexpectedAnswer, from: FakeTransport(.failure(URLError(.badServerResponse))))
    }

    @Test func aRequestWithATokenCarriesItAsBearer() async throws {
        let transport = FakeTransport([.host: .status(200, "{}")])
        _ = try await HostClient(transport: transport)
            .send(.get, "v1/host", at: try #require(address), token: HostToken("secret"))
        let request = try #require(await transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(request.value(forHTTPHeaderField: "Origin") == nil)
    }

    @Test func aRequestWithNoTokenCarriesNone() async throws {
        let transport = FakeTransport.version()
        _ = try await HostClient(transport: transport).version(at: try #require(address))
        let request = try #require(await transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func aBodyGoesAsJSON() async throws {
        struct Body: Encodable { let name: String }
        let transport = FakeTransport([.ask: .status(200, "{}")])
        _ = try await HostClient(transport: transport).send(
            .post, "v1/pairing", at: try #require(address), body: Body(name: "hobbymac"))
        let request = try #require(await transport.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Origin") == nil)
        let body = try #require(request.httpBody)
        #expect(String(bytes: body, encoding: .utf8) == #"{"name":"hobbymac"}"#)
    }

    @Test func aRefusedTokenIsToldApart() async throws {
        let transport = FakeTransport([.host: .status(401, #"{"detail": "pair first"}"#)])
        let address = try #require(address)
        await #expect(throws: HostFailure.tokenRefused) {
            try await HostClient(transport: transport)
                .send(.get, "v1/host", at: address, token: HostToken("stale"))
        }
    }

    @Test func aTokenHidesItsValueWhenPrinted() {
        #expect(!"\(HostToken("secret"))".contains("secret"))
    }

    private func expectFailure(_ failure: HostFailure, from transport: FakeTransport) async {
        guard let address else {
            Issue.record("The test address did not parse")
            return
        }
        await #expect(throws: failure) {
            try await HostClient(transport: transport).version(at: address)
        }
    }
}
