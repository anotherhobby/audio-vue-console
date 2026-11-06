import Foundation
import Testing

@testable import ConsoleCore

/// `host-pairing`: the pairing calls, each refusal on its own route, and the host read.
struct HostClientPairingTests {
    private let address = HostAddress(parsing: "audio-vue")

    private func client(_ answers: [FakeTransport.Route: FakeTransport.Answer]) -> (
        HostClient, FakeTransport
    ) {
        let transport = FakeTransport(answers)
        return (HostClient(transport: transport), transport)
    }

    private static func body(of request: URLRequest) -> [String: String]? {
        FakeTransport.json(of: request)
    }

    @Test func askingNamesTheClientAndCarriesNoToken() async throws {
        let (client, transport) = client([.ask: .status(200, #"{"ttl_s": 120.0, "tries": 5}"#)])
        let code = try await client.askPairing(at: try #require(address), name: "hobbymac")
        #expect(code == PairingCode(ttl: 120, tries: 5))
        let request = try #require(await transport.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "http://audio-vue:19200/v1/pairing")
        #expect(Self.body(of: request) == ["name": "hobbymac"])
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "Origin") == nil)
    }

    @Test func confirmingGivesTheTokenAndCarriesNoToken() async throws {
        let (client, transport) = client([
            .confirm: .status(200, #"{"token": "secret", "client_id": "c1"}"#)
        ])
        let grant = try await client.confirmPairing(at: try #require(address), code: "123456")
        #expect(grant == PairingGrant(token: HostToken("secret"), clientID: "c1"))
        let request = try #require(await transport.requests.first)
        #expect(Self.body(of: request) == ["code": "123456"])
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "Origin") == nil)
    }

    @Test(arguments: [
        (409, [:], PairingRefusal.Kind.busy),
        (429, ["Retry-After": "17"], .tooSoon(seconds: 17)),
        (429, [:], .tooSoon(seconds: nil)),
        (503, [:], .noPanel),
    ])
    func askingIsRefused(status: Int, headers: [String: String], kind: PairingRefusal.Kind)
        async throws
    {
        let (client, _) = client([.ask: .status(status, #"{"detail": "why"}"#, headers: headers)])
        let address = try #require(address)
        await #expect(throws: HostFailure.pairingRefused(PairingRefusal(kind, detail: "why"))) {
            try await client.askPairing(at: address, name: "hobbymac")
        }
    }

    @Test(arguments: [
        (403, PairingRefusal.Kind.wrongCode),
        (409, .noCode),
    ])
    func confirmingIsRefused(status: Int, kind: PairingRefusal.Kind) async throws {
        let (client, _) = client([.confirm: .status(status, #"{"detail": "why"}"#)])
        let address = try #require(address)
        await #expect(throws: HostFailure.pairingRefused(PairingRefusal(kind, detail: "why"))) {
            try await client.confirmPairing(at: address, code: "123456")
        }
    }

    /// The contract gives every refusal as `{"detail": …}`, so one that is not is an answer the
    /// contract does not give.
    @Test func aRefusalTheContractDoesNotGiveIsUnexpected() async throws {
        let (client, _) = client([.confirm: .status(403, "Forbidden")])
        let address = try #require(address)
        await #expect(throws: HostFailure.unexpectedAnswer) {
            try await client.confirmPairing(at: address, code: "123456")
        }
    }

    @Test func aMalformedRequestIsUnexpected() async throws {
        let (client, _) = client([
            .ask: .status(422, #"{"detail": []}"#), .confirm: .status(422, #"{"detail": []}"#),
        ])
        let address = try #require(address)
        await #expect(throws: HostFailure.unexpectedAnswer) {
            try await client.askPairing(at: address, name: "")
        }
        await #expect(throws: HostFailure.unexpectedAnswer) {
            try await client.confirmPairing(at: address, code: "1")
        }
    }

    @Test(arguments: [
        (#"{"id":"h1","name":"cabin","width_px":1920,"height_px":480}"#, 1920, 480),
        (
            #"{"id":"h1","name":"cabin","width_px":null,"height_px":null,"updating":null}"#,
            nil, nil
        ),
    ])
    func theHostIsReadWithTheToken(body: String, width: Int?, height: Int?) async throws {
        let (client, transport) = client([.host: .status(200, body)])
        let host = try await client.host(at: try #require(address), token: HostToken("secret"))
        #expect(host == HostIdentity(id: "h1", name: "cabin", widthPx: width, heightPx: height))
        let request = try #require(await transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    }

    @Test func theHostRefusingTheTokenIsToldApart() async throws {
        let (client, _) = client([.host: .status(401, #"{"detail": "pair first"}"#)])
        let address = try #require(address)
        await #expect(throws: HostFailure.tokenRefused) {
            try await client.host(at: address, token: HostToken("stale"))
        }
    }
}
