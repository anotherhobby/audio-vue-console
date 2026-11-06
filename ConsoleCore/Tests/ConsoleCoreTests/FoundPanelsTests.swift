import Testing

@testable import ConsoleCore

/// `host-discovery`, "One host is one panel, by its id", "An announcement without an id is not
/// listed" and "A withdrawn panel leaves the list", over the merge alone (design D3).
struct FoundPanelsTests {
    private static let local = HostAddress(parsing: "audio-vue.local")

    @Test func oneIDUnderTwoInstancesIsOnePanel() {
        let panels = FoundPanels.merge(
            [
                ServiceInstance(name: "audio-vue", hostID: "89efe3f8"),
                ServiceInstance(name: "audio-vue", hostID: "89efe3f8"),
            ], addresses: [:])
        #expect(panels == [FoundPanel(id: "89efe3f8", name: "audio-vue", address: nil)])
    }

    @Test func aRenamedInstanceIsStillThePanelByItsID() throws {
        let local = try #require(Self.local)
        let panels = FoundPanels.merge(
            [
                ServiceInstance(name: "audio-vue (2)", hostID: "89efe3f8"),
                ServiceInstance(name: "audio-vue", hostID: "89efe3f8"),
            ], addresses: ["audio-vue (2)": local])
        #expect(panels == [FoundPanel(id: "89efe3f8", name: "audio-vue", address: local)])
    }

    @Test func twoHostsOfOneNameAreTwoPanels() {
        let panels = FoundPanels.merge(
            [
                ServiceInstance(name: "audio-vue (2)", hostID: "b"),
                ServiceInstance(name: "audio-vue", hostID: "a"),
            ], addresses: [:])
        #expect(panels.map(\.name) == ["audio-vue", "audio-vue (2)"])
        #expect(panels.map(\.id) == ["a", "b"])
    }

    @Test func anInstanceWithNoIDIsNotListed() {
        let panels = FoundPanels.merge(
            [
                ServiceInstance(name: "stranger", hostID: nil),
                ServiceInstance(name: "audio-vue", hostID: "a"),
            ], addresses: [:])
        #expect(panels.map(\.name) == ["audio-vue"])
    }

    @Test func aPanelStaysWhileOneOfItsInstancesIsListed() {
        let both = [
            ServiceInstance(name: "audio-vue", hostID: "a"),
            ServiceInstance(name: "audio-vue (2)", hostID: "a"),
        ]
        #expect(FoundPanels.merge(both.dropFirst(), addresses: [:]).map(\.id) == ["a"])
    }

    @Test func everyInstanceWithdrawnLeavesNoPanel() {
        #expect(FoundPanels.merge([], addresses: [:]).isEmpty)
    }

    @Test func panelsAreInNameOrder() {
        let panels = FoundPanels.merge(
            [
                ServiceInstance(name: "studio", hostID: "s"),
                ServiceInstance(name: "cabin", hostID: "c"),
                ServiceInstance(name: "Attic", hostID: "t"),
            ], addresses: [:])
        #expect(panels.map(\.name) == ["Attic", "cabin", "studio"])
    }

    /// `panel-window`, "Two panels found": listed by address, by instance name until resolved.
    @Test func aPanelIsListedByItsAddressOnceKnown() {
        let resolved = FoundPanel(id: "a", name: "audio-vue", address: Self.local)
        #expect(resolved.listedName == "audio-vue.local")
        #expect(FoundPanel(id: "a", name: "audio-vue", address: nil).listedName == "audio-vue")
    }
}
