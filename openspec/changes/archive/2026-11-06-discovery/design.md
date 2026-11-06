# Design

## Context

See `proposal.md`, "Why". The host side is built: the agent announces `_audio-vue._tcp`, with TXT
`id` and `api`, and withdraws it when it stops (audio-vue `control-service`, `control-api`). The
proving host is found on two interfaces at once and resolves to `audio-vue.local.:19200` (Measured,
`dns-sd -B` and `-L`, 2026-11-06).

What the app has now:

- `HostConnection` connects to `addressText`: version, then `isPaired(at:)`, which looks up the token
  by address (`Pairings.addresses` maps an address to a host id) and reads `/v1/host` with it.
- `Pairings` can already look a token up by host id (`pairing(forHost:)`), and `save(_:at:)` links an
  address to an id. Nothing else in the token store changes.
- `AddressStore` keeps one string, the last address.
- `HostAddress(parsing:)` refuses a trailing dot, which is an empty label, so `audio-vue.local.` must
  lose it before it is parsed.
- `LiveState` takes its socket through the `EventSource` seam, which tests script. Browsing follows
  the same pattern.
- `app-boundaries`: the app target may not import Network or use `URLSession`. Browsing goes in
  `ConsoleCore`.
- `PanelWindow` runs `connectAtLaunch()` in its `.task`, which ends when the window closes.
- The app's `NSLocalNetworkUsageDescription` is already set, by the project's
  `INFOPLIST_KEY_NSLocalNetworkUsageDescription`; `NSBonjourServices` is not.
- audio-vue `host-store`: the host's identity and its paired clients live in one store, and a store
  made again has a new identity.

## Goals / Non-Goals

**Goals:**

- A model in the core that keeps the panels found, merged by id, each with its address once resolved,
  and the browse state, testable with no network.
- Connecting to a found panel through the same `HostConnection` path a typed address takes, with the
  token looked up by the announced id.
- The launch fallback, and the picker's list.

**Non-Goals:**

- Following a held panel that moves while the app runs. A connection that fails mid-session behaves
  as it does now; the user can choose the panel again from the list.
- Browsing any domain but `local.`, or reaching a found panel by IPv6 address.
- Reading anything from the TXT record but `id`.
- More than one panel connected at a time.

## Decisions

### D1. Browse with `NetworkBrowser`, resolve with `DNSServiceResolve`

Browsing uses Network's `NetworkBrowser` with `.bonjour("_audio-vue._tcp", includeTxtRecord: true)`:
it is the current Swift API, it gives each endpoint's TXT record without a resolve, and its state
reports a policy denial (D6). Each endpoint, a `Bonjour.Endpoint`, is one instance: its name, its
`txtRecord`, and the browse result listing the interfaces it was seen on (Measured, the SDK's
interface, 2026-11-06).

Network gives a found service as a service endpoint, not as a host and port `URLSession` can take.
So each new instance is resolved once with dnssd's `DNSServiceResolve`, on any interface (index 0),
which gives the host target
(`audio-vue.local.`) and the port, as `dns-sd -L` shows. The trailing dot is dropped and the result
parsed as a `HostAddress`. An instance whose host target does not parse is listed with no address,
and choosing it leaves `HostConnection` in `State.unresolved`, with the panel's name and why, since
there is no address to put in `failed`.

Alternatives: resolving by opening a Network connection to the service endpoint and reading its
remote endpoint gives an IP, often an IPv6 link-local one, which `HostAddress` does not take and which
changes with DHCP. Rejected. Browsing with `DNSServiceBrowse` too would put everything in one C API,
but its browse gives no TXT record, so every instance would need a resolve to be listed, and its
callbacks need unsafe context pointers under Swift 6. Rejected. `NetService` is deprecated.

### D2. Every instance found is resolved, not only the one chosen

The list holds each panel's address as soon as it resolves, rather than when it is chosen. This is
the only way to tell that a panel held by a typed address, unpaired, is a panel found, since its id is
unknown (`panel-window`, "The picker lists the panels found"). A LAN holds a few panels, so a resolve
for each is cheap. Resolving sends nothing to the host's agent; it is an mDNS query.

Alternative: resolving only on choose keeps the browse lighter, but then a typed, unpaired panel is
listed twice. Rejected.

### D3. `PanelDiscovery` in the core, behind a `ServiceBrowser` seam

- `ServiceBrowser` (protocol): a stream of browse updates, each the full set of current instances
  (instance name and TXT `id`, or none) or a state (browsing, denied), and
  `resolve(_ instance:) async throws -> HostAddress`. `BonjourServiceBrowser` is the real one (D1);
  tests script a fake, as `ScriptedEvents` does for `EventSource`.
