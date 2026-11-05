# Code alignment

## Read

Pass 1, 2026-11-05.

- `ConsoleCore/Package.swift`: tools 6.2, one target and its tests, warnings as errors, Swift 6.
- `HostTransport.swift`: the `send(URLRequest)` seam and `URLSessionTransport` (ephemeral, uncached,
  five seconds).
- `HostClient.swift`: `version(at:)`, the one `send` (method, JSON body, optional token, no
  `Origin`), the 401-with-token rule, the unanswered `URLError` set, `decode` and `detail`.
- `HostClient+Pairing.swift`: `askPairing` (409, 429 with `Retry-After`, 503), `confirmPairing` (403,
  409), `host(at:token:)` and the existing `HostIdentity` (id, name, `width_px`, `height_px`).
- `HostClient+Clients.swift`: `clients(at:token:)`, `revoke` (204, 404), `PairedClient`.
- `HostConnection.swift`: the state enum, `connectAtLaunch`, `connect`, `isPaired(at:)` reading
  `/v1/host` and discarding it, `pair`, `showClients`, `makePairing`, `makeClients`, `mark`.
- `HostPairing.swift`: `confirm` reads `/v1/host` with the grant's token before `keep` saves it;
  `revokeEarlierClient` uses the grant's token.
- `PairedClients.swift`: `load` and `revoke` with the pairing's token; `unpair` forgets the host.
- `TokenStore.swift`, `HostToken.swift`, `HTTPStatus.swift`, `AddressStore.swift`,
  `APIVersion.swift` (`supportedMajor` used only inside the file), `HostAddress.swift`.
- `Tests/ConsoleCoreTests/FakeTransport.swift` (answers by method and path),
  `BoundaryTests.swift` (scans `ConsoleCore/Sources` for UI imports and `AudioVueConsole` for
  networking).
- App: `AudioVueConsoleApp.swift` (the Host Connection window, `HostCommands`, the Debug-only sketch
  window, `SceneStore` and `ArrangeCommands` in `#if DEBUG`), `ConnectView.swift` (`ConnectView`,
  `ConnectionActions`, `ConnectForm`, `ConnectionStatus`, `PairingSection`, previews),
  `ClientsSheet.swift` (`ClientsSheet`, `ClientsForm`), `PairingSheet.swift`, `HostCommands.swift`,
  `Sketches/SketchShell.swift`, `Sketches/SketchPages.swift`.
- `../audio-vue/local/openapi.json` (written 2026-11-04 07:16): every operation's `security`, the
  pairing and clients responses and headers, `Host`, `State`, `Sections` and their fields.
- `../audio-vue/src/control_service/app.py`: the contract's description, the `events` socket (1008
  before accept, first state then the queue), `NoOrigin`; `poller.py`'s `POLL_S`, `READ_WINDOW_S`,
  `PUSH_WHOLE_S`.
- audio-vue specs, in full by a delegated read: `control-api`, `control-service`, `control-state`;
  audio-vue's one open change, `card-layout`, with its deltas and Impact.
- KB: `pitfalls.md` (all), `open-questions.md` (no items), `project-map.md`, `host-contract.md`.
- Removals searched across `AudioVueConsole/`, `ConsoleCore/`, the Xcode project and the KB:
  `ConnectView`, `ConnectForm`, `ConnectionStatus`, `PairingSection`, `ConnectionActions`,
  `ClientsSheet`, `ClientsForm`, `HostCommands`, `showClients`, `clients`, `SketchSection.access`,
  `HTTPStatus`, `HostTransport`, `URLSessionTransport`, `supportedMajor`, `SketchShell`,
  `SketchOverviewPage`, `windowID`, `#if DEBUG`.

## Findings

- **F1. A store-reading middleware breaks pairing** (resolved)
  - Plan: D4 had `HostRules` take the token from the `TokenStore` for the call's address, and 3.3
    dropped the calls' token arguments.
  - Code: `HostPairing.confirm` reads `host(at:token: grant.token)` before `keep` saves the pairing,
    because the store is keyed by the host id that read gives.
  - Goes to: design, task.
  - Resolution: `HostRules` is made with the call's token; the calls keep `token:` (D4, 3.1, 3.3).
