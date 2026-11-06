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
