# Code alignment

## Read

Pass 1, 2026-11-04.

- `proposal.md`, `design.md`, `tasks.md` and both spec deltas, as written this session.
- `audio-vue:control-service`, in full: "A client pairs by a code on the panel", "A pairing code is
  short-lived and cannot be guessed at", "A paired client can be revoked", "Everything but pairing
  and the version takes a token", "An unpaired client cannot start a stopped panel", and the
  requirement headers of the rest, none of which the plan relies on.
- `audio-vue:control-api`, in full: the contract, the version as an open read, no `Origin`, the host's
  id and display size (null with the panel down), the announcement's `id`.
- `audio-vue:host-store`: "What the store holds" (clients survive a restart), "A token is not stored
  in the clear", "A store on another version is rebuilt" (clients pair again).
- audio-vue's open changes (`openspec list --store audio-vue`): none. `settings-store` is archived
  (`bd214e1`), so no delta can move under the plan, and none names a spec of ours.
- The contract, `../audio-vue/local/openapi.json` (2.0.0): the pairing routes' responses (200, 403,
  409, 429, 503, 422, no security), `/v1/clients` (200, 401), `DELETE /v1/clients/{client_id}` (204,
  401, 404, 422), `/v1/host` (200, 401), the `Client`, `Token` and `PairingAsked` schemas, and the
  `HTTPBearer` scheme. No response declares a header.
- `../audio-vue/src/control_service/pairing.py`: `Pairing.ask`, `confirm`, `_lapse`, `_end`, and the
  constants `CODE_TTL_S` 120, `TRIES` 5, `COOLDOWN_S` 30, `DIGITS` 6.
- `../audio-vue/src/control_service/app.py`: `_refused` (the `detail` body and `Retry-After`),
  `_pairing` (the four routes), `paired`, `API_VERSION`.
- `../audio-vue/src/control_service/contract.py`: `PairingAsked`, `PairingShown`, `Token`, `Client`,
  `Clients`, `Host`, `Refusal`.
- `../audio-vue/src/host_store.py`: `add_client` (`paired_at` as ISO 8601 to the second, UTC offset),
  `clients`, `revoke`.
- The proving host, 2026-11-04: `/v1/version` 200 with `{"api":"2.0.0","schema":1}`; `/v1/host`,
  `/v1/openapi.json` and `/v1/clients` 401 with `{"detail":"pair first: this takes a token"}`.
- `ConsoleCore/Sources/ConsoleCore/`: `HostClient.swift` (`version(at:)`, the status constants,
  `HostFailure`), `HostTransport.swift` (`get`, `URLSessionTransport`), `HostConnection.swift`
  (`State`, `connect()`), `AddressStore.swift`, `APIVersion.swift` (`supportedMajor`,
  `compatibility`), `Package.swift`.
- `ConsoleCore/Tests/ConsoleCoreTests/`: `FakeTransport.swift`, `HostClientTests.swift`,
  `HostConnectionTests.swift`, `APIVersionTests.swift`, `BoundaryTests.swift`.
- `AudioVueConsole/ConnectView.swift` (the `@State` connection, `ConnectionStatus`, the previews) and
  `AudioVueConsoleApp.swift`.
- A sandboxed probe (2026-11-04): `Host.current().localizedName` and
  `SCDynamicStoreCopyComputerName` give `hobbymac` in under a millisecond, `ProcessInfo.hostName` gives
  `hobbymac.local`; the container's home is `~/Library/Containers/<bundle id>/Data`.
- `.claude/kb/agent/pitfalls.md` and `open-questions.md` (empty).
- Searched `ConsoleCore/`, `AudioVueConsole/`, the KB and `openspec/specs/` for every use of
  `HostTransport`, `get(`, `supportedMajor`, `.connected`, `HostConnection(` and the version strings
  the tests use.
- Every task, 1.1 through 6.2, against the code as the tasks before it leave it.

## Findings