- **F2. `HostIdentity` already exists** (resolved)
  - Plan: design and tasks named a new `HostInfo`.
  - Code: `HostIdentity` in `HostClient+Pairing.swift` holds id, name, `widthPx`, `heightPx`.
  - Goes to: design, task. Resolution: `HostIdentity` throughout (D2, D7, D8, 4.1, 5.1, 5.2, 6.1).
- **F3. The generated client is bound to one server** (resolved)
  - Plan: D2 put `HostClient` over the generated `Client` without saying how addresses reach it.
  - Code: `HostClient` takes an address per call; the generated `Client` takes a server URL at init.
  - Goes to: design. Resolution: a `Client` per call for its address and token (D2, 3.2).
- **F4. audio-vue's saved contract file is older than audio-vue** (resolved)
  - Plan: 1.1 copied `../audio-vue/local/openapi.json`.
  - Code: that file was written 2026-11-04 07:16, and audio-vue has commits since.
  - Goes to: task. Resolution: the refresh script comes first and always runs `make openapi` (1.1, 1.2).
- **F5. The fake transport answers by route, not operation id** (resolved)
  - Plan: D5 and 3.2 had it answer by operation id.
  - Code: `FakeTransport` answers by method and path, and every client test is written that way.
  - Goes to: design, task. Resolution: it keeps answering by method and path (D5, 3.2).
- **F6. Parts the new views reuse live in files the plan deletes** (resolved)
  - Plan: 6.4 removed `ConnectView.swift` and `ClientsSheet.swift`; 6.2 and 6.3 reused their parts.
  - Code: `ConnectionStatus` and `PairingSection` are in `ConnectView.swift`, `ClientsForm` in
    `ClientsSheet.swift`.
  - Goes to: task. Resolution: 6.2 moves them to files of their own first (D8).
- **F7. The connect at launch is the deleted view's** (resolved)
  - Plan: 6.2 put the launch connect in the Add Panel sheet.
  - Code: `ConnectView`'s `.task` calls `connectAtLaunch()`; a sheet opens only when asked.
  - Goes to: task. Resolution: it moves to `PanelWindow`'s `.task` (D8, 6.2).
- **F8. Tests of `showClients` must move** (resolved)
  - Code: `HostConnectionPairingTests` near lines 119 and 127 call `showClients()` and read `clients`.
  - Goes to: task. Resolution: 5.2 turns them into `makeClients()` tests.
- **F9. The other pages take the picker's `SketchPanel`** (resolved)
  - Code: `SketchShell.detail` hands the picked `SketchPanel` to Scenes, Calibration and Display.
  - Goes to: design, task. Resolution: they take `SketchData`'s first sample panel (D8, 6.1).
- **F10. A failed section is not all nulls** (resolved)
  - Host: audio-vue `control-state`, "A section that fails is contained", gives
    `{"unavailable": "<reason>"}`, which a typed decode would read as every field null.
  - Goes to: design, task. Resolution: `PanelState` carries the reason, and the Overview shows `—` with
    the reason under the section (D7, 4.1, 5.1). Within the spec's dash rule.
- **F11. Words the host's states need** (resolved)
  - Host: `stale` means drawing stopped, not measuring stopped (audio-vue `control-service`); down
    carries `since`; calibration `status` is a plain string, with five values in audio-vue's
    `scene.py` today and no enum in the contract.
  - Goes to: design. Resolution: D7's words, with an unknown status shown as the host's text.
- **F12. A revoked client's open socket keeps streaming** (resolved)
  - Host: audio-vue's `events` loop checks the token only at the handshake; no spec covers it.
  - Goes to: design. Resolution: stated in D6; `host-client`'s scenario already says the refusal comes
    on reopening.