- `PanelDiscovery` (`@Observable`, `@MainActor`, owned by the App beside `HostConnection`, browsing
  while the app runs): turns each update into `found: [FoundPanel]`, one per id, sorted by name, and
  `mayBrowse: Bool`. Its merging is a pure function over the instances, tested without the seam.
  `panel(withID:) async -> FoundPanel?` returns once an update holds that id, or nil when cancelled,
  which is how `HostConnection` waits at launch (D5) without observing the model.
- `FoundPanel`: the id, the instance name (the first instance's, in name order, when one host is seen
  under two names), and the address once resolved. A panel stays while any instance with its id is
  listed; instances with no `id` are dropped (`host-discovery`).

Each update being the full set makes withdrawal the absence of an instance, so there is no
add-and-remove bookkeeping to get wrong.

### D4. Connecting to a found panel

`HostConnection` is given the `PanelDiscovery` and gains `connect(to: FoundPanel)`. It takes the
found address (resolving it first if not yet resolved), sets `addressText` to it, keeps the panel as
`foundPanel`, and runs the existing connect with one difference: the pairing check looks up the token
by the announced id, never by the address, since the announcement names the host and the address may
still point at a host that was there before. A typed `connect()` clears `foundPanel`. Then:

- The host accepts the token and `/v1/host` gives the announced id: paired, and `save(_:at:)` links
  the address to the id, so a later typed or remembered connect to that address is paired too.
- `/v1/host` gives another id: not paired, and nothing is saved. A host keeps its identity and its
  clients' tokens in one store (audio-vue `host-store`), so this means a stale or false announcement,
  not a moved host.
- The host refuses the token: forgotten, as `host-pairing`, "A refused token means pair again" says.

The typed path is unchanged: with no announced id, a new address stays unpaired until it pairs.

### D5. The last panel's id is remembered with its address

`AddressStore` keeps the last address and, beside it, the id of the host that answered there when the
app knows it: from `/v1/host` when paired, or from the announcement when the panel was found. Each is
its own `UserDefaults` key. The id is saved when `/v1/host` is read while paired, when a pairing
keeps a token (`makePairing`'s callback), and when a found panel is connected to.

At launch, `connectAtLaunch()` connects to the address as now. If that fails as unreachable, and an id
is remembered, `HostConnection` starts a wait, a `Task` it holds, on `PanelDiscovery.panel(withID:)`,
and then connects to the panel as in D4. `connectAtLaunch()` returns without waiting on it, so closing
the window, which ends its `.task`, does not end the wait. The wait is cancelled when the user chooses
or adds a panel.
A refused or unexpected answer at the address is not a moved host, so it starts no wait.

Alternative: trying discovery first at launch would connect sooner when the panel moved, but the
common case is a panel that did not, and the address answers without waiting for a browse. Rejected.

### D6. A denial is `NetworkBrowser`'s waiting state

macOS refuses an app the local network by holding its browse in the waiting state with DNS-SD's
policy-denied error, `NWError.dns` of `kDNSServiceErr_PolicyDenied` (an `Int` in Swift, compared as
`Int32`); this is checked by hand (D9) before it is relied
on. The adapter reports that as the denied state, and any other wait as
browsing with nothing found. While denied, the App restarts the browser each time the app becomes
active, so access given in System Settings is picked up without relaunching
(`host-discovery`, "Access given later").

### D7. The Info.plist declares the service

`AudioVueConsole-Info.plist` gains `NSBonjourServices` with `_audio-vue._tcp`, an array, which an
`INFOPLIST_KEY_` build setting cannot carry. Without it, macOS refuses the browse. The existing
`INFOPLIST_KEY_NSLocalNetworkUsageDescription` is reworded to say the app finds and connects to the
audio-vue panels on the local network.

### D8. The picker

Where it sits and how it names the panel are superseded by D11; its menu and the held-panel match
stand.

The picker's menu shows the held panel as `PanelLabel` does now, then a section of the found panels
that are not held, by instance name, then Add Panel…. A found panel is the held one when its id is the
held host's (`host?.id`, else `foundPanel?.id`) or its address is the held address. While denied,
the section is one line saying the app may not reach the local network, and that Privacy & Security,
Local Network, in System Settings allows it. `PanelLabel` takes the found panel's instance name for an
unpaired held panel that was found: the one chosen, or the one found at the held id or address
(`PanelDiscovery.held(id:address:)`), so a panel reached at its remembered address is named as
announced. The window reads `PanelDiscovery` and calls `HostConnection`;
it does no networking. The App makes both in its own `init`, since one `@State` initialiser cannot
read another, and starts the browse there rather than in a view's `.task` (`pitfalls.md`, "A `.task`
on a view with nothing to show never runs").

### D9. Tests

- Merging, as a pure function: one id under two instances, a renamed instance, two hosts of one
  name, a missing `id`, one of two instances withdrawn, all withdrawn. Whether the framework already
  merges a host seen on two interfaces is seen in the run by hand, where it must be listed once.
- `PanelDiscovery` over a scripted `ServiceBrowser`: updates, resolves, the denied state.
- `HostConnection` over `FakeTransport` and a scripted browser: a found paired panel at a new
  address, an id that does not match, a refused token, the launch fallback and its cancel.
- `LiveHostTests` gains a discovery test, run only when asked, that finds the proving host by its id.
  `swift test` runs outside the app's sandbox, so macOS asks the app that launched it (Terminal or the
  editor) for local network access, not this app.
