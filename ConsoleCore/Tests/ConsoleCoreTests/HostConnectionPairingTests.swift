import Foundation
import Testing

@testable import ConsoleCore

/// `host-connection`, "Connecting says whether the app is paired", and `host-pairing`, "A refused
/// token means pair again", on connect.
@MainActor struct HostConnectionPairingTests {
    private static let host = FakeTransport.Answer.status(200, #"{"id": "h1", "name": "cabin"}"#)
    private static let kept = Pairing(hostID: "h1", token: HostToken("secret"), clientID: "c1")

    private func connection(
        _ transport: FakeTransport, tokens: InMemoryTokenStore, typing text: String = "audio-vue"
    ) -> HostConnection {
        let connection = HostConnection(
            client: HostClient(transport: transport), store: MemoryAddressStore(), tokens: tokens)
        connection.addressText = text
        return connection
    }

    private func paired(_ connection: HostConnection) -> Bool? {
        guard case .connected(_, _, let paired) = connection.state else { return nil }
        return paired
    }

    @Test func aHostNeverPairedWith() async {
        let transport = FakeTransport.version()
        let connection = connection(transport, tokens: InMemoryTokenStore())
        await connection.connect()
        #expect(paired(connection) == false)
        #expect(await transport.requests(to: .host).isEmpty)
        #expect(connection.makePairing(name: "hobbymac") != nil)
        #expect(connection.makeClients() == nil)
    }

    @Test func aHostPairedWith() async throws {
        let transport = FakeTransport([.version: FakeTransport.versionAnswer(), .host: Self.host])
        let tokens = InMemoryTokenStore()
        try tokens.save(Self.kept, at: try #require(HostAddress(parsing: "audio-vue")))
        let connection = connection(transport, tokens: tokens)
        await connection.connect()
        #expect(paired(connection) == true)
        let check = try #require(await transport.requests(to: .host).first)
        #expect(check.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(connection.makeClients() != nil)
        #expect(
            connection.host == HostIdentity(id: "h1", name: "cabin", widthPx: nil, heightPx: nil))
    }

    @Test func anotherAddressForAPairedHost() async throws {
        let transport = FakeTransport.version()
        let tokens = InMemoryTokenStore()
        try tokens.save(Self.kept, at: try #require(HostAddress(parsing: "audio-vue")))
        let connection = connection(transport, tokens: tokens, typing: "audio-vue.local")
        await connection.connect()
        #expect(paired(connection) == false)
    }

    @Test func aTokenTheHostNoLongerTakes() async throws {
        let refused = FakeTransport.Answer.status(401, #"{"detail": "pair first"}"#)
        let transport = FakeTransport([.version: FakeTransport.versionAnswer(), .host: refused])
        let tokens = InMemoryTokenStore()
        let address = try #require(HostAddress(parsing: "audio-vue"))
        try tokens.save(Self.kept, at: address)
        let connection = connection(transport, tokens: tokens)
        await connection.connect()
        #expect(paired(connection) == false)
        #expect(tokens.pairing(at: address) == nil)
        #expect(connection.host == nil)
    }

    @Test func anotherFailureOfTheCheckFailsTheConnect() async throws {
        let transport = FakeTransport([
            .version: FakeTransport.versionAnswer(), .host: .status(500, ""),
        ])
        let tokens = InMemoryTokenStore()
        let address = try #require(HostAddress(parsing: "audio-vue"))
        try tokens.save(Self.kept, at: address)
        let connection = connection(transport, tokens: tokens)
        await connection.connect()
        #expect(connection.state == .failed(address, .unexpectedAnswer))
        #expect(tokens.pairing(at: address) == Self.kept)
    }

    @Test func pairingMarksTheConnectionPaired() async throws {
        let transport = FakeTransport([
            .version: FakeTransport.versionAnswer(),
            .confirm: .status(200, #"{"token": "secret", "client_id": "c1"}"#),
            .host: Self.host,
        ])
        let tokens = InMemoryTokenStore()
        let connection = connection(transport, tokens: tokens)
        await connection.connect()
        let pairing = try #require(connection.makePairing(name: "hobbymac"))
        await pairing.confirm("123456")
        #expect(paired(connection) == true)
        #expect(tokens.pairing(at: try #require(HostAddress(parsing: "audio-vue"))) == Self.kept)
        #expect(connection.host?.name == "cabin")
        #expect(connection.liveState() != nil)
    }

    @Test func revokingThisAppMarksTheConnectionNotPaired() async throws {
        let transport = FakeTransport([
            .version: FakeTransport.versionAnswer(), .host: Self.host,
            .revoke("c1"): .status(204, ""),
        ])
        let tokens = InMemoryTokenStore()
        try tokens.save(Self.kept, at: try #require(HostAddress(parsing: "audio-vue")))
        let connection = connection(transport, tokens: tokens)
        await connection.connect()
        let clients = try #require(connection.makeClients())
        await clients.revoke(PairedClient(id: "c1", name: "hobbymac", pairedAtText: ""))
        #expect(paired(connection) == false)
        #expect(connection.makeClients() == nil)
        #expect(connection.host == nil)
        #expect(connection.liveState() == nil)
    }

    @Test func theWindowMakesWhatItShowsFromTheConnection() async throws {
        let transport = FakeTransport([.version: FakeTransport.versionAnswer(), .host: Self.host])
        let tokens = InMemoryTokenStore()
        let connection = connection(transport, tokens: tokens)
        #expect(connection.isPaired == nil)
        await connection.connect()
        #expect(connection.isPaired == false)
        #expect(connection.address?.description == "audio-vue")
        #expect(connection.makeClients() == nil)
        #expect(connection.liveState() == nil)
        connection.pair(name: "hobbymac")
        #expect(connection.pairing?.address.description == "audio-vue")
        connection.pairing = nil
        try tokens.save(Self.kept, at: try #require(HostAddress(parsing: "audio-vue")))
        await connection.connect()
        #expect(connection.isPaired == true)
        #expect(connection.makeClients() != nil)
        #expect(connection.liveState() != nil)
    }

    @Test func nothingIsMadeWhenNotConnected() {
        let connection = connection(FakeTransport.version(), tokens: InMemoryTokenStore())
        #expect(connection.address == nil)
        #expect(connection.makePairing(name: "hobbymac") == nil)
        #expect(connection.makeClients() == nil)
    }
}
