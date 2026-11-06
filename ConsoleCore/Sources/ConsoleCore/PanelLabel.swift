/// How the panel picker names a panel (`panel-window`, "The picker names the panel"): by the host's
/// name once paired, else by its address, else by the instance name it was found under; and whether
/// it was discovered on the network, which is said only while not paired (discovery design D11).
public struct PanelLabel: Sendable, Equatable {
    public let name: String
    /// Found on the network and not paired.
    public let isDiscovered: Bool

    public init(name: String, isDiscovered: Bool) {
        self.name = name
        self.isDiscovered = isDiscovered
    }

    /// The label for the panel at `address`, with `host` the identity read while paired (nil when
    /// not) and `foundName` the instance name it was found under (nil when it is not found). Nil
    /// with neither an address nor a found name.
    public init?(address: HostAddress?, host: HostIdentity?, foundName: String? = nil) {
        guard let name = host?.name ?? address?.description ?? foundName else { return nil }
        self.name = name
        isDiscovered = host == nil && foundName != nil
    }
}