- **F1. The host's 409 means opposite things on the two pairing routes** (resolved)
  - Plan, before: `busy` for any 409, and `host-pairing` names "a pairing already under way" only.
  - Code: `Pairing.ask` answers 409 when a code is showing; `Pairing.confirm` answers 409, "no pairing
    is under way", when the code lapsed or was withdrawn after the last wrong try.
  - Goes to: design D4 and tasks 3.1, 3.3, 5.2 (resolved, `noCode`); and a requirement: "A refused
    pairing says why" has no scenario for a code no longer showing (Q1).
  - Resolution: the design and tasks map statuses per call. Q1 ruled yes (maintainer, 2026-11-04):
    the requirement names a code no longer showing, with the scenario "A code that lapsed".

- **F2. `FakeTransport` gives one answer to every request** (resolved)
  - Plan, before: tests drive connects and pairings through the fake, as today.
  - Code: `FakeTransport` holds a single `Answer`. A connect now makes two requests (the version, the
    host) and a pairing three (confirm, host, an optional revoke).
  - Goes to: task 1.2.
  - Resolution: the fake answers by method and path and fails the test on a request it has no answer
    for.

- **F3. Major 2 breaks fixtures the tasks did not name** (resolved)
  - Code: `FakeTransport.version`'s default is `"1.0.0"`, which `thePanelIsDown` and others expect to
    connect; `APIVersionTests`' table and `anIncompatibleHostIsNotConnected` assume major 1;
    `ConnectView`'s "Connected" preview builds `1.0.0`. `HostClientTests`' `"1.0.0"` bodies test
    parsing only and can stay.
  - Goes to: task 1.1.
  - Resolution: named in 1.1.

- **F4. `Retry-After` is in the code, not the contract** (resolved)
  - Plan: a 429's wait comes from `Retry-After`.
  - Code: `_refused` sets it; no response in `openapi.json` declares a header, and no spec states it.
    The `detail` says the seconds in words.
  - Goes to: design (already: `tooSoon` with and without it, task 3.1) and audio-vue (Q2).
  - Resolution: Q2 ruled yes (maintainer, 2026-11-04): the maintainer asks audio-vue's session to
    declare the header on the 429 in the contract. Nothing here waits on it.

- **F5. `paired_at`'s format is unstated** (resolved)
  - Code: the contract says string; `add_client` writes `isoformat(timespec="seconds")` in UTC.
  - Goes to: design D7 and task 4.2.
  - Resolution: read as ISO 8601, shown as given where it does not parse.

- **F6. Three models sharing a client and a store had no owner** (resolved)
  - Plan, before: `ConnectView` builds the client and store and hands them to three models that mark
    one another.
  - Code: `ConnectView` holds `@State private var connection = HostConnection()`; a view's `@State`
    initialisers cannot share an instance between them.
  - Goes to: design D7 and tasks 4.1, 5.1.
  - Resolution: `HostConnection` owns the client and the store and makes the pairing and clients
    models, which report back to it.

- **F7. `Host` is Foundation's** (resolved)
  - Plan: D8 calls `Host.current()`, and task 3.1 left the `/v1/host` answer's type unnamed.
  - Goes to: design D1 and task 3.1.
  - Resolution: the answer is `HostIdentity`.

- **F8. `HostClient` would pass the gate's 200 lines a type** (resolved)
  - Code: `HostClient.swift` is 81 lines for one call; the plan adds five calls with their status
    maps and bodies.
  - Goes to: design D4 and tasks 3.1, 4.2.
  - Resolution: the calls go in `HostClient+Pairing.swift` and `HostClient+Clients.swift`, by subject,
    which is how they would be read anyway.

- **F9. An atomic write then a `chmod` leaves a moment at the umask's mode** (resolved)
  - Plan, before: "written atomically and set to `0600` on every write".
  - Code: `Data.write(options: .atomic)` creates its file at the process's umask, 0644 by default. A
    new container also has no Application Support folder until something makes it.
  - Goes to: design D3 and task 2.2.
  - Resolution: a temporary file created at `0600` is moved over the old one; the store creates its
    folder on the first save.

