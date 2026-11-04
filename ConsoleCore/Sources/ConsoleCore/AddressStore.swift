import Foundation

/// Where the last address a host answered at is kept between launches.
public protocol AddressStore {
    func load() -> String?
    func save(_ address: String)
}

/// The app's address store, in `UserDefaults`.
public struct UserDefaultsAddressStore: AddressStore {
    private static let key = "lastHostAddress"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> String? {
        defaults.string(forKey: Self.key)
    }

    public func save(_ address: String) {
        defaults.set(address, forKey: Self.key)
    }
}
