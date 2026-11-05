/// What pairing with a host left this app: the host's id, the token, and the id the host gave this
/// app as a client.
public struct Pairing: Sendable, Equatable {
    public let hostID: String
    public let token: HostToken
    public let clientID: String

    public init(hostID: String, token: HostToken, clientID: String) {
        self.hostID = hostID
        self.token = token
        self.clientID = clientID
    }
}

/// Where the app keeps one pairing per host between launches (`host-pairing`, "The app keeps one
/// token per host"). Pairings are kept by host id, and each address points at the id it led to,
/// since the confirm gives no host id and a host can be reached at more than one address.
public protocol TokenStore {
    /// The pairing of the host this address last led to, if the app keeps one.
    func pairing(at address: HostAddress) -> Pairing?
    /// The pairing kept for a host id, whatever address it was reached at.
    func pairing(forHost hostID: String) -> Pairing?
    /// Keeps a pairing for its host, replacing any earlier one, and points the address at it.
    func save(_ pairing: Pairing, at address: HostAddress) throws
    /// Drops a host's pairing and every address pointing at it. It is called only for a token the
    /// host no longer takes, so a store that fails to write it loses nothing: the next connect is
    /// refused the token and forgets it again.
    func forget(host hostID: String)
}

/// The pairings a token store holds, and the rules for changing them, kept apart from where they
/// are written so every store follows the same rules.
struct Pairings: Codable, Equatable {
    struct Entry: Codable, Equatable {
        let token: HostToken
        let clientID: String

        enum CodingKeys: String, CodingKey {
            case token
            case clientID = "client_id"
        }
    }

    private(set) var hosts: [String: Entry] = [:]
    /// Each address, as `HostAddress.description` gives it, to the host id it led to.
    private(set) var addresses: [String: String] = [:]

    func pairing(at address: HostAddress) -> Pairing? {
        addresses[address.description].flatMap(pairing(forHost:))
    }

    func pairing(forHost hostID: String) -> Pairing? {
        hosts[hostID].map { Pairing(hostID: hostID, token: $0.token, clientID: $0.clientID) }
    }

    mutating func save(_ pairing: Pairing, at address: HostAddress) {
        hosts[pairing.hostID] = Entry(token: pairing.token, clientID: pairing.clientID)
        addresses[address.description] = pairing.hostID
    }

    mutating func forget(host hostID: String) {
        hosts[hostID] = nil
        addresses = addresses.filter { $0.value != hostID }
    }
}