- **F10. A default token store would let tests write the real file** (resolved)
  - Code: `HostConnection(client:store:)` defaults its `AddressStore`, and three tests construct it
    without one. `State.connected` is matched in `ConnectView` (line 76, the preview at 136) and in
    `aCompatibleHost` and `thePanelIsDown`.
  - Goes to: design D3 and tasks 4.1, 5.1.
  - Resolution: the token store has no default; each caller is named in its task.

- **F11. A 503 is also "a running panel would not show a code"** (resolved)
  - Plan, before: a 503 means the panel is not running.
  - Code: `Pairing.ask` answers 503 for `control_link.NoPanel` and for `control_link.Refused`.
  - Goes to: design D5.
  - Resolution: the kind reads "the panel can't show a code", with the host's reason under it; the
    spec's scenario, a panel not running, still holds.

- **F12. The version's 401 must stay unexpected** (resolved)
  - Code: `somethingElseAnswers` expects a 401 on the version to be `unexpectedAnswer`; the version
    never carries a token, so a 401 there is not a refused token.
  - Goes to: design D4 and task 1.3.
  - Resolution: `tokenRefused` is only for a request that carried a token.

## Questions for the maintainer

Both answered on 2026-11-04, as recommended.

- **Q1 (F1).** Add to `host-pairing`'s "A refused pairing says why" a code no longer showing, with the
  scenario "A code that lapsed": WHEN the user sends a code after it lapsed or was withdrawn, THEN the
  app says the code is no longer showing and offers to ask for a new one? Recommended: yes. A user
  reading the code slowly meets it, and without the scenario it would be told a pairing is under way.
- **Q2 (F4).** Ask audio-vue's session to declare `Retry-After` on the pairing route's 429 in the
  contract? Recommended: yes, as a small contract fix there. The app reads it when present and copes
  without it, but the panel client's generator (next change) sees only what the contract declares.

## Confirmed

- Pairing takes no token, on both routes; the contract gives them no security and the code reads no
  `Authorization` (`_pairing`). `host-pairing`, "Requests carry the host's token".
- `PairingAsked.name` is 1 to 64 characters, counted by Python as code points, so cutting to 64
  Unicode scalars fits (D8).
- The code is six digits (`DIGITS`), stands 120 s for five wrong tries, and the next pairing waits
  30 s after one ends however it ended (`_end`, `_lapse`). Task 6.1's "Ask again within 30 s" and its
  second pairing at `audio-vue.local` meet that wait.
- Confirming gives `token` and `client_id` only, no host id (`Token`), so D1's read of `/v1/host` is
  needed; `Host.id` is "stable across addresses and restarts", and answers with the panel down.
- A paired client may revoke any client, itself included, with any valid token (`revoke` takes no
  owner check), so D2's revoke of the earlier client with the new token works; an unknown id is 404.
- Every token route answers 401 with `WWW-Authenticate: Bearer` for a missing or wrong token
  (`paired`), the same for both, so the app cannot and need not tell them apart.
- A host store rebuilt on another version drops its clients (`host-store`), the case `pitfalls.md`
  names; `host-pairing`'s "A refused token means pair again" covers it.
- `HostAddress.description` drops the default port and spaces (`anAnsweringHostsAddressIsSaved...`),
  so it is a stable key for D1's address map.
- `URLSession` sends no `Origin` today (`theRequestIsAGetOfTheVersionWithNoOrigin`); task 1.3 keeps
  that check on every new request.
- Foundation's `Host` and `FileManager` are not UI frameworks, so `ConsoleCore` may use them
  (`BoundaryTests`); the app target gains no `URLSession` or `Network` import.
- The sandbox needs no entitlement to write the container's Application Support.
