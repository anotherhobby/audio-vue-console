import Foundation
import Observation

/// A paired panel's scenes and what drawing them needs from its host (design D7): each scene's
/// document, the install's fonts block, the schema's facts, the default scene's backdrop as the
/// fallback, and every backdrop image those name, fetched into the app's store.
@MainActor @Observable
public final class PanelScenes {
    public enum State: Equatable, Sendable {
        case idle
        case loading
        case loaded
        /// The host refused the app's token, so the app is no longer paired.
        case unpaired
        case failed(HostFailure)
    }

    public private(set) var state = State.idle
    /// The scenes a user may open, in the host's order, with no fixed scene.
    public private(set) var scenes: [SceneDocument] = []
    public private(set) var facts: SchemaFacts?
    /// The panel's display size, or nil where the host does not know it.
    public let display: PixelSize?
    /// The digest of the code the panel draws with, as the host's version read gave it.
    public let cards: CardCode

    private let address: HostAddress
    private let client: HostClient
    private let pairing: Pairing
    private let store: any TokenStore
    private let images: ImageStore
    private let onUnpaired: @MainActor () -> Void
    private var fonts = JSONValue.object([:])
    private var fallback = JSONValue.null

    init(
        address: HostAddress, host: HostIdentity?, cards: CardCode, client: HostClient,
        access: (pairing: Pairing, store: any TokenStore), images: ImageStore,
        onUnpaired: @escaping @MainActor () -> Void
    ) {
        self.address = address
        display = host.flatMap { host in
            host.widthPx.flatMap { width in
                host.heightPx.map { PixelSize(width: width, height: $0) }
            }
        }
        self.cards = cards
        self.client = client
        pairing = access.pairing
        store = access.store
        self.images = images
        self.onUnpaired = onUnpaired
    }

    /// What every request for this panel carries besides the scene.
    public var context: RenderContext {
        RenderContext(
            display: display ?? .unknownPanel, fonts: fonts, images: images.directory,
            fallback: fallback)
    }

    /// Reads the scenes and what drawing them needs, then fetches the images they name.
    public func load() async {
        state = .loading
        do throws(HostFailure) {
            let token = pairing.token
            let listed = try await client.scenes(at: address, token: token)
            var documents: [SceneDocument] = []
            for scene in listed {
                documents.append(try await client.scene(scene.id, at: address, token: token))
            }
            let install = try await client.install(at: address, token: token)
            guard
                let facts = SchemaFacts(schema: try await client.schema(at: address, token: token))
            else { throw .unexpectedAnswer }
            fonts = install["fonts"] ?? .object([:])
            fallback = documents.first { $0.id == Self.defaultScene }?.doc["backdrop"] ?? .null
            for id in Self.images(in: documents.map(\.doc) + [.object(["backdrop": fallback])]) {
                _ = try await images.fetch(id, at: address, token: token)
            }
            self.facts = facts
            scenes = documents.filter { !$0.fixed }
            state = .loaded
        } catch {
            fail(error)
        }
    }

    /// Compares the card code a helper carries with the panel's (`card-code`).
    public func cardCode(helperDigest: String, bundled: CardManifest?) async -> CardCodeVerdict? {
        let (client, address, token) = (client, address, pairing.token)
        do throws(HostFailure) {
            return try await CardCodeCheck.verdict(
                helperDigest: helperDigest, bundled: bundled, version: cards
            ) { () throws(HostFailure) in
                try await client.cardManifest(at: address, token: token)
            }
        } catch {
            fail(error)
            return nil
        }
    }

    /// The scene the panel falls back to when a backdrop image is missing (audio-vue `scene.py`).
    static let defaultScene = "default"

    /// The backdrop image ids `docs` name, once each.
    private static func images(in docs: [JSONValue]) -> [String] {
        var seen: [String] = []
        for case let id? in docs.map({ $0["backdrop"]?["image"]?.stringValue })
        where !seen.contains(id) {
            seen.append(id)
        }
        return seen
    }

    private func fail(_ failure: HostFailure) {
        guard failure == .tokenRefused else {
            state = .failed(failure)
            return
        }
        store.forget(host: pairing.hostID)
        state = .unpaired
        onUnpaired()
    }
}
