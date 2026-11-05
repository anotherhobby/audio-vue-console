import Testing

@testable import ConsoleCore

/// The rules every token store follows, through the in-memory one the other tests use.
@MainActor struct TokenStoreTests {
    private let audioVue = HostAddress(parsing: "audio-vue")
    private let local = HostAddress(parsing: "audio-vue.local")

    private func pairing(_ hostID: String, _ clientID: String = "c1") -> Pairing {
        Pairing(hostID: hostID, token: HostToken("t-\(hostID)"), clientID: clientID)
    }

    @Test func anAddressLeadsToTheLastHostSavedAtIt() throws {
        let store = InMemoryTokenStore()
        let address = try #require(audioVue)
        try store.save(pairing("first"), at: address)
        try store.save(pairing("second"), at: address)
        #expect(store.pairing(at: address) == pairing("second"))
    }

    @Test func aHostReachedAtTwoAddressesIsKeptOnce() throws {
        let store = InMemoryTokenStore()
        try store.save(pairing("host", "old"), at: try #require(audioVue))
        try store.save(pairing("host", "new"), at: try #require(local))
        #expect(store.pairing(at: try #require(audioVue)) == pairing("host", "new"))
        #expect(store.pairing(forHost: "host") == pairing("host", "new"))
    }

    @Test func anAddressNeverSavedHasNoPairing() throws {
        let store = InMemoryTokenStore()
        try store.save(pairing("host"), at: try #require(audioVue))
        #expect(store.pairing(at: try #require(local)) == nil)
    }

    @Test func forgettingAHostDropsEveryAddressPointingAtIt() throws {
        let store = InMemoryTokenStore()
        try store.save(pairing("host"), at: try #require(audioVue))
        try store.save(pairing("host"), at: try #require(local))
        try store.save(pairing("other"), at: try #require(HostAddress(parsing: "elsewhere")))
        store.forget(host: "host")
        #expect(store.pairing(at: try #require(audioVue)) == nil)
        #expect(store.pairing(at: try #require(local)) == nil)
        #expect(store.pairing(forHost: "other") == pairing("other"))
    }
}

/// A token store held in memory.
final class InMemoryTokenStore: TokenStore {
    private(set) var pairings = Pairings()

    func pairing(at address: HostAddress) -> Pairing? { pairings.pairing(at: address) }
    func pairing(forHost hostID: String) -> Pairing? { pairings.pairing(forHost: hostID) }
    func save(_ pairing: Pairing, at address: HostAddress) throws {
        pairings.save(pairing, at: address)
    }
    func forget(host hostID: String) { pairings.forget(host: hostID) }
}
