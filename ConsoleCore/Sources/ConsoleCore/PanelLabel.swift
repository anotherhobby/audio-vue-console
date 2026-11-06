/// How the panel picker names a panel (`panel-window`, "The picker names the panel"): by the host's
/// name once paired, else by its address; by its display's shape where the host gives a size; and
/// up only while the live state is current and says so.
public struct PanelLabel: Sendable, Equatable {
    public let name: String
    public let shape: String?
    public let isUp: Bool

    public init(name: String, shape: String?, isUp: Bool) {
        self.name = name
        self.shape = shape
        self.isUp = isUp
    }

    /// The label for the panel at `address`, with `host` the identity read while paired (nil when
    /// not), and `state` the live state, current or not. Nil without an address.
    public init?(address: HostAddress?, host: HostIdentity?, state: PanelState?, isLive: Bool) {
        guard let address else { return nil }
        let width = state?.displayWidthPx ?? host?.widthPx
        let height = state?.displayHeightPx ?? host?.heightPx
        name = host?.name ?? address.description
        if let width, let height {
            shape = DisplayShape.name(width: width, height: height)
        } else {
            shape = nil
        }
        isUp = isLive && state?.condition == .up
    }
}
