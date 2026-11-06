import Testing

@testable import ConsoleCore

/// `host-discovery` over a scripted browser (design D3, D5, D6).
@MainActor struct PanelDiscoveryTests {
    private static let audioVue = ServiceInstance(name: "audio-vue", hostID: "89efe3f8")
    private static let studio = ServiceInstance(name: "studio", hostID: "5d1e")

    private static func address(_ text: String) throws -> HostAddress {
        try #require(HostAddress(parsing: text))
    }

    @Test func aPanelFoundIsListedAndThenResolved() async throws {
        let local = try Self.address("audio-vue.local")
        let browser = ScriptedBrowser(answers: ["audio-vue": .success(local)])
        let discovery = PanelDiscovery(browser: browser)
        discovery.receive(.found([Self.audioVue]))
        #expect(discovery.found == [FoundPanel(id: "89efe3f8", name: "audio-vue", address: nil)])
        await discovery.settled()
        #expect(discovery.found == [FoundPanel(id: "89efe3f8", name: "audio-vue", address: local)])
    }

    @Test func aWithdrawnPanelLeavesTheList() async {
        let discovery = PanelDiscovery(browser: ScriptedBrowser())
        discovery.receive(.found([Self.audioVue, Self.studio]))
        discovery.receive(.found([Self.studio]))
        #expect(discovery.found.map(\.name) == ["studio"])
        discovery.receive(.found([]))
        #expect(discovery.found.isEmpty)
    }

    @Test func aDenialListsNothingUntilABrowseFindsPanels() {
        let discovery = PanelDiscovery(browser: ScriptedBrowser())
        discovery.receive(.found([Self.audioVue]))
        discovery.receive(.denied)
        #expect(!discovery.mayBrowse)
        #expect(discovery.found.isEmpty)
        discovery.receive(.found([Self.audioVue]))
        #expect(discovery.mayBrowse)
        #expect(discovery.found.map(\.name) == ["audio-vue"])
    }

    @Test func aFailedResolveLeavesTheAddressToBeResolvedOnChoosing() async throws {
        let browser = ScriptedBrowser()
        let discovery = PanelDiscovery(browser: browser)
        discovery.receive(.found([Self.audioVue]))
        await discovery.settled()
        let panel = try #require(discovery.found.first)
        #expect(panel.address == nil)
        let local = try Self.address("audio-vue.local")
        browser.answer("audio-vue", with: .success(local))
        #expect(try await discovery.address(of: panel) == local)
        #expect(discovery.found.first?.address == local)
    }

    @Test func noInstanceIsResolvedTwice() async {
        let browser = ScriptedBrowser()
        let discovery = PanelDiscovery(browser: browser)
        discovery.receive(.found([Self.audioVue]))
        await discovery.settled()
        discovery.receive(.found([Self.audioVue, Self.studio]))
        await discovery.settled()
        #expect(browser.resolveCount("audio-vue") == 1)
        #expect(browser.resolveCount("studio") == 1)
    }

    @Test func anInstanceWithNoIDIsNotResolved() async {
        let browser = ScriptedBrowser()
        let discovery = PanelDiscovery(browser: browser)
        discovery.receive(.found([ServiceInstance(name: "stranger", hostID: nil)]))
        await discovery.settled()
        #expect(browser.resolveCount("stranger") == 0)
    }

    @Test func aPanelListedIsGivenAtOnce() async {
        let discovery = PanelDiscovery(browser: ScriptedBrowser())
        discovery.receive(.found([Self.audioVue]))
        #expect(await discovery.panel(withID: "89efe3f8")?.name == "audio-vue")
    }

    @Test func aPanelIsGivenOnceAnUpdateListsIt() async {
        let discovery = PanelDiscovery(browser: ScriptedBrowser())
        let waiting = Task { await discovery.panel(withID: "89efe3f8") }
        await Task.yield()
        discovery.receive(.found([Self.studio]))
        discovery.receive(.found([Self.studio, Self.audioVue]))
        #expect(await waiting.value?.name == "audio-vue")
    }

    @Test func aCancelledWaitGivesNoPanel() async {
        let discovery = PanelDiscovery(browser: ScriptedBrowser())
        let waiting = Task { await discovery.panel(withID: "89efe3f8") }
        await Task.yield()
        waiting.cancel()
        #expect(await waiting.value == nil)
    }

    /// `panel-window`, "Two panels found".
    @Test func thePanelsFoundButTheOneHeldAreTheOthers() {
        let cabin = ServiceInstance(name: "cabin", hostID: "c4b1")
        let discovery = PanelDiscovery(browser: ScriptedBrowser())
        discovery.receive(.found([Self.studio, cabin, Self.audioVue]))
        let others = discovery.others(heldID: "89efe3f8", heldAddress: nil)
        #expect(others.map(\.name) == ["cabin", "studio"])
    }

    /// `panel-window`, "The held panel is found", by its address when its id is not known.
    @Test func theHeldPanelIsKnownByItsAddress() async throws {
        let local = try Self.address("audio-vue.local")
        let browser = ScriptedBrowser(answers: ["audio-vue": .success(local)])
        let discovery = PanelDiscovery(browser: browser)
        discovery.receive(.found([Self.audioVue, Self.studio]))
        await discovery.settled()
        #expect(discovery.others(heldID: nil, heldAddress: local).map(\.name) == ["studio"])
        let typed = try Self.address("192.168.1.20")
        #expect(discovery.others(heldID: nil, heldAddress: typed).count == 2)
    }

    /// `panel-window`, "An unpaired panel found at the address held": a panel reached at its
    /// remembered address is the one found there, so it is named as announced.
    @Test func theHeldPanelIsTheOneFoundByItsIDOrAddress() async throws {
        let local = try Self.address("audio-vue.local")
        let browser = ScriptedBrowser(answers: ["audio-vue": .success(local)])
        let discovery = PanelDiscovery(browser: browser)
        discovery.receive(.found([Self.audioVue, Self.studio]))
        await discovery.settled()
        #expect(discovery.held(id: nil, address: local)?.name == "audio-vue")
        #expect(discovery.held(id: "5d1e", address: nil)?.name == "studio")
        let typed = try Self.address("192.168.1.20")
        #expect(discovery.held(id: nil, address: typed) == nil)
    }

    @Test func aBrowseFollowsItsUpdatesAndARestartBrowsesAgain() async {
        let browser = ScriptedBrowser()
        let discovery = PanelDiscovery(browser: browser)
        let browsing = Task { await discovery.browse() }
        await browser.browseStarted()
        browser.send(.denied)
        browser.send(.found([Self.audioVue]))
        #expect(await discovery.panel(withID: "89efe3f8") != nil)
        discovery.restart()
        await browser.browseStarted()
        #expect(browser.browses == 2)
        browsing.cancel()
        await browsing.value
    }
}
