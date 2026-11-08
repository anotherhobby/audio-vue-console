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

    /// Stores `draft` on the host (design D3): a copy never saved is created, any other scene written
    /// on `overRev`, or on the draft's revision. The scene is then read again, so the app holds the
    /// host's document and revision, not what it sent; a created scene's id is the host's.
    public func save(_ draft: Draft, overRev: Int? = nil) async throws(HostFailure)
        -> SceneDocument
    {
        let token = pairing.token
        do throws(HostFailure) {
            if SceneDrafts.isCopy(draft.id) {
                let created = try await client.createScene(
                    doc: draft.doc, at: address, token: token)
                return try await reread(created.id, listing: true)
            }
            guard let base = overRev ?? draft.rev else { throw .unexpectedAnswer }
            _ = try await client.writeScene(
                draft.id, doc: draft.doc, baseRev: base, at: address, token: token)
            return try await reread(draft.id, listing: false)
        } catch {
            throw unpairing(error)
        }
    }

    /// Renames the stored scene `id` by writing the host's document with `name` set (design D4),
    /// trimmed and refused when empty before any request. A stale base is read again and written
    /// once more, since only the name changes.
    public func rename(_ id: String, to name: String) async throws(HostFailure) -> SceneDocument {
        guard let name = Self.name(name) else {
            throw .invalid([DocumentFailure(place: "name", message: Self.needsAName)])
        }
        do throws(HostFailure) {
            guard let held = scenes.first(where: { $0.id == id }) else { throw .notFound }
            do throws(HostFailure) {
                try await write(name, over: held)
            } catch .stale {
                let current = try await client.scene(id, at: address, token: pairing.token)
                try await write(name, over: current)
            }
            return try await reread(id, listing: true)
        } catch {
            throw unpairing(error)
        }
    }

    /// Deletes the stored scene `id` on the host and from `scenes`.
    public func delete(_ id: String) async throws(HostFailure) {
        do throws(HostFailure) {
            try await client.deleteScene(id, at: address, token: pairing.token)
            scenes.removeAll { $0.id == id }
        } catch {
            throw unpairing(error)
        }
    }

    /// Switches the panel to the scene `id`, a stored scene at its current revision (design D8).
    public func switchTo(_ id: String) async throws(HostFailure) -> CommandOutcome {
        do throws(HostFailure) {
            return try await client.switchScene(id, at: address, token: pairing.token)
        } catch {
            throw unpairing(error)
        }
    }

    /// Reset (design D11): restarts the panel's measurement.
    public func reset() async throws(HostFailure) -> CommandOutcome {
        do throws(HostFailure) {
            return try await client.resetPanel(at: address, token: pairing.token)
        } catch {
            throw unpairing(error)
        }
    }

    /// The stored scene `id`'s kept earlier revisions, newest first, for the Versions menu.
    public func revisions(_ id: String) async throws(HostFailure) -> [SceneRevision] {
        do throws(HostFailure) {
            return try await client.sceneRevisions(id, at: address, token: pairing.token)
        } catch {
            throw unpairing(error)
        }
    }

    /// Reads the scene `id` again and holds the host's document, as Discard Mine does.
    public func refresh(_ id: String) async throws(HostFailure) {
        do throws(HostFailure) {
            _ = try await reread(id, listing: false)
        } catch {
            throw unpairing(error)
        }
    }

    /// `name` trimmed, or nil where nothing is left: a scene needs a name.
    public static func name(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public static let needsAName = "A scene needs a name."

    private func write(_ name: String, over document: SceneDocument) async throws(HostFailure) {
        guard let rev = document.rev else { throw .unexpectedAnswer }
        var doc = document.doc.objectValue ?? [:]
        doc["name"] = .string(name)
        _ = try await client.writeScene(
            document.id, doc: .object(doc), baseRev: rev, at: address, token: pairing.token)
    }

    /// Reads the scene `id` again and holds it in place of what was held, reading the listing too
    /// where the scene's place in the host's order may have changed.
    private func reread(_ id: String, listing: Bool) async throws(HostFailure) -> SceneDocument {
        let token = pairing.token
        let document = try await client.scene(id, at: address, token: token)
        guard listing else {
            scenes = scenes.map { $0.id == id ? document : $0 }
            return document
        }
        let order = try await client.scenes(at: address, token: token).filter { !$0.fixed }
        let held = Dictionary(uniqueKeysWithValues: scenes.map { ($0.id, $0) })
        scenes = order.compactMap { $0.id == id ? document : held[$0.id] }
        return document
    }

    /// `failure` as it is thrown back, a refused token having unpaired the app first.
    private func unpairing(_ failure: HostFailure) -> HostFailure {
        if failure == .tokenRefused { fail(failure) }
        return failure
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