- **F13. The picker's shape when the panel is down** (resolved)
  - Plan: `panel-window`, "The picker names the panel": the host's name and display's shape when
    paired.
  - Host: `/v1/host`'s `width_px` and `height_px` are null unless a running panel says them
    (audio-vue `control-api`).
  - Goes to: requirement. Q1.
  - Resolution: ruled as recommended (maintainer, 2026-11-05): the name with no shape; `panel-window`'s
    requirement reworded, with a scenario for a down panel.
- **F14. `/v1/events`'s message shape is in the contract, not a spec** (resolved)
  - Plan: `host-client` relies on one whole `State` per message, the first on connect, whole every
    second, Bearer in the handshake, refused with 1008.
  - Host: `control-api`, "The state is pushed", says only that the state is pushed as it changes and
    moving fields at a slower rate. The rest is the contract's `info.description` and `app.py`.
    Likewise, 401, Bearer, 403 for `Origin` and the route paths are in the contract and code only.
  - Goes to: requirement source lines. Q2.
  - Resolution: ruled as recommended (maintainer, 2026-11-05): the saved contract is a host source of
    equal standing to audio-vue's specs; nothing is asked of audio-vue.

## Questions for the maintainer

Both answered 2026-11-05, as recommended.

- **Q1 (F13).** When the app is paired but the panel is down, the host gives no display size. What
  should the picker show? Recommended: the host's name with no shape, and the requirement reworded to
  "its display's shape when the host gives it", with a scenario for a down panel.
- **Q2 (F14).** Several host behaviours the plan relies on are stated by the contract audio-vue
  generates, and its code, but not by a spec: the events message shape and timing, 401 and Bearer, 403
  and 1008. Recommended: treat the saved contract as a host source of equal standing to its specs,
  since the app is generated from it and `host-contract.md` already ranks the running agent's contract
  first; cite it in the source lines as it is cited now; ask audio-vue for nothing.

## Confirmed

- The contract puts `security: HTTPBearer` on every token-taking operation and none on
  `GET /v1/version`, `POST /v1/pairing` and `POST /v1/pairing/confirm` (D3, D4).
- The contract declares `Retry-After` on the pairing ask's 429, so the generated client exposes it
  (3.3); `host-contract.md` already says so.
- `State` has `condition` with the five values and `sections`; `Sections` holds `scene.name`,
  `capture.device` and `rate_hz`, `analysis.p99_ms` and `budget_ms`, `calibration.status` and
  `age_days`, `display.width_px` and `height_px`; nullable fields are `anyOf [T, null]` (D7, 4.1).
- Readers ignore unknown fields (audio-vue `control-state`, "Adding to the state never breaks a
  reader"), and the contract leaves `State` open (4.1).
- The agent polls only while a client is connected or has just read, and the panel never waits on a
  client (audio-vue `control-service`, `control-state`), so an open socket costs the panel nothing
  (design risks).
- A deploy restarts the agent and a reboot brings it back (audio-vue `control-service`), so the
  socket closing and reopening is expected (`host-client`).
- The scene's `name` is shown as a label only, never handed back to the host, as `pitfalls.md`
  requires.
- `supportedMajor` is used only in `APIVersion.swift`; `HTTPStatus` only in the two `HostClient`
  extensions; `HostTransport` only in `HostClient.swift` and `FakeTransport`; `windowID` only in the
  files 6.4 deletes. `decisions-log.md` names `ConnectView` as history and stays.
- The boundary test scans `ConsoleCore/Sources`, where `HostAPI` holds no Swift; generated code is
  in the build directory and is not scanned.
- `pitfalls.md`'s `Origin` entry is carried by 4.4; `open-questions.md` holds no items.
- audio-vue's open change `card-layout` has no delta to `control-api`, `control-service` or
  `control-state`, and its Impact names only this project's `scene-layout` and `scene-canvas`, which
  this change does not modify.
- The backoff runs 1, 2, 4, 8, 16, then 30 s; five seconds of silence is five missed whole-state
  pushes at one a second (D6).
