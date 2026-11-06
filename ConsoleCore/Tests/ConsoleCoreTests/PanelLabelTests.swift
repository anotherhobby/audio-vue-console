import Foundation
import Testing

@testable import ConsoleCore

/// `panel-window`, "The picker names the panel".
struct PanelLabelTests {
    private let address = HostAddress(parsing: "audio-vue.local")

    private static func state(_ condition: PanelState.Condition, width: Int?, height: Int?)
        -> PanelState
    {
        var state = PanelState(condition: condition)
        state.displayWidthPx = width
        state.displayHeightPx = height
        return state
    }

    @Test func aPairedPanel() {
        let host = HostIdentity(id: "h1", name: "audio-vue", widthPx: nil, heightPx: nil)
        let label = PanelLabel(
            address: address, host: host, state: Self.state(.up, width: 1920, height: 1080),
            isLive: true)
        #expect(label == PanelLabel(name: "audio-vue", shape: "16:9", isUp: true))
    }

    @Test func aPairedPanelThatIsDown() {
        let host = HostIdentity(id: "h1", name: "audio-vue", widthPx: nil, heightPx: nil)
        let label = PanelLabel(
            address: address, host: host, state: Self.state(.down, width: nil, height: nil),
            isLive: true)
        #expect(label == PanelLabel(name: "audio-vue", shape: nil, isUp: false))
    }

    @Test func anUnpairedPanel() {
        let label = PanelLabel(address: address, host: nil, state: nil, isLive: false)
        #expect(label == PanelLabel(name: "audio-vue.local", shape: nil, isUp: false))
    }

    @Test func aStateNoLongerLiveIsNotUp() {
        let host = HostIdentity(id: "h1", name: "audio-vue", widthPx: 2560, heightPx: 960)
        let label = PanelLabel(
            address: address, host: host, state: Self.state(.up, width: nil, height: nil),
            isLive: false)
        #expect(label == PanelLabel(name: "audio-vue", shape: "8:3", isUp: false))
    }

    @Test func noAddressNoLabel() {
        #expect(PanelLabel(address: nil, host: nil, state: nil, isLive: false) == nil)
    }
}
