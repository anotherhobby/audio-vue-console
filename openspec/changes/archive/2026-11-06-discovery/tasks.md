# Tasks

## 1. Finding panels (ConsoleCore)

- [x] 1.1 Add `FoundPanels.swift`: `ServiceInstance` (instance name, TXT `id` or nil),
  `FoundPanel` (id, instance name, `HostAddress?`), and a pure `FoundPanels.merge` that keeps one
  panel per id, drops instances with no `id`, names a panel by the first of its instance names in
  name order, and sorts panels by name (design D3). Verify `FoundPanelsTests` for one id under two
  instances, a renamed instance, two hosts of one name with different ids, a missing `id`, one of two
  instances withdrawn, and every instance withdrawn
- [x] 1.2 Add `HostAddress(resolvedHost:port:)`, which drops one trailing dot and validates through
  the same rules as `init(parsing:)` (`HostAddress.swift`, design D1). Verify `HostAddressTests` that
  `audio-vue.local.` at 19200 is `audio-vue.local` and reads `http://audio-vue.local:19200/v1/version`,
  port 8080 is kept, and a host target that is not a hostname is refused
- [x] 1.3 Add `ServiceBrowser.swift`: the `ServiceBrowser` protocol, a stream of `BrowseUpdate`s, each
  the full set of current `ServiceInstance`s or `.denied`, and `resolve(_:) async throws ->
  HostAddress`; and `PanelDiscovery` (`@Observable`, `@MainActor`, in `PanelDiscovery.swift`), with `browse()` running until
  cancelled, `found: [FoundPanel]`, `mayBrowse`, each new instance resolved once, `restart()` for
  the App to call while denied, and `panel(withID:) async -> FoundPanel?`, returning once an update
  holds the id or nil when cancelled (design D3, D5, D6). Add `ScriptedBrowser` beside
  `ScriptedEvents` in the tests. Verify `PanelDiscoveryTests` for a panel found and then resolved, a
  panel withdrawn, a denial then a browse, a failed resolve leaving the address nil, no instance
  resolved twice, and `panel(withID:)` answering at once, on a later update, and nil when cancelled
- [x] 1.4 Add `BonjourServiceBrowser.swift`: `NetworkBrowser` with `.bonjour("_audio-vue._tcp",
  includeTxtRecord: true)`, each `Bonjour.Endpoint`'s `name` and `txtRecord`'s `id` an instance, its
  waiting state with `NWError.dns(Int32(kDNSServiceErr_PolicyDenied))` reported as `.denied`;
  `resolve` by `DNSServiceResolve` on interface 0 and a dispatch queue (`DNSServiceSetDispatchQueue`),
  deallocated after the first reply or after `HostClient.requestTimeout` (design D1, D6). Verify
  `xcrun swift build` in `ConsoleCore/` with warnings as errors, `BoundaryTests`, and a
  `LiveHostTests` test that reads the proving host's id from `/v1/host` with the kept token and finds
  a panel with that id whose address answers `/v1/version`; add its run to `commands.md`, noting that
  macOS asks the launching app (Terminal or the editor) for local network access

## 2. Connecting to a found panel (ConsoleCore)

- [x] 2.1 Give `HostConnection` a `PanelDiscovery` (an `init` parameter) and `connect(to:
  FoundPanel)`: resolve the address if not yet resolved, set `addressText`, keep the panel as
  `foundPanel` (cleared by a typed `connect()`), and connect as now, except that `isPaired(at:)` takes
  the announced id and looks the token up by `tokens.pairing(forHost:)` only. On a host id that
  matches, `tokens.save(_:at:)` links the address; on one that does not, nothing is saved and the app
  is not paired; a refused token is forgotten as now (design D4). Update the `HostConnection(...)`
  calls in `HostConnectionTests` and `HostConnectionPairingTests` for the new parameter. Verify `HostConnectionDiscoveryTests`
  over `FakeTransport` for `host-connection`'s "A paired host found at a new address" (Bearer sent,
  the address linked) and "A found panel whose id does not match", a refused token, an unpaired found
  panel offering Pair, and a panel that cannot be resolved, which is `State.unresolved(name, failure)`
  since it has no address, shown by `ConnectionStatus`
- [x] 2.2 Make `AddressStore` keep the host id beside the address: `UserDefaultsAddressStore` gains
  the key `lastHostID`, saved when `/v1/host` is read while paired, in `makePairing`'s `onPaired`,
  and when a found panel is connected to, and cleared when an address is saved with no id known
  (`AddressStore.swift`, `MemoryAddressStore` in the tests, design D5). Verify `HostConnectionTests`
  over a `UserDefaults` suite that a typed paired host, a pairing, a found panel and a typed unpaired
  host leave the id, the paired id, the announced id and none
- [x] 2.3 Add the launch fallback to `connectAtLaunch()`: when the remembered address fails as
  unreachable and an id is remembered, start a wait, a `Task` `HostConnection` holds, on
  `PanelDiscovery.panel(withID:)`, and `connect(to:)` what it gives; `connectAtLaunch()` returns
  without awaiting it, and `connect()` and `connect(to:)` called by the user cancel it (design D5).
  Verify `HostConnectionDiscoveryTests` for `host-connection`'s "A panel that moved", "A panel not yet
  announced" (announced later, and the user adding another first) and "No id remembered", and that a
  refused or unexpected answer starts no wait