- By hand: the Local Network prompt, a denial and access given later, from a standalone launch of
  the built app (`open`), since Xcode's launch shows no prompt (`pitfalls.md`).

### D10. Connected means the panel can be used

Its naming and mark are superseded by D11; its rule on connected stands.

Found in the maintainer's run: an unpaired panel showed a green "Connected to audio-vue.local" above
"This Mac isn't paired", and the picker named it `audio-vue` while the title and status said
`audio-vue.local`. To a person, connected means the panel can be used, and one panel has one name.

- `ConnectionStatus` says "Connected to <name>", green, only for `.connected(paired: true)`. For
  `.connected(paired: false)` it shows only the API version and state schema; nothing says connected.
  Connecting names the panel too. A failure keeps the address, since it is about reaching it.
- While `.connected(paired: false)`, `OverviewForm` leads with a section above Panel: "Pair with
  <name> to see and control its panel.", what pairing takes, and Pair… as the default button. The
  Pairing section keeps the address and the version, and Pair Again while paired.
- `PanelWindow` builds the `PanelLabel` once and gives its name to `OverviewPage` for the title and
  the status, so the picker, the title and the status cannot disagree.
- `PanelLabel.isUp` is `Bool?`: nil without the host's identity, which is read only while paired, so
  the picker shows no mark rather than a grey one that reads as down.

The state stays as it is: `HostConnection.State` already tells paired from not; only what the window
says of it changes. Found in the maintainer's run: with the agent stopped, the page said not live at
the top and still "Connected" in green below. `ConnectionStatus` takes a `HostContact` read from
`LiveState`: connected while live, connecting before any state, "Lost contact… Trying again…" in
orange once it stops.

### D11. The picker moves to the Panel page

The maintainer's next look: `audio-vue` alone, as the window's title, reads as the product, not a
panel, and nothing said it was discovered; and switching panels need not sit on every page. D10's
naming and mark give way to this.

- The sidebar is only the pages, and Overview is renamed Panel (`PanelSection.panel`,
  `PanelPage`, `PanelForm`, `PanelRows`); the page's first section is Status, since a page called
  Panel cannot open on a section called Panel.
- The picker is a `ToolbarItem(placement: .navigation)` on the Panel page, with the title removed
  (`.toolbar(removing: .title)`), so it sits where the title was; the title stays "Panel" for the
  Window menu. Other pages keep their own titles and have no picker. SwiftUI's title menu is not
  offered on macOS, hence a toolbar item.
- It reads "Panel:", then a menu named for the panel held: the host's name when paired, else the
  address, else the instance name until resolved; with "(discovered)" while found and not paired.
  `PanelLabel` is reduced to that name and `isDiscovered`; the up mark and the shape go, with
  `DisplayShape`, since the Status section shows the condition and the display's size.
- The found panels are listed by address, or instance name until resolved (`FoundPanel.listedName`).
- The pairing prompt and the status use `PanelLabel.name`, without "(discovered)".

## Risks / Trade-offs

- [Anything on the LAN that announces a paired host's id gets that host's token] → Ruled acceptable
  (maintainer, 2026-11-06): the API is plain HTTP, so the token is already readable on the LAN. D4
  checks the id afterwards and saves nothing on a mismatch.
- [A false announcement that answers 401 makes the app forget a good token] → The same holds for
  any host at a remembered address today. The user pairs again, which needs someone at the panel.
- [`.local` names resolve by mDNS on each request, slower than an IP] → `URLSession` caches the
  lookup for a connection's life, and the events socket is one long connection.
- [`NetworkBrowser` may not leave the denied state when access is given] → D6 restarts the browser on
  activation while denied; the manual check confirms it.
- [The launch wait never ends when the panel never comes back] → It costs nothing while waiting, and
  the Pairing section shows the host could not be reached, as now.
