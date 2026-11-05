# Tasks

## 1. Requests with a method, a body and a token (ConsoleCore)

- [x] 1.1 Set `APIVersion.supportedMajor` to 2 (`APIVersion.swift`, design D9) and move
  `APIVersionTests` and `HostConnectionTests` to the `host-connection` scenarios as modified:
  `2.4.2` compatible, `3.0.0` newer, `1.0.0` older, the schema shown with `2.0.0`.
  `FakeTransport.version`'s default becomes `"2.0.0"`, `APIVersionTests`' table moves up a major,
  and `ConnectView`'s "Connected" preview names `2.0.0` (alignment F3); verify `xcrun swift test` in
  `ConsoleCore/`
- [x] 1.2 Replace `HostTransport.get` with `send(_ request: URLRequest)` in `HostTransport.swift`,
  with `URLSessionTransport` and `FakeTransport` (`Tests/ConsoleCoreTests/FakeTransport.swift`)
  following (design D4). `FakeTransport` answers by method and path, each with a status, a body and
  headers, recording every request, since a connect now makes two requests and a pairing three
  (alignment F2); a request it has no answer for fails the test. Verify the existing
  `HostClientTests` and `HostConnectionTests` pass unchanged in what they assert
- [x] 1.3 In `HostClient.swift`, build every request in one function taking the method, the path, an
  optional `Encodable` body sent as JSON, and an optional `HostToken` sent as `Authorization:
  Bearer`, never with an `Origin`; `version(at:)` goes through it with no token. Add
  `HostFailure.tokenRefused` for a 401 on a request with a token; verify `HostClientTests` for a
  request with a token, one without, a JSON body's `Content-Type`, no `Origin` on any of them, and a
  401 read as `tokenRefused`, while the version's 401 stays `unexpectedAnswer` as
  `somethingElseAnswers` has it

## 2. Keeping tokens (ConsoleCore)

- [x] 2.1 Add `HostToken`, a `Pairing` record (host id, token, `client_id`) and the `TokenStore`
  protocol (the pairing for an address, save one for a host id and address, forget a host id) in
  `TokenStore.swift`, with an `InMemoryTokenStore` in the tests (design D1, D3); verify a test that
  an address saved for one host id and then for another leads to the second only
- [x] 2.2 Add `FileTokenStore`: one `pairings.json` (`hosts` by id, `addresses` to ids) in the
  directory it is given, created on the first save. Each save writes a temporary file created at
  `0600` in that directory and moves it over the old (design D3, alignment F9). A missing file reads
  as empty, and an unreadable one as empty and replaced on the next save, through `do`/`catch`,
  since the gate refuses `try?`. Verify `FileTokenStoreTests` against a temporary directory for a
  round trip, a directory that does not exist yet, the file's mode after each save, forgetting, and
  a corrupt file

## 3. Pairing (ConsoleCore)

- [x] 3.1 In `HostClient+Pairing.swift` (design D4, alignment F8), add
  `HostClient.askPairing(at:name:)` (`POST /v1/pairing`, answering the code's `ttl_s` and `tries`),
  `confirmPairing(at:code:)` (`POST /v1/pairing/confirm`, answering the token and `client_id`) and
  `host(at:token:)` (`GET /v1/host`, as a `HostIdentity` (F7): its `id` and, unused for now, `name`,
  and `width_px` and `height_px`, null unless a running panel says them), with no token on the two
  pairing calls. Add `HostFailure.pairingRefused(PairingRefusal)`, by call (design D4, alignment
  F1): asking maps `busy` 409, `tooSoon(seconds)` 429 from `Retry-After` and `noPanel` 503;
  confirming maps `wrongCode` 403 and `noCode` 409; each carries the host's `detail`, and a 422 is
  `unexpectedAnswer`. Verify `HostClientTests` for each refusal on its own route, a 409 read
  differently on each, `tooSoon` with and without `Retry-After`, and neither pairing request
  carrying a token
- [x] 3.2 Add `ClientName.current` (design D8): `Host.current().localizedName` cut to 64 Unicode
  scalars, or the app's name when empty, with the cut a pure function; verify tests for a short
  name, a 70-character name, a name whose 64th scalar ends a multi-scalar character, and an empty
  one
- [x] 3.3 Add the `@MainActor @Observable` `HostPairing` (`HostPairing.swift`, design D7): states
  `idle`, `asking`, `showingCode(ttl, tries)`, `confirming`, `paired`, `refused(PairingRefusal)`; a
  code that is not six ASCII digits is refused locally with nothing sent; after a confirm it reads
  `host(at:token:)` for the id, revokes the id's earlier `client_id` with the new token if one is
  kept, a 404 taken as gone (design D2), then saves; a `tooSoon` refusal says when asking is allowed
  again; a `noCode` offers to ask again; verify `HostPairingTests` for every `host-pairing` scenario
  of "The app pairs by the code on the panel", "A refused pairing says why" and "The app keeps one
  token per host" ("Pairing again"), plus a failed revoke keeping the new token

## 4. Connect and clients (ConsoleCore)

- [x] 4.1 `HostConnection` takes a `TokenStore`, with no default (design D3, alignment F10), and
  owns it with its `HostClient`; `State.connected` gains whether the app is paired, and its callers
  follow: `HostConnectionTests`' `aCompatibleHost` and `thePanelIsDown`, and its three
  `HostConnection(` calls, given an in-memory store. After a compatible version it looks up the
  address's pairing: none is not paired; one is checked with `host(at:token:)`, a 200 paired, a
  `tokenRefused` forgetting it and not paired, any other failure a failed connection (design D6). It
  makes the `HostPairing` and `PairedClients` for the connected host, and each reports back to it to
  mark it paired or not paired (design D7, F6); verify `HostConnectionTests` for the three
  `host-connection` scenarios of "Connecting says whether the app is paired" and the `host-pairing`
  scenario "A token the host no longer takes"
- [x] 4.2 In `HostClient+Clients.swift`, add `HostClient.clients(at:token:)` (`GET /v1/clients`,
  `paired_at` read as ISO 8601 or kept as text, design D7, alignment F5) and `revoke(_:at:token:)`
  (`DELETE /v1/clients/{client_id}`, a 204, a 404 its own failure), and the `@MainActor @Observable`
  `PairedClients` (`PairedClients.swift`): it loads the list, marks this app by its kept
  `client_id`, revokes a client, and on revoking this app forgets the token and marks the connection
  not paired; a `tokenRefused`, while the version's 401 stays `unexpectedAnswer` as
  `somethingElseAnswers` has it on any of its calls does the same; verify `PairedClientsTests` for
  every scenario of "The app lists the host's paired clients", "The app revokes a paired client" and
  "Requests carry the host's token" ("Reading the clients"), a `paired_at` that is not ISO 8601, and
  that the boundary tests still pass

## 5. The views (app)

- [x] 5.1 `ConnectView` keeps its one `@State` `HostConnection`, now given a `FileTokenStore` in the
  container's Application Support, and opens the sheets on the models the connection makes (design
  D7, alignment F6). `ConnectionStatus`'s `connected` case and the "Connected" preview take the
  paired flag (F10). `ConnectionStatus` shows paired or not paired, with Pair… when not paired and
  Clients… when paired; verify the build and `RenderPreview` of `ConnectForm` connected and paired,
  and connected and not paired
