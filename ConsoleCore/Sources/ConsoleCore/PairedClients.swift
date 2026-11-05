import Observation

/// The clients paired with a host this app is paired with: listing them, with this app marked,
/// and revoking any of them (`host-pairing`).
@MainActor @Observable
public final class PairedClients: Identifiable {
    public enum State: Equatable, Sendable {
        case idle
        case loading
        case loaded
        /// The app is no longer paired: it revoked itself, or the host refused its token.
        case unpaired
        case failed(HostFailure)
    }

    public let address: HostAddress
    public private(set) var state = State.idle
    public private(set) var clients: [PairedClient] = []

    private let client: HostClient
    private let pairing: Pairing
    private let store: any TokenStore
    private let onUnpaired: @MainActor () -> Void

    /// The clients of the host `pairing` is for, calling `onUnpaired` once its token is forgotten.
    init(
        address: HostAddress, client: HostClient, pairing: Pairing, store: any TokenStore,
        onUnpaired: @escaping @MainActor () -> Void
    ) {
        self.address = address
        self.client = client
        self.pairing = pairing
        self.store = store
        self.onUnpaired = onUnpaired
    }

    /// Whether a listed client is this app, by the id the host gave it when it paired.
    public func isThisApp(_ listed: PairedClient) -> Bool {
        listed.id == pairing.clientID
    }

    /// Reads the host's list.
    public func load() async {
        state = .loading
        do {
            clients = try await client.clients(at: address, token: pairing.token)
            state = .loaded
        } catch {
            fail(error)
        }
    }

    /// Revokes a client, once the user has confirmed it. Revoking this app forgets its token; any
    /// other is followed by reading the list again. One the host no longer lists is gone already.
    public func revoke(_ listed: PairedClient) async {
        do {
            try await client.revoke(listed.id, at: address, token: pairing.token)
        } catch {
            guard error == .unknownClient else {
                fail(error)
                return
            }
        }
        if isThisApp(listed) {
            unpair()
        } else {
            await load()
        }
    }

    private func fail(_ failure: HostFailure) {
        if failure == .tokenRefused {
            unpair()
        } else {
            state = .failed(failure)
        }
    }

    private func unpair() {
        store.forget(host: pairing.hostID)
        clients = []
        state = .unpaired
        onUnpaired()
    }
}
