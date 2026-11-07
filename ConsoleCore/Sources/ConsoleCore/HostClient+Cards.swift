import HostAPI

/// A card code's manifest: a SHA-256 for each card family's directory, each shared module and each
/// font, by repository path, the digest they make, and each card's family entry (`card-code`).
public struct CardManifest: Sendable, Equatable {
    public let digest: String
    public let entries: [String: String]
    /// Each card, by name, mapped to the key in `entries` of the family directory declaring it.
    public let cards: [String: String]

    public init(digest: String, entries: [String: String], cards: [String: String] = [:]) {
        self.digest = digest
        self.entries = entries
        self.cards = cards
    }
}

/// The host's card manifest, read with a token, so a digest that differs from the app's can be
/// told apart entry by entry.
extension HostClient {
    /// `GET /v1/cards/manifest`: the manifest from where the version's digest came from.
    public func cardManifest(at address: HostAddress, token: HostToken) async throws(HostFailure)
        -> (manifest: CardManifest, source: CardCode.Source)
    {
        let output = try await call(at: address, token: token) {
            try await $0.cardManifestV1CardsManifestGet()
        }
        guard case .ok(let ok) = output else { throw .unexpectedAnswer }
        let body = try Self.body { try ok.body.json }
        let manifest = CardManifest(
            digest: body.digest, entries: body.entries.additionalProperties,
            cards: body.cards.additionalProperties)
        return (manifest, body.from == .panel ? .panel : .host)
    }
}
