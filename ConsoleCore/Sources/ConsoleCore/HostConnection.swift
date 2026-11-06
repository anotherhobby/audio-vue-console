import Observation

/// One host, reached at an address the user gives or at a panel found on the network: the state the
/// window shows, and the connect that moves it. At launch it connects once to the last address a
/// host answered at, and, when that cannot be reached, to the panel announced with that host's id
/// (discovery design D5).
@MainActor @Observable
public final class HostConnection {
    public enum State: Equatable, Sendable {
        case idle
        /// The text is not an address, so nothing was sent.
        case invalidAddress
        case connecting(HostAddress)
        /// Connected to a compatible host, and whether the host takes the token the app keeps for
        /// it.
        case connected(HostAddress, HostVersion, paired: Bool)
        /// The host answered with a version this app does not speak; `api.compatibility` says
        /// whether it is newer or older.
        case incompatible(HostAddress, HostVersion)
        case failed(HostAddress, HostFailure)
        /// The found panel of this name could not be resolved to an address.
        case unresolved(String, HostFailure)
    }

    /// The address as the user types it, starting from the last one a host answered at.
    public var addressText: String
    public private(set) var state = State.idle
    /// The pairing the app is showing, set by `pair()` and cleared when the user closes it.
    public var pairing: HostPairing?
    /// The connected host's identity, read when the app finds itself paired with it, and nil when
    /// not paired.
    public private(set) var host: HostIdentity?
    /// The found panel the connection was made to, or nil for a typed address (design D4).
    public private(set) var foundPanel: FoundPanel?

    private let client: HostClient
    private let store: any AddressStore
    private let tokens: any TokenStore
    private let discovery: PanelDiscovery
    /// The host remembered from the last launch, which `connectAtLaunch()` connects to once.
    private var launchHost: RememberedHost?
    /// The wait for the last launch's panel to be announced (design D5).
    private var launchWait: Task<Void, Never>?

    /// A connection keeping its tokens in `tokens` and finding panels with `discovery`, neither of
    /// which has a default, so nothing but the app reaches the real file or the network's browse.
    public init(
        client: HostClient = HostClient(), store: any AddressStore = UserDefaultsAddressStore(),
        tokens: any TokenStore, discovery: PanelDiscovery
    ) {
        self.client = client
        self.store = store
        self.tokens = tokens
        self.discovery = discovery
        let saved = store.load()
        launchHost = saved
        addressText = saved?.address ?? ""
    }

    /// Connects to the address remembered from the last launch, once, and only if nothing has
    /// happened since; with none remembered it sends nothing (`host-connection`). When the address
    /// cannot be reached and the host's id is remembered, a wait starts for the panel announced
    /// with it; this returns without waiting.
    public func connectAtLaunch() async {
        guard let remembered = launchHost, state == .idle else { return }
        launchHost = nil
        addressText = remembered.address
        await connect()
        guard case .failed(_, .unreachable) = state, let hostID = remembered.hostID else { return }
        launchWait = Task { [weak self, discovery] in
            guard let panel = await discovery.panel(withID: hostID) else { return }
            await self?.join(panel)
        }
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
        stopWaiting()
        foundPanel = nil
        await connect(at: address, announcedID: nil)
    }

    /// Connects to a panel found on the network, at the address it is announced at, with the token
    /// kept for the host it names by id (design D4).
    public func connect(to panel: FoundPanel) async {
        if case .connecting = state { return }
        stopWaiting()
        await join(panel)
    }

