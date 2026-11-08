import Foundation
import Testing

@testable import ConsoleCore

/// Against a real host, skipped unless asked for (task 4.4): the live state arrives over the real
/// socket, and its handshake is not refused, which rules out an `Origin` added by URLSession. Run
/// with the host's address and the folder of a `pairings.json` holding a pairing for it:
///
///     AUDIO_VUE_LIVE_HOST=<address> AUDIO_VUE_PAIRINGS_DIR=<folder> \
///         xcrun swift test --filter LiveHostTests
@MainActor
@Suite(.enabled(if: LiveHost.isAsked))
struct LiveHostTests {
    private static let patience = Duration.seconds(10)
    private static let step = Duration.milliseconds(100)

    @Test func theLiveStateArrives() async throws {
        let host = try #require(LiveHost.host)
        let folder = try #require(LiveHost.pairings)
        let address = try #require(HostAddress(parsing: host))
        let tokens = FileTokenStore(directory: URL(filePath: folder))
        let pairing = try #require(tokens.pairing(at: address), "No pairing for the host")
        var refused = false
        let live = LiveState(address: address, pairing: pairing, tokens: ReadOnlyTokens(tokens)) {
            refused = true
        }
        let watching = Task { await live.watch() }
        let clock = ContinuousClock()
        let deadline = clock.now + Self.patience
        while live.state == nil, !refused, clock.now < deadline {
            try await Task.sleep(for: Self.step)
        }
        watching.cancel()
        await watching.value
        #expect(!refused)
        let state = try #require(live.state, "No state arrived")
        print("Live state: \(state)")
    }

    /// `host-discovery`: the host is found on the LAN by the id it gives with the token, and the
    /// address its announcement resolves to answers. `swift test` runs outside the app's sandbox,
    /// so macOS asks the app that launched it for local network access.
    @Test func theHostIsFoundByItsID() async throws {
        let host = try #require(LiveHost.host)
        let folder = try #require(LiveHost.pairings)
        let address = try #require(HostAddress(parsing: host))
        let tokens = FileTokenStore(directory: URL(filePath: folder))
        let pairing = try #require(tokens.pairing(at: address), "No pairing for the host")
        let identity = try await HostClient().host(at: address, token: pairing.token)
        let discovery = PanelDiscovery()
        let browsing = Task { await discovery.browse() }
        let finding = Task { await discovery.panel(withID: identity.id) }
        let deadline = Task {
            try await Task.sleep(for: Self.patience)
            finding.cancel()
        }
        let found = await finding.value
        deadline.cancel()
        let panel = try #require(found, "No panel announced with id \(identity.id)")
        let resolved = try await discovery.address(of: panel)
        browsing.cancel()
        await browsing.value
        let version = try await HostClient().version(at: resolved)
        print("Found \(panel.name) at \(resolved), API \(version.api)")
    }
}

/// `scene-gallery` and `scene-canvas` against the real host: its scenes in the gallery's sections
/// for its display's shape, and its schema's library in the panel's order, printed for a reader.
@Suite(.enabled(if: LiveHost.isAsked))
struct LiveGalleryTests {
    private struct Entry: GalleryEntry {
        let name: String
        let builtIn: Bool
        let grid: CellSize?
    }

    @Test func theGalleryAndTheLibrary() async throws {
        let host = try #require(LiveHost.host)
        let folder = try #require(LiveHost.pairings)
        let address = try #require(HostAddress(parsing: host))
        let tokens = FileTokenStore(directory: URL(filePath: folder))
        let token = try #require(tokens.pairing(at: address), "No pairing for the host").token
        let client = HostClient()
        let identity = try await client.host(at: address, token: token)
        let schema = try await client.schema(at: address, token: token)
        let facts = try #require(SchemaFacts(schema: schema))
        var entries: [Entry] = []
        for summary in try await client.scenes(at: address, token: token) where !summary.fixed {
            let document = try await client.scene(summary.id, at: address, token: token)
            let laidOut = try LaidOutScene(document, defaultGrid: facts.defaultGrid)
            entries.append(
                Entry(
                    name: document.name ?? document.id, builtIn: document.builtIn,
                    grid: laidOut.layout.grid))
        }
        let panel = DisplayShape(
            width: try #require(identity.widthPx), height: try #require(identity.heightPx))
        let sections = GallerySections(entries, panel: panel, defaultGrid: facts.defaultGrid)
        print("Panel \(panel)")
        print("My Scenes: \(sections.mine.map(\.name))")
        print("Built-in Scenes: \(sections.builtIn.map(\.name))")
        print("Other Shapes: \(sections.otherShapes.map(\.name))")
        for shelf in facts.library {
            print("\(shelf.category.label): \(shelf.cards.map(\.name))")
        }
        #expect(!facts.library.isEmpty)
        #expect(!facts.library.contains { $0.category.id == "calibration" })
    }
}

/// The host the run asked for, by the environment.
private enum LiveHost {
    static let host = ProcessInfo.processInfo.environment["AUDIO_VUE_LIVE_HOST"]
    static let pairings = ProcessInfo.processInfo.environment["AUDIO_VUE_PAIRINGS_DIR"]
    static var isAsked: Bool { host != nil && pairings != nil }
}

/// The real token file, read but never written, so a test cannot forget the maintainer's token.
private struct ReadOnlyTokens: TokenStore {
    let store: FileTokenStore

    init(_ store: FileTokenStore) {
        self.store = store
    }

    func pairing(at address: HostAddress) -> Pairing? { store.pairing(at: address) }
    func pairing(forHost hostID: String) -> Pairing? { store.pairing(forHost: hostID) }
    func save(_ pairing: Pairing, at address: HostAddress) throws {}
    func forget(host hostID: String) {}
}
