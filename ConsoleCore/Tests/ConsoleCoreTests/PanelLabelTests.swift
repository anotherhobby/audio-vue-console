import Testing

@testable import ConsoleCore

/// `panel-window`, "The picker names the panel".
struct PanelLabelTests {
    private let address = HostAddress(parsing: "audio-vue.local")
    private let host = HostIdentity(id: "h1", name: "audio-vue", widthPx: nil, heightPx: nil)

    @Test func aPairedPanel() {
        let label = PanelLabel(address: address, host: host)
        #expect(label == PanelLabel(name: "audio-vue", isDiscovered: false))
    }

    @Test func anUnpairedPanel() {
        let label = PanelLabel(address: address, host: nil)
        #expect(label == PanelLabel(name: "audio-vue.local", isDiscovered: false))
    }

    /// Also "An unpaired panel found at the address held": the found name is given either way.
    @Test func anUnpairedFoundPanel() {
        let label = PanelLabel(address: address, host: nil, foundName: "audio-vue")
        #expect(label == PanelLabel(name: "audio-vue.local", isDiscovered: true))
    }

    @Test func aFoundPanelPaired() {
        let label = PanelLabel(address: address, host: host, foundName: "audio-vue")
        #expect(label == PanelLabel(name: "audio-vue", isDiscovered: false))
    }

    @Test func aFoundPanelWithNoAddressIsNamedAsFound() {
        let label = PanelLabel(address: nil, host: nil, foundName: "audio-vue")
        #expect(label == PanelLabel(name: "audio-vue", isDiscovered: true))
    }

    @Test func noAddressNoLabel() {
        #expect(PanelLabel(address: nil, host: nil) == nil)
    }
}
