import Foundation

/// What comparing the app's card code with a panel's found (`card-code`, `render-runtime`).
public enum CardCodeVerdict: Sendable, Equatable {
    /// The same code: every card is drawn by the helper.
    case same
    /// The code differs, entry by entry.
    case differs(CardDrift)
    /// The app's own bundle does not match its manifest, so no comparison can be trusted.
    case damagedBundle
    /// The host's manifest could not be read, so the code cannot be compared.
    case unreadable
}

/// Compares the card code the app carries with the code the host says its panel draws with.
public enum CardCodeCheck {
    /// The manifest the app's bundle carries, `manifest.json`.
    public static func bundledManifest(at file: URL) throws -> CardManifest {
        let json = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: file))
        guard let digest = json["digest"]?.stringValue, let entries = json["entries"]?.objectValue,
            let cards = json["cards"]?.objectValue
        else { throw CocoaError(.fileReadCorruptFile) }
        return CardManifest(
            digest: digest, entries: entries.compactMapValues(\.stringValue),
            cards: cards.compactMapValues(\.stringValue))
    }

    /// The verdict for a helper whose code's digest is `helperDigest`, carrying `bundled`, against
    /// the host's `version`. The host's manifest is read, through `hostManifest`, only when the
    /// digests differ.
    public static func verdict(
        helperDigest: String, bundled: CardManifest?, version: CardCode,
        hostManifest:
            @Sendable () async throws(HostFailure) -> (
                manifest: CardManifest, source: CardCode.Source
            )
    ) async throws(HostFailure) -> CardCodeVerdict {
        guard let bundled, bundled.digest == helperDigest else { return .damagedBundle }
        if version.digest == helperDigest { return .same }
        let host = try await hostManifest()
        return .differs(
            CardDrift.between(bundled: bundled, host: host.manifest, source: host.source))
    }
}

extension CardCodeVerdict {
    /// What the gallery says when no card can be drawn, or nil when cards are drawn.
    public var noCardsReason: String? {
        switch self {
        case .same: return nil
        case .damagedBundle:
            return "This app's render bundle doesn't match its manifest, so no card is drawn. "
                + "Rebuild the app."
        case .unreadable:
            return "The panel's card code can't be read, so no card is drawn. "
                + "Deploy audio-vue to the panel."
        case .differs(let drift):
            guard drift.sharesNothing else { return nil }
            let next =
                drift.source == .host
                ? "The panel isn't running, so this is the code it will run at its next start."
                : "Deploy audio-vue to the panel, or rebuild the app with the panel's code."
            return "This app's code for \(CardDrift.listed(drift.shared)) differs from "
                + "the panel's, so no card is drawn. \(next)"
        }
    }
}
