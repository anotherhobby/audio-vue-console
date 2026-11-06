import Foundation

/// One announcement of `_audio-vue._tcp` in `local.`, as the browse gives it: its instance name and
/// its TXT record's `id`, nil when the record has none.
public struct ServiceInstance: Sendable, Hashable {
    public let name: String
    public let hostID: String?

    public init(name: String, hostID: String?) {
        self.name = name
        self.hostID = hostID
    }
}

/// A panel found on the network (`host-discovery`): one host by its id, named by its instance, with
/// the address its announcement resolves to once resolved.
public struct FoundPanel: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let address: HostAddress?

    public init(id: String, name: String, address: HostAddress?) {
        self.id = id
        self.name = name
        self.address = address
    }

    /// What the picker lists it by: its address, or its instance name until that is known
    /// (`panel-window`, "The picker lists the panels found").
    public var listedName: String { address?.description ?? name }
}

/// How the announcements found make the panels found (design D3): one panel per id, whatever its
/// instance names, and none for an announcement with no id, which cannot be told apart from others
/// or matched to a pairing.
enum FoundPanels {
    /// The panels in `instances`, sorted by name. A panel is named by the first of its instance
    /// names in name order, and reached at the first of them that has resolved, by `addresses`,
    /// which is keyed by instance name.
    static func merge(_ instances: some Sequence<ServiceInstance>, addresses: [String: HostAddress])
        -> [FoundPanel]
    {
        var names: [String: [String]] = [:]
        for instance in instances {
            guard let id = instance.hostID else { continue }
            names[id, default: []].append(instance.name)
        }
        let panels = names.map { id, instanceNames in
            let ordered = instanceNames.sorted(by: inNameOrder)
            return FoundPanel(
                id: id, name: ordered[0], address: ordered.lazy.compactMap { addresses[$0] }.first)
        }
        return panels.sorted(by: inPickerOrder)
    }

    /// By name, then by id, so two panels the responder left with one name keep a fixed order.
    static func inPickerOrder(_ first: FoundPanel, _ second: FoundPanel) -> Bool {
        first.name == second.name ? first.id < second.id : inNameOrder(first.name, second.name)
    }

    /// Names as Finder sorts them, so `audio-vue (2)` follows `audio-vue`.
    static func inNameOrder(_ first: String, _ second: String) -> Bool {
        first.localizedStandardCompare(second) == .orderedAscending
    }
}
