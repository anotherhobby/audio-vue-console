import Foundation

/// What a browse for `_audio-vue._tcp` says, each time it changes.
public enum BrowseUpdate: Sendable, Equatable {
    /// Every instance announced now: one that is no longer here was withdrawn.
    case found(Set<ServiceInstance>)
    /// macOS refuses this app the local network (`host-discovery`, "The app knows when it may not
    /// browse").
    case denied
}

/// Where `PanelDiscovery` gets the announcements and their addresses (design D3). Tests script one;
/// the app browses with `BonjourServiceBrowser`.
public protocol ServiceBrowser: Sendable {
    /// One browse, giving an update each time what it finds changes, until the stream is dropped or
    /// the browse fails.
    func updates() -> AsyncStream<BrowseUpdate>
    /// The address an instance's announcement resolves to: unreachable when it does not resolve in
    /// time, and an unexpected answer when its host target is not a hostname.
    func resolve(_ instance: ServiceInstance) async throws(HostFailure) -> HostAddress
}
