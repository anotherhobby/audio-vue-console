import Foundation

/// The last address a host answered at, with that host's id when the app knew it (discovery design
/// D5): read with the token, or from the panel's announcement.
public struct RememberedHost: Sendable, Equatable {
    public let address: String
    public let hostID: String?

    public init(address: String, hostID: String?) {
        self.address = address
        self.hostID = hostID
    }
}

/// Where the last host answered is kept between launches.
public protocol AddressStore {
    func load() -> RememberedHost?
    /// Keeps `address` as the last one answered at, with its host's id, or none when it is not
    /// known, which forgets any id kept before.
    func save(_ address: String, hostID: String?)
}

/// The app's address store, in `UserDefaults`.
public struct UserDefaultsAddressStore: AddressStore {
    private static let addressKey = "lastHostAddress"
    private static let hostIDKey = "lastHostID"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> RememberedHost? {
        defaults.string(forKey: Self.addressKey).map {
            RememberedHost(address: $0, hostID: defaults.string(forKey: Self.hostIDKey))
        }
    }

    public func save(_ address: String, hostID: String?) {
        defaults.set(address, forKey: Self.addressKey)
        defaults.set(hostID, forKey: Self.hostIDKey)
    }
}
