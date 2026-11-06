import Foundation
import Testing

@testable import ConsoleCore

/// `host-pairing`: "The app pairs by the code on the panel", "A refused pairing says why" and "The
/// app keeps one token per host", driven through the model the pairing sheet binds to.
@MainActor struct HostPairingTests {
    private static let shown = FakeTransport.Answer.status(200, #"{"ttl_s": 120, "tries": 5}"#)
    private static let token = FakeTransport.Answer.status(
        200, #"{"token": "new-token", "client_id": "new"}"#)
    private static let host = FakeTransport.Answer.status(200, #"{"id": "h1", "name": "cabin"}"#)
    private static let newPairing = Pairing(
        hostID: "h1", token: HostToken("new-token"), clientID: "new")

    private let address = HostAddress(parsing: "audio-vue")

    private final class Paired {
        var pairings: [Pairing] = []
    }

    private func pairing(
        _ transport: FakeTransport, store: any TokenStore = InMemoryTokenStore(),
        paired: Paired = Paired()
    ) throws -> HostPairing {
        HostPairing(
            address: try #require(address), client: HostClient(transport: transport), store: store,
            name: "hobbymac"
        ) { pairing, _ in paired.pairings.append(pairing) }
    }

    private func refusal(_ status: Int, headers: [String: String] = [:]) -> FakeTransport.Answer {
        .status(status, #"{"detail": "the host's reason"}"#, headers: headers)
    }

    @Test func aFirstPairing() async throws {
        let transport = FakeTransport([.ask: Self.shown, .confirm: Self.token, .host: Self.host])
        let store = InMemoryTokenStore()
        let paired = Paired()
        let pairing = try pairing(transport, store: store, paired: paired)
        await pairing.ask()
        #expect(pairing.state == .showingCode(PairingCode(ttl: 120, tries: 5)))
        #expect(pairing.codeLapsesAt != nil)
        await pairing.confirm("123456")
        #expect(pairing.state == .paired)
        #expect(store.pairing(at: try #require(address)) == Self.newPairing)
        #expect(paired.pairings == [Self.newPairing])
        let host = try #require(await transport.requests(to: .host).first)
        #expect(host.value(forHTTPHeaderField: "Authorization") == "Bearer new-token")
    }

    @Test(arguments: ["12345", "1234567", "12345a", " 123456", "١٢٣٤٥٦", ""])
    func aCodeThatIsNotSixDigitsSendsNothing(code: String) async throws {
        let transport = FakeTransport([.ask: Self.shown])
        let pairing = try pairing(transport)
        await pairing.ask()
        await pairing.confirm(code)
        #expect(pairing.codeIsMalformed)
        #expect(pairing.state == .showingCode(PairingCode(ttl: 120, tries: 5)))
        #expect(await transport.requests(to: .confirm).isEmpty)
    }

    @Test func aWrongCode() async throws {
        let transport = FakeTransport([.ask: Self.shown, .confirm: refusal(403)])
        let pairing = try pairing(transport)
        await pairing.ask()
        await pairing.confirm("000000")
        #expect(pairing.state == .refused(PairingRefusal(.wrongCode, detail: "the host's reason")))
    }

    @Test func aWrongCodeKeepsTheCodeStandingToSendAgain() async throws {
        let transport = FakeTransport([.ask: Self.shown, .confirm: refusal(403)])
        let pairing = try pairing(transport)
        await pairing.ask()
        await pairing.confirm("000000")
        #expect(!pairing.mayAsk(at: .now))
        await pairing.ask()
        #expect(await transport.requests(to: .ask).count == 1)
        await transport.answer(.confirm, with: Self.token)
        await transport.answer(.host, with: Self.host)
        await pairing.confirm("123456")
        #expect(pairing.state == .paired)
    }

    @Test func askingIsAllowedOnceTheCodeHasLapsed() throws {
        let now = Date.now
        #expect(!HostPairing.mayAsk(at: now, codeLapsesAt: now + 1, askAllowedAt: nil))
        #expect(HostPairing.mayAsk(at: now, codeLapsesAt: now - 1, askAllowedAt: nil))
        #expect(!HostPairing.mayAsk(at: now, codeLapsesAt: nil, askAllowedAt: now + 1))
        #expect(HostPairing.mayAsk(at: now, codeLapsesAt: nil, askAllowedAt: nil))
    }

    @Test func aCodeThatLapsed() async throws {
        let transport = FakeTransport([.ask: Self.shown, .confirm: refusal(409)])
        let pairing = try pairing(transport)
        await pairing.ask()
        await pairing.confirm("123456")
        #expect(pairing.state == .refused(PairingRefusal(.noCode, detail: "the host's reason")))
        await transport.answer(.ask, with: Self.shown)
        await pairing.ask()
        #expect(pairing.state == .showingCode(PairingCode(ttl: 120, tries: 5)))
    }

    @Test func anotherPairingUnderWay() async throws {
        let pairing = try pairing(FakeTransport([.ask: refusal(409)]))
        await pairing.ask()
        #expect(pairing.state == .refused(PairingRefusal(.busy, detail: "the host's reason")))
    }

    @Test func tooSoonAfterTheLastPairing() async throws {
        let transport = FakeTransport([.ask: refusal(429, headers: ["Retry-After": "30"])])
        let pairing = try pairing(transport)
        let before = Date.now
        await pairing.ask()
        let kind = PairingRefusal.Kind.tooSoon(seconds: 30)
        #expect(pairing.state == .refused(PairingRefusal(kind, detail: "the host's reason")))
        let allowed = try #require(pairing.askAllowedAt)
        #expect(allowed >= before + 30 && allowed <= .now + 30)
    }

    @Test func tooSoonWithNoWaitNamed() async throws {
        let pairing = try pairing(FakeTransport([.ask: refusal(429)]))
        await pairing.ask()
        #expect(pairing.askAllowedAt == nil)
    }

    @Test func thePanelNotRunning() async throws {
        let pairing = try pairing(FakeTransport([.ask: refusal(503)]))
        await pairing.ask()
        #expect(pairing.state == .refused(PairingRefusal(.noPanel, detail: "the host's reason")))
    }

    @Test func noHostIsAFailureNotARefusal() async throws {
        let pairing = try pairing(FakeTransport([.ask: .failure(URLError(.cannotConnectToHost))]))
        await pairing.ask()
        #expect(pairing.state == .failed(.unreachable))
    }

    @Test(arguments: [204, 404])
    func pairingAgainRevokesTheEarlierClient(revoked: Int) async throws {
        let transport = FakeTransport([
            .confirm: Self.token, .host: Self.host, .revoke("old"): .status(revoked, ""),
        ])
        let store = InMemoryTokenStore()
        let earlier = Pairing(hostID: "h1", token: HostToken("old-token"), clientID: "old")
        try store.save(earlier, at: try #require(HostAddress(parsing: "audio-vue.local")))
        let pairing = try pairing(transport, store: store)
        await pairing.confirm("123456")
        let revoke = try #require(await transport.requests(to: .revoke("old")).first)
        #expect(revoke.value(forHTTPHeaderField: "Authorization") == "Bearer new-token")
        #expect(store.pairing(forHost: "h1") == Self.newPairing)
        #expect(pairing.state == .paired)
    }

    @Test func aFailedRevokeKeepsTheNewToken() async throws {
        let transport = FakeTransport([
            .confirm: Self.token, .host: Self.host, .revoke("old"): .status(500, ""),
        ])
        let store = InMemoryTokenStore()
        let address = try #require(address)
        try store.save(Pairing(hostID: "h1", token: HostToken("old"), clientID: "old"), at: address)
        let pairing = try pairing(transport, store: store)
        await pairing.confirm("123456")
        #expect(store.pairing(at: address) == Self.newPairing)
        #expect(pairing.state == .paired)
    }

    @Test func aTokenThisMacCannotKeep() async throws {
        let transport = FakeTransport([.confirm: Self.token, .host: Self.host])
        let paired = Paired()
        let pairing = try pairing(transport, store: UnwritableTokenStore(), paired: paired)
        await pairing.confirm("123456")
        guard case .notKept = pairing.state else {
            Issue.record("Not reported as not kept: \(pairing.state)")
            return
        }
        #expect(paired.pairings.isEmpty)
    }

    @Test func theRequestNamesTheClient() async throws {
        let transport = FakeTransport([.ask: Self.shown])
        try await pairing(transport).ask()
        let ask = try #require(await transport.requests(to: .ask).first)
        #expect(FakeTransport.json(of: ask) == ["name": "hobbymac"])
    }
}

/// A token store whose every save fails, as a full or locked disk would.
private struct UnwritableTokenStore: TokenStore {
    func pairing(at address: HostAddress) -> Pairing? { nil }
    func pairing(forHost hostID: String) -> Pairing? { nil }
    func save(_ pairing: Pairing, at address: HostAddress) throws {
        throw CocoaError(.fileWriteNoPermission)
    }
    func forget(host hostID: String) {}
}
