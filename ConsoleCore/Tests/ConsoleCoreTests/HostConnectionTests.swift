import Foundation
import Testing

@testable import ConsoleCore

/// `host-connection`, each scenario driven through the model the connect view binds to.
@MainActor struct HostConnectionTests {
    private func connection(
        _ transport: FakeTransport, store: MemoryAddressStore = MemoryAddressStore(),
        typing text: String = "audio-vue"
    ) -> HostConnection {
        let connection = HostConnection(
            client: HostClient(transport: transport), store: store, tokens: InMemoryTokenStore())
        connection.addressText = text
        return connection
    }

    @Test(arguments: [
        (
            "audio-vue.cabin.hobbysprawl.com",
            "http://audio-vue.cabin.hobbysprawl.com:19200/v1/version"
        ),
        ("192.168.1.20:8080", "http://192.168.1.20:8080/v1/version"),
    ])
    func theAddressIsRead(text: String, url: String) async throws {
        let transport = FakeTransport.version()
        await connection(transport, typing: text).connect()
        #expect(await transport.requests.map(\.url?.absoluteString) == [url])
    }

    @Test(arguments: ["", "audio vue", "http://audio-vue", "audio-vue:0", "audio-vue:65536"])
    func anInvalidAddressSendsNothing(text: String) async {
        let transport = FakeTransport.version()
        let connection = connection(transport, typing: text)
        await connection.connect()
        #expect(connection.state == .invalidAddress)
        #expect(await transport.requests.isEmpty)
    }

    @Test func aCompatibleHost() async throws {
        let connection = connection(FakeTransport.version(schema: "3"))
        await connection.connect()
        guard case .connected(let address, let version, paired: false) = connection.state else {
            Issue.record("Not connected: \(connection.state)")
            return
        }
        #expect(address.description == "audio-vue")
        #expect(version.api.description == FakeTransport.supportedAPI)
        #expect(version.schema == 3)
    }

    @Test func thePanelIsDown() async {
        let connection = connection(FakeTransport.version(schema: "null"))
        await connection.connect()
        guard case .connected(_, let version, _) = connection.state else {
            Issue.record("Not connected: \(connection.state)")
            return
        }
        #expect(version.schema == nil)
    }

    @Test(arguments: [
        (FakeTransport.newerAPI, APIVersion.Compatibility.hostNewer),
        (FakeTransport.olderAPI, .hostOlder),
    ])
    func anIncompatibleHostIsNotConnected(api: String, verdict: APIVersion.Compatibility) async {
        let connection = connection(FakeTransport.version(api))
        await connection.connect()
        guard case .incompatible(_, let version) = connection.state else {
            Issue.record("Not incompatible: \(connection.state)")
            return
        }
        #expect(version.api.compatibility == verdict)
    }

    @Test(arguments: [
        (FakeTransport(.failure(URLError(.timedOut))), HostFailure.unreachable),
        (FakeTransport(.status(403, "")), .refused),
        (FakeTransport(.status(404, "")), .unexpectedAnswer),
        (FakeTransport.version("one"), .unexpectedAnswer),
    ])
    func aFailureSaysWhy(transport: FakeTransport, failure: HostFailure) async throws {
        let connection = connection(transport)
        await connection.connect()
        let address = try #require(HostAddress(parsing: "audio-vue"))
        #expect(connection.state == .failed(address, failure))
    }

    @Test func anAnsweringHostsAddressIsSavedAndOfferedAtLaunch() async {
        let store = MemoryAddressStore()
        await connection(FakeTransport.version(), store: store, typing: " audio-vue:19200 ")
            .connect()
        #expect(store.saved == "audio-vue")
        let relaunched = HostConnection(
            client: HostClient(transport: FakeTransport.version()), store: store,
            tokens: InMemoryTokenStore())
        #expect(relaunched.addressText == "audio-vue")
        #expect(relaunched.state == .idle)
    }

    @Test func anIncompatibleHostsAddressIsSavedToo() async {
        let store = MemoryAddressStore()
        await connection(FakeTransport.version(FakeTransport.newerAPI), store: store).connect()
        #expect(store.saved == "audio-vue")
    }

    @Test(arguments: [
        FakeTransport(.failure(URLError(.cannotConnectToHost))),
        FakeTransport(.status(403, "")),
        FakeTransport.version("one"),
    ])
    func aFailedAddressIsNotSaved(transport: FakeTransport) async {
        let store = MemoryAddressStore(saved: "audio-vue")
        await connection(transport, store: store, typing: "elsewhere").connect()
        #expect(store.saved == "audio-vue")
    }

    @Test func nothingIsSentAtLaunch() async {
        let transport = FakeTransport.version()
        let connection = HostConnection(
            client: HostClient(transport: transport), store: MemoryAddressStore(saved: "audio-vue"),
            tokens: InMemoryTokenStore())
        #expect(connection.state == .idle)
        #expect(await transport.requests.isEmpty)
    }

    @Test func relaunchingConnectsToTheLastAddressOnce() async {
        let transport = FakeTransport.version()
        let connection = HostConnection(
            client: HostClient(transport: transport), store: MemoryAddressStore(saved: "audio-vue"),
            tokens: InMemoryTokenStore())
        await connection.connectAtLaunch()
        #expect(connection.addressText == "audio-vue")
        #expect(connection.isPaired == false)
        await connection.connectAtLaunch()
        #expect(await transport.requests(to: .version).count == 1)
    }

    @Test func aFirstLaunchSendsNothing() async {
        let transport = FakeTransport.version()
        let connection = HostConnection(
            client: HostClient(transport: transport), store: MemoryAddressStore(),
            tokens: InMemoryTokenStore())
        await connection.connectAtLaunch()
        #expect(connection.state == .idle)
        #expect(await transport.requests.isEmpty)
    }

    @Test func theUserDefaultsStoreKeepsTheAddress() throws {
        let suite = "ConsoleCoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(UserDefaultsAddressStore(defaults: defaults).load() == nil)
        UserDefaultsAddressStore(defaults: defaults).save("audio-vue:8080")
        #expect(UserDefaultsAddressStore(defaults: defaults).load() == "audio-vue:8080")
    }
}

/// An address store held in memory.
final class MemoryAddressStore: AddressStore {
    private(set) var saved: String?

    init(saved: String? = nil) {
        self.saved = saved
    }

    func load() -> String? { saved }
    func save(_ address: String) { saved = address }
}
