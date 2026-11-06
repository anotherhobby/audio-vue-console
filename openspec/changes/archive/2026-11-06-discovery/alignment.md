# Code alignment

## Read

Pass 1, 2026-11-06.

- `ConsoleCore/Sources/ConsoleCore/HostConnection.swift`: the state enum, `init` (reads the
  `AddressStore` once), `connectAtLaunch`, `connect` (saves the address on any version answer),
  `isPaired(at:)` (token by address, `/v1/host` read, a refused token forgotten), `makePairing` (its
  `onPaired` sets `host`), `makeClients`, `liveState`, `mark`.
- `TokenStore.swift`: `TokenStore`, `Pairings` (`hosts` by id, `addresses` by `HostAddress.description`,
  `pairing(at:)`, `pairing(forHost:)`, `save(_:at:)`, `forget(host:)`).
- `HostPairing.swift`: `confirm` reads `/v1/host` with the grant's token, `keep` saves at the pairing's
  address and calls `onPaired` with the host.
- `HostClient+Pairing.swift`: `HostIdentity` (id, name, `widthPx`, `heightPx`), `host(at:token:)`.
- `HostAddress.swift`: `init(parsing:)`, `isHost` (an empty label, as from a trailing dot, is
  refused), `description` (leaves out the default port).
- `AddressStore.swift`: one `UserDefaults` key, `lastHostAddress`.
- `PanelLabel.swift`: `init?(address:host:state:isLive:)`, named by the host or the address.
- `LiveState.swift`, `EventSource.swift`: the `@MainActor @Observable` pattern and the seam a test
  scripts.
- `Tests/ConsoleCoreTests`: `HostConnectionTests` (`MemoryAddressStore`, the `UserDefaults` suite
  test), `HostConnectionPairingTests`, `LiveHostTests` (`AUDIO_VUE_LIVE_HOST`,
  `AUDIO_VUE_PAIRINGS_DIR`, `ReadOnlyTokens`), `BoundaryTests` (Network and `URLSession` barred from
  the app target only).
- `AudioVueConsole/AudioVueConsoleApp.swift`: `HostConnection` made in a `@State` initialiser.
  `PanelWindow.swift`: `.task { await connection.connectAtLaunch() }`, the picker `Menu`,
  `panelLabel`, `WatchKey`.
- `AudioVueConsole.xcodeproj/project.xcproj`: `ENABLE_APP_SANDBOX`, `ENABLE_OUTGOING_NETWORK_CONNECTIONS`,
  `INFOPLIST_FILE`, `INFOPLIST_KEY_NSLocalNetworkUsageDescription`. `AudioVueConsole-Info.plist`: ATS only.
- SDK: a typecheck of `NetworkBrowser(for: .bonjour(_:includeTxtRecord:))`, its `onStateUpdate` and
  `.waiting(error)`, `run`, `DNSServiceResolve` and `DNSServiceSetDispatchQueue` against macOS 27.2;
  `Bonjour.Endpoint`'s members in Network's `.swiftinterface`. Apple's docs for `DNSServiceResolve`.
- Measured: `dns-sd -B` and `-L` for `_audio-vue._tcp`, 2026-11-06.
- audio-vue specs, in full: `control-api` ("The host says what it is and what it offers", "The
  announcement is part of the contract"), `control-service` (the seven announcement requirements,
  "Everything but pairing and the version takes a token", pairing and revoking), `host-store` (the
  identity and the paired clients in one store). Open changes: none (`aes17-hardening` archived
  2026-11-06).
- KB: `pitfalls.md` (all headings, and in full the Local Network prompt and `.task` items),
  `open-questions.md` (no items), `host-contract.md`, `project-map.md`.
- Removals and renames: none in the plan. `PanelLabel.init?` and `HostConnection.init` gain
  parameters; their callers are `PanelWindow.panelLabel`, `AudioVueConsoleApp`, `HostConnectionTests`,
  `HostConnectionPairingTests` and `LiveHostTests`'s none, each in a task.

## Findings

