import Foundation
import Testing

@testable import ConsoleCore

/// `host-connection`, "Connecting says whether the app is paired" for a found panel, and "The app
/// remembers the last address" with its launch fallback (discovery design D4, D5).
@MainActor struct HostConnectionDiscoveryTests {
    private static let host = FakeTransport.Answer.status(200, #"{"id": "h1", "name": "cabin"}"#)
    private static let kept = Pairing(hostID: "h1", token: HostToken("secret"), clientID: "c1")
    private static let instance = ServiceInstance(name: "audio-vue", hostID: "h1")
    private static let unreachable = FakeTransport.Answer.failure(URLError(.cannotConnectToHost))

    private struct Setup {
        let connection: HostConnection
        let transport: FakeTransport
        let tokens: InMemoryTokenStore
        let store: MemoryAddressStore
        let discovery: PanelDiscovery
        let local: HostAddress
    }

    /// A connection over `transport`, its discovery resolving `audio-vue` to `audio-vue.local`.
    private func setup(
        _ transport: FakeTransport, store: MemoryAddressStore = MemoryAddressStore()
    ) throws -> Setup {
        let local = try #require(HostAddress(parsing: "audio-vue.local"))
        let tokens = InMemoryTokenStore()
        let discovery = PanelDiscovery(
            browser: ScriptedBrowser(answers: ["audio-vue": .success(local)]))
        let connection = HostConnection(
            client: HostClient(transport: transport), store: store, tokens: tokens,
            discovery: discovery)
        return Setup(
            connection: connection, transport: transport, tokens: tokens, store: store,
            discovery: discovery, local: local)
    }

    private static func found(at address: HostAddress?) -> FoundPanel {
        FoundPanel(id: "h1", name: "audio-vue", address: address)
    }

    private static var pairedHost: FakeTransport {
        FakeTransport([.version: FakeTransport.versionAnswer(), .host: host])
    }

    @Test func aPairedHostFoundAtANewAddress() async throws {
        let setup = try setup(Self.pairedHost)
        try setup.tokens.save(Self.kept, at: try #require(HostAddress(parsing: "audio-vue")))
        let panel = Self.found(at: setup.local)
        await setup.connection.connect(to: panel)
        #expect(setup.connection.isPaired == true)
        let check = try #require(await setup.transport.requests(to: .host).first)
        #expect(check.url?.host() == "audio-vue.local")
        #expect(check.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(setup.tokens.pairing(at: setup.local) == Self.kept)
        #expect(setup.connection.foundPanel == panel)
        #expect(setup.connection.addressText == "audio-vue.local")
        #expect(setup.store.saved == "audio-vue.local")
        #expect(setup.store.savedHostID == "h1")
    }

    @Test func aFoundPanelWhoseIDDoesNotMatch() async throws {
        let other = FakeTransport.Answer.status(200, #"{"id": "h2", "name": "cabin"}"#)
        let setup = try setup(
            FakeTransport([.version: FakeTransport.versionAnswer(), .host: other]))
        try setup.tokens.save(Self.kept, at: try #require(HostAddress(parsing: "audio-vue")))
        await setup.connection.connect(to: Self.found(at: setup.local))
        #expect(setup.connection.isPaired == false)
        #expect(setup.connection.host == nil)
        #expect(setup.tokens.pairing(at: setup.local) == nil)
    }

    @Test func aTokenRefusedAtAFoundPanelIsForgotten() async throws {
        let refused = FakeTransport.Answer.status(401, #"{"detail": "pair first"}"#)
        let setup = try setup(
            FakeTransport([.version: FakeTransport.versionAnswer(), .host: refused]))
        try setup.tokens.save(Self.kept, at: try #require(HostAddress(parsing: "audio-vue")))
        await setup.connection.connect(to: Self.found(at: setup.local))
        #expect(setup.connection.isPaired == false)
        #expect(setup.tokens.pairing(forHost: "h1") == nil)
    }

    @Test func anUnpairedFoundPanelOffersPair() async throws {
        let setup = try setup(FakeTransport.version())
        await setup.connection.connect(to: Self.found(at: setup.local))
        #expect(setup.connection.isPaired == false)
        #expect(await setup.transport.requests(to: .host).isEmpty)
        #expect(setup.connection.makePairing(name: "hobbymac") != nil)
        #expect(setup.store.savedHostID == "h1")
    }

    @Test func aTypedPairedHostRemembersItsID() async throws {
        let setup = try setup(Self.pairedHost)
        try setup.tokens.save(Self.kept, at: try #require(HostAddress(parsing: "audio-vue")))
        setup.connection.addressText = "audio-vue"
        await setup.connection.connect()
        #expect(setup.store.saved == "audio-vue")
        #expect(setup.store.savedHostID == "h1")
    }

    @Test func aTypedUnpairedHostRemembersNoID() async throws {
        let setup = try setup(
            FakeTransport.version(), store: MemoryAddressStore(saved: "audio-vue", hostID: "h1"))
        setup.connection.addressText = "audio-vue"
        await setup.connection.connect()
        #expect(setup.store.saved == "audio-vue")
        #expect(setup.store.savedHostID == nil)
    }

    @Test func aFoundPanelsTokenIsTheOneKeptForItsID() async throws {
        let setup = try setup(Self.pairedHost)
        let earlier = Pairing(hostID: "h0", token: HostToken("old"), clientID: "c0")
        try setup.tokens.save(earlier, at: setup.local)
        try setup.tokens.save(Self.kept, at: try #require(HostAddress(parsing: "audio-vue")))
        await setup.connection.connect(to: Self.found(at: setup.local))
        let check = try #require(await setup.transport.requests(to: .host).first)
        #expect(check.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(setup.connection.isPaired == true)
    }

    @Test func aFoundPanelIsResolvedWhenChosenWithNoAddress() async throws {
        let setup = try setup(FakeTransport.version())
        setup.discovery.receive(.found([Self.instance]))
        await setup.connection.connect(to: Self.found(at: nil))
        #expect(setup.connection.address == setup.local)
    }

    @Test func aPanelThatCannotBeResolved() async throws {
        let setup = try setup(FakeTransport.version())
        await setup.connection.connect(to: Self.found(at: nil))
        #expect(setup.connection.state == .unresolved("audio-vue", .unreachable))
        #expect(setup.connection.address == nil)
        #expect(await setup.transport.requests.isEmpty)
    }

    @Test func aTypedConnectForgetsTheFoundPanel() async throws {
        let setup = try setup(FakeTransport.version())
        await setup.connection.connect(to: Self.found(at: setup.local))
        setup.connection.addressText = "audio-vue"
        await setup.connection.connect()
        #expect(setup.connection.foundPanel == nil)
        #expect(setup.store.savedHostID == nil)
    }

    @Test func aPairingRemembersTheHostsID() async throws {
        let confirmed = FakeTransport.Answer.status(
            200, #"{"token": "secret", "client_id": "c1"}"#)
        let setup = try setup(
            FakeTransport([
                .version: FakeTransport.versionAnswer(),
                .ask: .status(200, #"{"ttl_s": 120, "tries": 5}"#),
                .confirm: confirmed, .host: Self.host,
            ]))
        setup.connection.addressText = "audio-vue"
        await setup.connection.connect()
        #expect(setup.store.savedHostID == nil)
        let pairing = try #require(setup.connection.makePairing(name: "hobbymac"))
        await pairing.ask()
        await pairing.confirm("123456")
        #expect(setup.connection.isPaired == true)
        #expect(setup.store.savedHostID == "h1")
    }

    // MARK: The launch fallback

    @Test func aPanelThatMoved() async throws {
        let setup = try setup(
            Self.pairedHost, store: MemoryAddressStore(saved: "192.168.1.20", hostID: "h1"))
        await setup.transport.answer(.version, at: "192.168.1.20", with: Self.unreachable)
        try setup.tokens.save(Self.kept, at: try #require(HostAddress(parsing: "192.168.1.20")))
        setup.discovery.receive(.found([Self.instance]))
        await setup.connection.connectAtLaunch()
        await setup.connection.launchWaitEnded()
        #expect(setup.connection.address == setup.local)
        #expect(setup.connection.isPaired == true)
        #expect(setup.store.saved == "audio-vue.local")
    }

    @Test func aPanelNotYetAnnounced() async throws {
        let setup = try setup(
            Self.pairedHost, store: MemoryAddressStore(saved: "192.168.1.20", hostID: "h1"))
        await setup.transport.answer(.version, at: "192.168.1.20", with: Self.unreachable)
        await setup.connection.connectAtLaunch()
        let remembered = try #require(HostAddress(parsing: "192.168.1.20"))
        #expect(setup.connection.state == .failed(remembered, .unreachable))
        setup.discovery.receive(.found([Self.instance]))
        await setup.connection.launchWaitEnded()
        #expect(setup.connection.address == setup.local)
    }

    @Test func aPanelAddedBeforeTheAnnouncementEndsTheWait() async throws {
        let setup = try setup(
            Self.pairedHost, store: MemoryAddressStore(saved: "192.168.1.20", hostID: "h1"))
        await setup.transport.answer(.version, at: "192.168.1.20", with: Self.unreachable)
        await setup.connection.connectAtLaunch()
        setup.connection.addressText = "studio"
        await setup.connection.connect()
        await setup.connection.launchWaitEnded()
        setup.discovery.receive(.found([Self.instance]))
        await Task.yield()
        #expect(setup.connection.address == HostAddress(parsing: "studio"))
    }

    @Test func noIDRememberedStartsNoWait() async throws {
        let setup = try setup(Self.pairedHost, store: MemoryAddressStore(saved: "192.168.1.20"))
        await setup.transport.answer(.version, at: "192.168.1.20", with: Self.unreachable)
        setup.discovery.receive(.found([Self.instance]))
        await setup.connection.connectAtLaunch()
        await setup.connection.launchWaitEnded()
        #expect(setup.connection.address == HostAddress(parsing: "192.168.1.20"))
    }

    @Test(arguments: [
        FakeTransport.Answer.status(403, ""), FakeTransport.versionAnswer("one"),
    ])
    func anAnswerThatIsNotAMovedHostStartsNoWait(answer: FakeTransport.Answer) async throws {
        let setup = try setup(
            Self.pairedHost, store: MemoryAddressStore(saved: "192.168.1.20", hostID: "h1"))
        await setup.transport.answer(.version, at: "192.168.1.20", with: answer)
        setup.discovery.receive(.found([Self.instance]))
        await setup.connection.connectAtLaunch()
        await setup.connection.launchWaitEnded()
        #expect(setup.connection.address == HostAddress(parsing: "192.168.1.20"))
    }
}
