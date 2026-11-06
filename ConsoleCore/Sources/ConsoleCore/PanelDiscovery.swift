import Foundation
import Observation

/// The panels announced on the local network (`host-discovery`; design D3), browsed while the app
/// runs: `browse()` runs until cancelled. Each instance found is resolved once, so the list holds
/// every panel's address as soon as it is known (design D2).
@MainActor @Observable
public final class PanelDiscovery {
    /// The panels found, one per host id, in name order.
    public private(set) var found: [FoundPanel] = []
    /// False while macOS refuses the app the local network.
    public private(set) var mayBrowse = true

    private let browser: any ServiceBrowser
    private var instances: Set<ServiceInstance> = []
    /// Each listed instance's address, by instance name, once it has resolved.
    private var addresses: [String: HostAddress] = [:]
    /// The resolve started for each listed instance, by instance name.
    private var resolves: [String: Task<Void, Never>] = [:]
    private var waiters: [UUID: Waiter] = [:]
    /// The browse under way, which `restart()` ends.
    private var current: Task<Void, Never>?
    private var restartAsked = false

    private struct Waiter {
        let hostID: String
        let continuation: CheckedContinuation<FoundPanel?, Never>
    }

    public init(browser: any ServiceBrowser = BonjourServiceBrowser()) {
        self.browser = browser
    }

    /// Browses until cancelled. A browse ended by `restart()` is started again; one that fails waits
    /// for the next `restart()`.
    public func browse() async {
        repeat {
            restartAsked = false
            let run = Task { await follow(browser.updates()) }
            current = run
            await withTaskCancellationHandler {
                await run.value
            } onCancel: {
                run.cancel()
            }
        } while restartAsked && !Task.isCancelled
    }

    /// Ends the browse under way and starts another, so access given in System Settings is picked up
    /// without a relaunch (design D6).
    public func restart() {
        restartAsked = true
        current?.cancel()
    }

    /// The panel found with `hostID`: at once if it is listed, else once an update lists it, or nil
    /// when the caller is cancelled first.
    public func panel(withID hostID: String) async -> FoundPanel? {
        if let panel = found.first(where: { $0.id == hostID }) { return panel }
        let key = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(returning: nil)
                } else {
                    waiters[key] = Waiter(hostID: hostID, continuation: continuation)
                }
            }
        } onCancel: {
            Task { @MainActor in self.dropWaiter(key) }
        }
    }

    /// The panels found but the one the app holds, which is the one with its id when the app knows
    /// it, or the one at its address (`panel-window`, "The picker lists the panels found").
    public func others(heldID: String?, heldAddress: HostAddress?) -> [FoundPanel] {
        found.filter { !Self.isHeld($0, id: heldID, address: heldAddress) }
    }

    /// The panel the app holds, when it is found: so an unpaired panel reached at its address is
    /// named as announced (`panel-window`, "The picker names the panel").
    public func held(id: String?, address: HostAddress?) -> FoundPanel? {
        found.first { Self.isHeld($0, id: id, address: address) }
    }

    /// Where `panel` is reached: the address it resolved to, or a resolve of it now when it has none.
    public func address(of panel: FoundPanel) async throws(HostFailure) -> HostAddress {
        if let address = panel.address ?? found.first(where: { $0.id == panel.id })?.address {
            return address
        }
        guard let instance = instances(of: panel.id).first else { throw .unreachable }
        let address = try await browser.resolve(instance)
        keep(address, for: instance)
        return address
    }

    /// Takes in one update: the instances found replace those held, a withdrawn instance's address
    /// goes with it, and each new instance with an id is resolved.
    func receive(_ update: BrowseUpdate) {
        switch update {
        case .denied:
            mayBrowse = false
            instances = []
        case .found(let now):
            mayBrowse = true
            instances = now
        }
        let names = Set(instances.map(\.name))
        addresses = addresses.filter { names.contains($0.key) }
        for (name, resolve) in resolves where !names.contains(name) {
            resolve.cancel()
            resolves[name] = nil
        }
        for instance in instances where instance.hostID != nil && resolves[instance.name] == nil {
            resolves[instance.name] = Task { await resolve(instance) }
        }
        refresh()
    }

    /// Returns once every resolve started has ended, for tests.
    func settled() async {
        for resolve in resolves.values { await resolve.value }
    }

    private func follow(_ updates: AsyncStream<BrowseUpdate>) async {
        for await update in updates { receive(update) }
    }

    private func resolve(_ instance: ServiceInstance) async {
        do {
            keep(try await browser.resolve(instance), for: instance)
        } catch {
            // Left with no address; choosing the panel resolves it again (`address(of:)`).
        }
    }

    private func keep(_ address: HostAddress, for instance: ServiceInstance) {
        guard instances.contains(instance) else { return }
        addresses[instance.name] = address
        refresh()
    }

    private func refresh() {
        found = FoundPanels.merge(instances, addresses: addresses)
        for (key, waiter) in waiters {
            guard let panel = found.first(where: { $0.id == waiter.hostID }) else { continue }
            waiters[key] = nil
            waiter.continuation.resume(returning: panel)
        }
    }

    private func dropWaiter(_ key: UUID) {
        waiters.removeValue(forKey: key)?.continuation.resume(returning: nil)
    }

    private static func isHeld(_ panel: FoundPanel, id: String?, address: HostAddress?) -> Bool {
        panel.id == id || (address != nil && panel.address == address)
    }

    private func instances(of hostID: String) -> [ServiceInstance] {
        instances.filter { $0.hostID == hostID }
            .sorted { FoundPanels.inNameOrder($0.name, $1.name) }
    }
}