- [x] 5.2 Add `PairingSheet` (`AudioVueConsole/PairingSheet.swift`): Ask for a code; a six-digit
  field with the code's time left; Pair; each refusal's kind, a lapsed or withdrawn code (`noCode`)
  among them, with the host's reason under it, after a wrong code the field cleared to type the code
  again and no Ask while the code stands (`HostPairing.mayAsk(at:)`, after the maintainer's run,
  2026-11-04), Ask for a New Code once it lapses, and Ask again enabled when a `tooSoon` wait has
  passed; verify the build and `RenderPreview` of the sheet showing a code, after a wrong code, and
  too soon
- [x] 5.3 Add `ClientsSheet` (`AudioVueConsole/ClientsSheet.swift`): each client's name and pairing
  date, This Mac marked, Revoke with a confirmation that says, for this Mac, that it will have to
  pair again at the panel; verify the build and `RenderPreview` with three clients, this Mac among
  them
- [x] 5.4 Make pairing easy to find (maintainer, 2026-11-04, after trying 5.1): the `HostConnection`
  moves to the App, so closing the window keeps it, and the connect window becomes a single `Window`
  ("Host Connection") that reopens from the Window menu, with an app delegate that keeps the app
  running with no window. `HostConnection` holds the `pairing` and `clients` being shown, set by
  `pair()` and `showClients()`, with `isPaired`, so the window and menu share them (design D7). The
  connect form gains a Pairing section with Pair with This Host… or Show Clients…, in place of the
  status row, and a Host menu (`HostCommands.swift`) gives both, bringing the window forward. The
  default button is the next step (maintainer, 2026-11-04): Connect, beside the address, until
  connected there, when it becomes a plain Reconnect and Pair with This Host… is the default.
  Pairing in the panel window's Overview and Access pages waits for the panel client; verify
  `HostConnectionPairingTests` for the shared models, the build, and `RenderPreview` of the form
  connected, paired and not
- [x] 5.5 Connect at launch (maintainer, 2026-11-04, after the run):
  `HostConnection.connectAtLaunch()` connects once to the address remembered from the last launch,
  and only from `idle`; `ConnectView` calls it from `.task`. The `host-connection` delta modifies
  "The app remembers the last address"; verify `HostConnectionTests` for a relaunch connecting once
  and a first launch sending nothing, and the build

## 6. Against the proving host

- [x] 6.1 Checkpoint: the maintainer runs the app against `audio-vue.cabin.hobbysprawl.com` and
  works through every `host-pairing` and `host-connection` scenario the host can show: connect (not
  paired, API 2.0.0), pair with the code on the panel, a wrong code, Ask again within 30 s, close
  the window and reopen it from the Window menu (still connected), pair from the Host menu, relaunch
  (connects by itself, paired), a rebuild from Xcode and connect (paired, no password asked), list
  the clients, connect at `audio-vue.local` and pair again (one entry for this Mac), revoke this Mac
  (not paired). Record in this task what each showed; verify each scenario passes or becomes a
  finding with a fix before this box is ticked
  Run by the maintainer, 2026-11-04. Every step passed once these were fixed: pairing was hard to
  find from the status row (5.4: a Pairing section, a Host menu, the connection kept with the window
  closed); Connect stayed the blue default once connected (5.4: the default button is the next
  step); the app did not connect at launch (5.5); and "Ask for a New Code" after a typo left it
  waiting out the code and the host's 30 s (5.2: retype the code, no asking while it stands).
  Connect showed not paired at API 2.0.0, pairing at the panel, relaunch and an Xcode rebuild stayed
  paired with no password asked, the clients list, a second address paired once, and revoking this
  Mac all showed as the scenarios say.
- [x] 6.2 Record what is built: `project-map.md` (the token store, the pairing and clients models
  and sheets), `host-contract.md` (anything the run measured), `pitfalls.md` (anything the run
  found), and `working-notes.md` (pairing done, the panel client next); verify each note names the
  file it describes

## Workflow follow-up

- Run `openspec validate pairing --strict` before review.
- Archive the change once the maintainer has reviewed it and the manual run has passed.
