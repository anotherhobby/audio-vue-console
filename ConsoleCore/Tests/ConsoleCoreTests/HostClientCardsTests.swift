import Foundation
import Testing

@testable import ConsoleCore

/// `card-code`: the host's manifest, read with the token.
struct HostClientCardsTests {
    private let token = HostToken("secret")

    private func address() throws -> HostAddress {
        try #require(HostAddress(parsing: "audio-vue"))
    }

    @Test func theManifestIsRead() async throws {
        let body =
            #"{"from": "host", "digest": "d1", "#
            + #""entries": {"src/cards/waveform": "aa", "src/glass.py": "bb"}, "#
            + #""cards": {"waveform": "src/cards/waveform"}}"#
        let transport = FakeTransport([.cardManifest: .status(200, body)])
        let read = try await HostClient(transport: transport).cardManifest(
            at: try address(), token: token)
        #expect(read.manifest.digest == "d1")
        #expect(read.manifest.entries == ["src/cards/waveform": "aa", "src/glass.py": "bb"])
        #expect(read.manifest.cards == ["waveform": "src/cards/waveform"])
        #expect(read.source == .host)
    }

    @Test func aRefusedTokenSaysSo() async throws {
        let transport = FakeTransport([.cardManifest: .status(401, #"{"detail": "token"}"#)])
        await #expect(throws: HostFailure.tokenRefused) {
            _ = try await HostClient(transport: transport).cardManifest(
                at: try address(), token: token)
        }
    }
}