- [x] 2.4 Give `PanelLabel` the found panel's instance name, used for the name when not paired and
  before the address (`PanelLabel.swift`, design D8). Verify `PanelLabelTests` for `panel-window`'s
  "An unpaired found panel" and "An unpaired panel" (a typed address)
- [x] 2.5 Add `PanelDiscovery.others(heldID:heldAddress:)`, the found panels but the held one, matched
  by id or by address (design D2, D8). Verify `PanelDiscoveryTests` for `panel-window`'s "Two panels
  found" and "The held panel is found", by id and by address

- [x] 2.6 Make `PanelLabel.isUp` a `Bool?`, nil without the host's identity, and add
  `PanelDiscovery.held(id:address:)`, the found panel held, matched as `others` matches it (design
  D8, D10). Verify `PanelLabelTests` for `panel-window`'s "An unpaired panel" and "An unpaired found
  panel" with no mark, and `PanelDiscoveryTests` for "An unpaired panel found at the address held"

## 3. The picker (app target)

- [x] 3.1 Add `NSBonjourServices` (`_audio-vue._tcp`) to `AudioVueConsole-Info.plist`, and reword
  the project's `INFOPLIST_KEY_NSLocalNetworkUsageDescription` to say the app finds and connects to the
  audio-vue panels on the local network (design D7). Verify a build through `BuildProject` and both
  keys in the built app's `Info.plist` (`plutil -p`)
- [x] 3.2 Have `AudioVueConsoleApp` make one `PanelDiscovery` and the `HostConnection` given it in
  its own `init`, start `browse()` there in a `Task`, not in a view's `.task`, and call `restart()` on
  `NSApplication.didBecomeActiveNotification` while `mayBrowse` is false (design D3, D6, D8). Verify
  the Debug and Release builds and `BoundaryTests`
- [x] 3.3 In `PanelWindow`'s picker menu (built as `PanelPicker.swift`), list the held panel, then a section of
  `PanelDiscovery.others(...)` by instance name, each calling `connection.connect(to:)`, then Add
  Panel…; while `mayBrowse` is false, the section is one line naming Privacy & Security, Local
  Network, in System Settings (design D8). Verify previews for none found, two found and denied, and `project-map.md`'s `AudioVueConsole/` and `ConsoleCore/`
  entries updated for `PanelDiscovery`, `ServiceBrowser` and the picker

- [x] 3.4 Name the panel once and say connected only when paired: `PanelWindow` builds the
  `PanelLabel` with `held(id:address:)`'s name and gives the name to `OverviewPage` for its title and
  `ConnectionStatus`; `ConnectionStatus` says "Connected to <name>" only when paired and connecting
  by the name; `OverviewForm` leads with the pairing prompt while `.connected(paired: false)`; the
  Pairing section drops its unpaired lines and "This Mac is paired"; the picker shows no `UpMark`
  when `isUp` is nil (design D10). Verify the Overview previews "Not paired", "Paired, up", "Paired,
  down" and "Unreachable", the picker previews, and the Debug build

- [x] 3.5 Move the picker to the Panel page (design D11): rename Overview to Panel (`PanelSection`,
  `PanelPage.swift`, `PanelForm`, `PanelRows`) and its first section to Status; drop the picker from
  `PanelSidebar`; put `PanelPicker` in a `.navigation` toolbar item on the Panel page with the title
  removed, reading "Panel:" and the held panel's name, "(discovered)" while found and not paired;
  reduce `PanelLabel` to a name and `isDiscovered`, removing the up mark and `DisplayShape`; list
  found panels by `FoundPanel.listedName`. Verify `PanelLabelTests`, `FoundPanelsTests`,
  `PanelRowsTests`, the picker previews "Discovered", "Paired, two found" and "None, denied", the
  Panel page previews, and the Debug build

- [x] 3.6 Say connected only while the paired host is live: `HostContact` (live, waiting, lost) from
  `LiveState`, given through `PanelForm` and `PairingSection` to `ConnectionStatus`, which says
  "Connected to <name>", "Connecting to <name>…" or "Lost contact with <name>. Trying again…"
  (design D10, `panel-window`'s "Lost contact"). Verify the Pairing section preview and the Debug
  build

## 4. Against the proving host

- [x] 4.1 With the maintainer, from a standalone launch of the built app (`open`, not `RunProject`,
  `pitfalls.md`): the Local Network prompt shows once; allowed, the proving host is listed once though
  seen on two interfaces; paired at `audio-vue.cabin.hobbysprawl.com`, choosing the found `audio-vue`
  connects paired with no new pairing; stopping the agent (`tools/panel.py agent stop` on the host)
  drops it from the list, and starting it lists it again; with `lastHostAddress` set to `192.0.2.1` in
  the app container's defaults, a relaunch says unreachable and then connects to the found panel;
  access turned off in System Settings makes the picker say so, and turned back on lists the panel
  without a relaunch; a screenshot of the picker listing the proving host, moved here from 3.3, since
  the agent's shell cannot capture the window (`pitfalls.md`). Record what D6 assumed about the denial, and anything surprising, in
  `pitfalls.md`; the API choice of D1 in `decisions-log.md`; and update `working-notes.md`'s change
  order and `host-contract.md`'s discovery section

## Workflow follow-up

- Verify the change against its artifacts (`openspec-verify-change`).
- Archive the change and sync its specs once the maintainer's run passes; then edit
  `openspec/specs/panel-window/spec.md`'s Purpose, which still says Overview and the sidebar's
  picker, since a delta cannot change it.
