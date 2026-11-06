import Foundation
import Testing

@testable import ConsoleCore

/// `host-pairing`: "The app lists the host's paired clients", "The app revokes a paired client" and
/// "Requests carry the host's token", through the model the clients sheet binds to.
@MainActor struct PairedClientsTests {
    private static let kept = Pairing(hostID: "h1", token: HostToken("secret"), clientID: "me")
    private static let two = FakeTransport.Answer.status(
        200,
        #"""
        {"clients": [
          {"id": "me", "name": "hobbymac", "paired_at": "2026-11-04T10:00:00+00:00"},
          {"id": "old", "name": "Lost laptop", "paired_at": "2026-10-01T08:30:00+00:00"}
        ]}
        """#)
    private static let one = FakeTransport.Answer.status(
        200, #"{"clients": [{"id": "me", "name": "hobbymac", "paired_at": "2026-11-04"}]}"#)

    private let address = HostAddress(parsing: "audio-vue")

    private final class Unpaired {
        var times = 0
    }

    private func clients(
        _ transport: FakeTransport, tokens: InMemoryTokenStore = InMemoryTokenStore(),
        unpaired: Unpaired = Unpaired()
    ) throws -> PairedClients {
        let address = try #require(address)
        try tokens.save(Self.kept, at: address)
        return PairedClients(
            address: address, client: HostClient(transport: transport), pairing: Self.kept,
            store: tokens
        ) { unpaired.times += 1 }
    }

    @Test func listing() async throws {
        let transport = FakeTransport([.clients: Self.two])
        let clients = try clients(transport)
        await clients.load()
        #expect(clients.state == .loaded)
        #expect(clients.clients.map(\.name) == ["hobbymac", "Lost laptop"])
        #expect(clients.clients.map(clients.isThisApp) == [true, false])
        #expect(clients.clients.first?.pairedAt == Date(timeIntervalSince1970: 1_793_786_400))
    }

    @Test func readingTheClientsCarriesTheToken() async throws {
        let transport = FakeTransport([.clients: Self.two])
        try await clients(transport).load()
        let request = try #require(await transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(request.value(forHTTPHeaderField: "Origin") == nil)
    }

    @Test(arguments: ["yesterday", "2026-11-04", ""])
    func aPairingDateThatIsNotISO8601IsKeptAsText(text: String) {
        let client = PairedClient(id: "c", name: "n", pairedAtText: text)
        #expect(client.pairedAt == nil)
        #expect(client.pairedAtText == text)
    }

    @Test func revokingAnotherClient() async throws {
        let transport = FakeTransport([.clients: Self.two, .revoke("old"): .status(204, "")])
        let unpaired = Unpaired()
        let clients = try clients(transport, unpaired: unpaired)
        await clients.load()
        await transport.answer(.clients, with: Self.one)
        await clients.revoke(PairedClient(id: "old", name: "Lost laptop", pairedAtText: ""))
        #expect(clients.clients.map(\.id) == ["me"])
        #expect(clients.state == .loaded)
        #expect(unpaired.times == 0)
        let revoke = try #require(await transport.requests(to: .revoke("old")).first)
        #expect(revoke.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    }

    @Test func revokingAClientAlreadyGone() async throws {
        let transport = FakeTransport([
            .clients: Self.one, .revoke("old"): .status(404, #"{"detail": "no such client"}"#),
        ])
        let clients = try clients(transport)
        await clients.revoke(PairedClient(id: "old", name: "Lost laptop", pairedAtText: ""))
        #expect(clients.state == .loaded)
    }

    @Test func revokingThisApp() async throws {
        let transport = FakeTransport([.clients: Self.two, .revoke("me"): .status(204, "")])
        let tokens = InMemoryTokenStore()
        let unpaired = Unpaired()
        let clients = try clients(transport, tokens: tokens, unpaired: unpaired)
        await clients.load()
        await clients.revoke(PairedClient(id: "me", name: "hobbymac", pairedAtText: ""))
        #expect(clients.state == .unpaired)
        #expect(tokens.pairing(forHost: "h1") == nil)
        #expect(unpaired.times == 1)
    }

    @Test func aRefusedTokenMeansPairAgain() async throws {
        let transport = FakeTransport([.clients: .status(401, #"{"detail": "pair first"}"#)])
        let tokens = InMemoryTokenStore()
        let unpaired = Unpaired()
        let clients = try clients(transport, tokens: tokens, unpaired: unpaired)
        await clients.load()
        #expect(clients.state == .unpaired)
        #expect(tokens.pairing(forHost: "h1") == nil)
        #expect(unpaired.times == 1)
    }

    @Test func anotherFailureIsReported() async throws {
        let transport = FakeTransport([.clients: .failure(URLError(.timedOut))])
        let clients = try clients(transport)
        await clients.load()
        #expect(clients.state == .failed(.unreachable))
    }
}
