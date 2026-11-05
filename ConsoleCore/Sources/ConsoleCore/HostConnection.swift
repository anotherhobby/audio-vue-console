import Observation

/// One host, reached at the address the user gives: the state the connect view shows, and the
/// connect that moves it. At launch it connects once to the last address a host answered at.
@MainActor @Observable
public final class HostConnection {
    public enum State: Equatable, Sendable {
        case idle
        /// The text is not an address, so nothing was sent.
        case invalidAddress
        case connecting(HostAddress)
        /// Connected to a compatible host, and whether the host takes the token the app keeps for
        /// it at this address.
        case connected(HostAddress, HostVersion, paired: Bool)
        /// The host answered with a version this app does not speak; `api.compatibility` says
        /// whether it is newer or older.
        case incompatible(HostAddress, HostVersion)
        case failed(HostAddress, HostFailure)
    }

    /// The address as the user types it, starting from the last one a host answered at.
    public var addressText: String
    public private(set) var state = State.idle
    /// The pairing the app is showing, set by `pair()` and cleared when the user closes it.
    public var pairing: HostPairing?
    /// The clients list the app is showing, set by `showClients()` and cleared when closed.
    public var clients: PairedClients?

    private let client: HostClient
    private let store: any AddressStore
    private let tokens: any TokenStore
    /// The address remembered from the last launch, which `connectAtLaunch()` connects to once.
    private var launchAddress: String?

    /// A connection keeping its tokens in `tokens`, which has no default, so nothing but the app
    /// reaches the real file (design D3).
    public init(
        client: HostClient = HostClient(), store: any AddressStore = UserDefaultsAddressStore(),
        tokens: any TokenStore
    ) {
        self.client = client
        self.store = store
        self.tokens = tokens
        let saved = store.load()
        launchAddress = saved
        addressText = saved ?? ""
    }

    /// Connects to the address remembered from the last launch, once, and only if nothing has
    /// happened since; with none remembered it sends nothing (`host-connection`).
    public func connectAtLaunch() async {
        guard let address = launchAddress, state == .idle else { return }
        launchAddress = nil
        addressText = address
        await connect()
    }

    /// Reads the version at the typed address, then whether the host takes the token kept for it.
    /// The address is saved once a host answers with a version, compatible or not. A connect
    /// already under way is left to finish.
    public func connect() async {
        if case .connecting = state { return }
        guard let address = HostAddress(parsing: addressText) else {
            state = .invalidAddress
            return
        }
        state = .connecting(address)
        do {
            let version = try await client.version(at: address)
            store.save(address.description)
            guard version.api.compatibility == .compatible else {
                state = .incompatible(address, version)
                return
            }
            let paired = try await isPaired(at: address)
            state = .connected(address, version, paired: paired)
        } catch {
            state = .failed(address, error)
        }
    }

    /// Whether the app is paired with the connected host, or nil when not connected to one.
    public var isPaired: Bool? {
        guard case .connected(_, _, let paired) = state else { return nil }
        return paired
    }

    /// Starts showing a pairing with the connected host, if connected.
    public func pair(name: String = ClientName.current) {
        pairing = makePairing(name: name)
    }

    /// Starts showing the connected host's clients, if connected and paired.
    public func showClients() {
        clients = makeClients()
    }

    /// A pairing with the connected host, which marks the connection paired once it keeps a
    /// token, or nil when not connected.
    public func makePairing(name: String = ClientName.current) -> HostPairing? {
        guard case .connected(let address, _, _) = state else { return nil }
        return HostPairing(address: address, client: client, store: tokens, name: name) {
            [weak self] _ in self?.mark(paired: true, at: address)
        }
    }

    /// The connected host's clients, which mark the connection not paired once its token is
    /// forgotten, or nil when not connected and paired.
    public func makeClients() -> PairedClients? {
        guard case .connected(let address, _, paired: true) = state,
            let pairing = tokens.pairing(at: address)
        else { return nil }
        return PairedClients(address: address, client: client, pairing: pairing, store: tokens) {
            [weak self] in self?.mark(paired: false, at: address)
        }
    }

    /// Whether the host at `address` takes the token kept for it (design D6). One it refuses is
    /// forgotten; any other failure is the connect's.
    private func isPaired(at address: HostAddress) async throws(HostFailure) -> Bool {
        guard let pairing = tokens.pairing(at: address) else { return false }
        do {
            _ = try await client.host(at: address, token: pairing.token)
            return true
        } catch {
            guard error == .tokenRefused else { throw error }
            tokens.forget(host: pairing.hostID)
            return false
        }
    }

    private func mark(paired: Bool, at address: HostAddress) {
        guard case .connected(address, let version, _) = state else { return }
        state = .connected(address, version, paired: paired)
    }
}