    /// The address the connection is at, connected or not, or nil before one is known.
    public var address: HostAddress? {
        switch state {
        case .idle, .invalidAddress, .unresolved: nil
        case .connecting(let address), .connected(let address, _, _),
            .incompatible(let address, _), .failed(let address, _):
            address
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

    /// A pairing with the connected host, which marks the connection paired once it keeps a
    /// token, or nil when not connected.
    public func makePairing(name: String = ClientName.current) -> HostPairing? {
        guard case .connected(let address, _, _) = state else { return nil }
        return HostPairing(address: address, client: client, store: tokens, name: name) {
            [weak self] _, host in
            self?.host = host
            self?.store.save(address.description, hostID: host.id)
            self?.mark(paired: true, at: address)
        }
    }

    /// The connected host's clients, which mark the connection not paired once its token is
    /// forgotten, or nil when not connected and paired.
    public func makeClients() -> PairedClients? {
        guard case .connected(let address, _, paired: true) = state,
            let pairing = keptPairing(at: address)
        else { return nil }
        return PairedClients(address: address, client: client, pairing: pairing, store: tokens) {
            [weak self] in self?.mark(paired: false, at: address)
        }
    }

    /// The live state of the connected host, for the window to watch, or nil when not connected
    /// and paired. A token the host refuses on it marks the connection not paired.
    public func liveState() -> LiveState? {
        guard case .connected(let address, _, paired: true) = state,
            let pairing = keptPairing(at: address)
        else { return nil }
        return LiveState(address: address, pairing: pairing, tokens: tokens) { [weak self] in
            self?.mark(paired: false, at: address)
        }
    }

    /// Ends when the launch's wait for its panel does, for tests.
    func launchWaitEnded() async {
        await launchWait?.value
    }

    private func join(_ panel: FoundPanel) async {
        foundPanel = panel
        do {
            let address = try await discovery.address(of: panel)
            addressText = address.description
            await connect(at: address, announcedID: panel.id)
        } catch {
            state = .unresolved(panel.name, error)
        }
    }

    private func connect(at address: HostAddress, announcedID: String?) async {
        state = .connecting(address)
        host = nil
        do {
            let version = try await client.version(at: address)
            store.save(address.description, hostID: announcedID)
            guard version.api.compatibility == .compatible else {
                state = .incompatible(address, version)
                return
            }
            let paired = try await isPaired(at: address, announcedID: announcedID)
            state = .connected(address, version, paired: paired)
        } catch {
            state = .failed(address, error)
        }
    }

    /// Whether the host at `address` takes the token kept for it, keeping the host it reads (the
    /// pairing change's design D6). A found panel's token is the one kept for the id it announced,
    /// and the host must give that id back, which links the address to it (discovery design D4).
    /// A token refused is forgotten; any other failure is the connect's.
    private func isPaired(at address: HostAddress, announcedID: String?) async throws(HostFailure)
        -> Bool
    {
        let kept =
            if let announcedID {
                tokens.pairing(forHost: announcedID)
            } else {
                tokens.pairing(at: address)
            }
        guard let pairing = kept else { return false }
        do {
            let identity = try await client.host(at: address, token: pairing.token)
            guard identity.id == pairing.hostID else { return false }
            host = identity
            store.save(address.description, hostID: identity.id)
            if announcedID != nil { link(address, to: pairing) }
            return true
        } catch {
            guard error == .tokenRefused else { throw error }
            tokens.forget(host: pairing.hostID)
            return false
        }
    }

    /// Points `address` at the host `pairing` is for, so a typed or remembered connect to it later
    /// finds the token too.
    private func link(_ address: HostAddress, to pairing: Pairing) {
        do {
            try tokens.save(pairing, at: address)
        } catch {
            // Unlinked, the address still connects paired as a found panel, and links next time.
        }
    }

    /// The pairing the connected host was found paired by: the one kept for its id once read, else
    /// the one its address points at.
    private func keptPairing(at address: HostAddress) -> Pairing? {
        host.flatMap { tokens.pairing(forHost: $0.id) } ?? tokens.pairing(at: address)
    }

    private func stopWaiting() {
        launchWait?.cancel()
        launchWait = nil
    }

    private func mark(paired: Bool, at address: HostAddress) {
        guard case .connected(address, let version, _) = state else { return }
        if !paired { host = nil }
        state = .connected(address, version, paired: paired)
    }
}
