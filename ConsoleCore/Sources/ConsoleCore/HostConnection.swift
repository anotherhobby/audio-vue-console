import Observation

/// One host, reached at the address the user gives: the state the connect view shows, and the
/// connect that moves it. It connects only when asked, never on its own at launch.
@MainActor @Observable
public final class HostConnection {
    public enum State: Equatable, Sendable {
        case idle
        /// The text is not an address, so nothing was sent.
        case invalidAddress
        case connecting(HostAddress)
        case connected(HostAddress, HostVersion)
        /// The host answered with a version this app does not speak; `api.compatibility` says
        /// whether it is newer or older.
        case incompatible(HostAddress, HostVersion)
        case failed(HostAddress, HostFailure)
    }

    /// The address as the user types it, starting from the last one a host answered at.
    public var addressText: String
    public private(set) var state = State.idle

    private let client: HostClient
    private let store: any AddressStore

    public init(
        client: HostClient = HostClient(), store: any AddressStore = UserDefaultsAddressStore()
    ) {
        self.client = client
        self.store = store
        addressText = store.load() ?? ""
    }

    /// Reads the version at the typed address. The address is saved once a host answers with a
    /// version, compatible or not. A connect already under way is left to finish.
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
            let compatible = version.api.compatibility == .compatible
            state = compatible ? .connected(address, version) : .incompatible(address, version)
        } catch {
            state = .failed(address, error)
        }
    }
}