- **F1. The local network reason is already set** (resolved)
  - Plan: D7 and 3.1 added `NSLocalNetworkUsageDescription` to `AudioVueConsole-Info.plist`.
  - Code: the project sets `INFOPLIST_KEY_NSLocalNetworkUsageDescription` ("AudioVueConsole connects to
    the audio-vue panels on your local network."). `NSBonjourServices` is set nowhere, and as an array
    cannot be an `INFOPLIST_KEY_` setting.
  - Goes to: design, task.
  - Resolution: D7 and 3.1 add only `NSBonjourServices` to the plist and reword the build setting.
- **F2. An endpoint is an instance, not an instance on one interface** (resolved)
  - Plan: D1 said each endpoint is one instance on one interface; D3 and 1.1 gave `ServiceInstance`
    an interface.
  - Code: `Bonjour.Endpoint` has `name`, `txtRecord` and `result`, an `NWBrowser.Result` listing the
    interfaces it was seen on.
  - Goes to: design, task.
  - Resolution: the interface is dropped from `ServiceInstance`; the merge is tested over one id under
    two instances, and the two-interface case is checked in 4.1, where the host must be listed once.
- **F3. The launch wait would end with the window** (resolved)
  - Plan: D5 had `connectAtLaunch()` wait for the panel by id.
  - Code: `PanelWindow` awaits `connectAtLaunch()` in a `.task`, cancelled when the window closes, while
    the app keeps running and connected (`panel-window`, "The panel window is the app's window").
  - Goes to: design, task.
  - Resolution: the wait is a `Task` `HostConnection` holds; `connectAtLaunch()` returns without it
    (D5, 2.3).
- **F4. Nothing lets the connection wait on the model** (resolved)
  - Plan: D5 waited for `PanelDiscovery.found` to hold an id.
  - Code: an `@Observable` property gives no awaitable change; `LiveState` is watched by views only.
  - Goes to: design, task.
  - Resolution: `PanelDiscovery.panel(withID:) async -> FoundPanel?` (D3, 1.3), tested at once, later
    and cancelled.
- **F5. The id is also learned by pairing** (resolved)
  - Plan: 2.2 saved the id when `/v1/host` was read while paired, or a found panel connected.
  - Code: `HostPairing.confirm` reads the host, and `makePairing`'s `onPaired` sets `host`, with no
    `isPaired` read.
  - Goes to: design, task.
  - Resolution: D5 and 2.2 also save it in `onPaired`.
- **F6. The address can still point at another host** (resolved)
  - Plan: D4 and 2.1 looked the token up by the announced id when the address had none.
  - Code: `Pairings.addresses` keeps each address's last host id, so `audio-vue.local` can still name a
    host reinstalled since; its token would be sent and, refused, forgotten.
  - Goes to: design, task.
  - Resolution: a found panel's token is looked up by the announced id only (D4, 2.1).
- **F7. The App cannot pass one `@State` to another's initialiser** (resolved)
  - Plan: 3.2 had the App own the discovery and hand it to `HostConnection`.
  - Code: `AudioVueConsoleApp` makes `HostConnection` in a `@State` property initialiser.
  - Goes to: design, task.
  - Resolution: the App makes both in its own `init` and starts the browse there, not in a view's
    `.task` (`pitfalls.md`, "A `.task` on a view with nothing to show never runs") (D8, 3.2).
- **F8. The held panel's found identity has no home** (resolved)
  - Plan: D8 matched the held panel by "the announced id" and named an unpaired found panel by its
    instance name.
  - Code: `HostConnection` keeps only the address and, when paired, `host`.
  - Goes to: design, task.
  - Resolution: `HostConnection.foundPanel`, set by `connect(to:)` and cleared by `connect()` (D4, D8,
    2.1).
- **F9. D4's claim about another id rests on `host-store`** (resolved)
  - Plan: D4 said a host cannot accept a token another host issued, with no source.
  - Code and host: audio-vue `host-store` keeps the identity and the paired clients in one store, and a
    store made again has a new identity.
  - Goes to: design; the proposal's Impact.
  - Resolution: D4 cites it, and the proposal names `audio-vue:host-store`.
- **F10. "Another address for a paired host" no longer always holds** (resolved)
  - Plan: `host-connection`'s scenario says a paired host typed at `audio-vue.local` shows not paired.
  - Code: once D4 links a found panel's address to its host, a typed `audio-vue.local` finds the token
    through `Pairings.addresses` and is paired, which is right, but the scenario reads as if never.
  - Goes to: requirement.
  - Resolution: the maintainer ruled the rewording (Q1, 2026-11-06); the scenario's WHEN now says
    the app has not reached the host at `audio-vue.local`.
- **F11. The live test is asked for by another app** (resolved)
  - Plan: 1.4's live discovery test runs under `swift test`.
  - Code: `swift test` runs outside the app's sandbox and bundle, so macOS asks the launching app
    (Terminal or the editor) for local network access; `NSBonjourServices` is not checked there.
  - Goes to: design, task.
  - Resolution: noted in D9 and in 1.4's `commands.md` entry.

## Questions for the maintainer

- **Q1 (F10).** Should `host-connection`'s scenario "Another address for a paired host" say the app
  has not reached that host at the new address before? Recommended: yes, reword its WHEN to "the app
  paired with a host at `audio-vue`, has not reached it at `audio-vue.local`, and the user adds it by
  that address"; the behaviour is unchanged. Ruled yes (maintainer, 2026-11-06).

## Confirmed

- `Pairings.pairing(forHost:)` exists and is on the `TokenStore` protocol, so a token by id needs no
  store change (design Context).
- `Pairings.save(_:at:)` links an address to an id, and `forget(host:)` drops every address of it.
- `HostAddress(parsing:)` refuses `audio-vue.local.`: the trailing dot leaves an empty label, which
  `isLabel` refuses (design D1, 1.2).
- `HostIdentity.id` is what `/v1/host` gives, and `host(at:token:)` reads it (D4).
- `BoundaryTests` bars Network only from the app target, so `ConsoleCore` may import Network and dnssd.
- `NetworkBrowser`, `.bonjour(_:includeTxtRecord:)`, `.waiting(error)`, `DNSServiceResolve` and
  `DNSServiceSetDispatchQueue` typecheck against the SDK; `kDNSServiceErr_PolicyDenied` is an `Int`.
- The sandboxed app already has `ENABLE_OUTGOING_NETWORK_CONNECTIONS`, which browsing and resolving
  need.
- audio-vue states every host behaviour the plan uses: the service type, TXT `id`, withdrawal on stop,
  a renamed instance keeping its TXT record (`control-service`, `control-api`); `/v1/host`'s stable id
  (`control-api`); the token rule and 401 (`control-service`); one store for identity and clients
  (`host-store`).
- The proving host announces `audio-vue` at `audio-vue.local.:19200` with `id` and `api`, on two
  interfaces (Measured, 2026-11-06).
- `pitfalls.md`'s Local Network prompt item is carried by D9 and 4.1; its `.task` item by D8 and 3.2;
  no other pitfall touches this change. `open-questions.md` has no items.
