# Tasks

## 1. The generated client builds (ConsoleCore)

- [ ] 1.1 Add `tools/refresh-contract.sh`: `make openapi` in `../audio-vue`, then copy
  `local/openapi.json` over `ConsoleCore/Sources/HostAPI/openapi.json`; `--check` prints the diff,
  copies nothing and exits non-zero on a difference (design D9). Verify both modes, the check
  passing after a refresh, and record both commands in `.claude/kb/agent/commands.md`. The
  `local/openapi.json` in audio-vue predates its later commits, so always regenerate (alignment F4)
- [ ] 1.2 Add `swift-openapi-generator`, `swift-openapi-runtime` and `swift-openapi-urlsession` to
  `ConsoleCore/Package.swift`, each pinned to an exact version, and a `HostAPI` target with the
  generator's build plugin, `openapi-generator-config.yaml` (types and client, idiomatic naming,
  internal access) and `openapi.json` written by 1.1's script, also declared a resource;
  `ConsoleCore` depends on `HostAPI` and no product exports it (design D1, D2). Verify
  `xcrun swift build` in `ConsoleCore/` with warnings as errors, the generated `State` and `Host`
  types holding nullable fields as optionals, and the plugin seeing `openapi.json` as a resource. Any
  warning, a failed check, or a setting the build seems to need goes to the maintainer before
  anything else changes
- [ ] 1.3 Build the app in Xcode through the MCP `BuildProject` and verify it succeeds with the plugin
  trusted; if Xcode asks to trust the plugin, list enabling it as a plain next step for the
  maintainer and wait

## 2. The saved contract decides the version and the open routes (ConsoleCore)

- [ ] 2.1 Add `SavedContract.swift`: read the bundled `openapi.json` once, giving `major` from
  `info.version` and `openOperations`, the operation ids with no `security` (design D3), through
  `do`/`catch` with no `try?`. Verify a `SavedContractTests` that the bundled contract gives a major
  and exactly the version and the two pairing operations as open, and that a contract string with no
  `info.version` or a non-semantic one is refused
- [ ] 2.2 Measure `APIVersion.compatibility` against `SavedContract`'s major, removing
  `supportedMajor` (`APIVersion.swift`). Verify `APIVersionTests` and `HostConnectionTests` for the
  `host-connection` scenarios as modified, with the newer and older majors taken as the saved
  contract's plus and minus one, so no test names a version the contract will outgrow

## 3. Every call through the generated client (ConsoleCore)

- [ ] 3.1 Add `HostRules`, a `ClientMiddleware` (`HostRules.swift`) made with an optional
  `HostToken`, that strips any `Origin` and attaches `Authorization: Bearer` to every operation outside
  `SavedContract.openOperations` (design D4). Verify `HostRulesTests` for an open operation with a
  token given (no header), a closed one (the token), a closed one with no token (no header), and no
  `Origin` on any, with an `Origin` set on the way in
- [ ] 3.2 Replace `HostTransport.swift` with the runtime's transport: the urlsession transport set up
  ephemeral, uncached, five seconds; `FakeTransport` becomes a `ClientTransport` answering by
  method and path as it does now, recording requests, failing the test on an unanswered one (design
  D5). Move `HostClient`'s version and `/v1/host` reads onto a generated `Client` built per call for
  the address and token (design D2), keeping `HostFailure` and
  the unanswered-error mapping, with a 401 on a closed operation as `tokenRefused`. Verify
  `HostClientTests` pass unchanged in what they assert, and the `app-boundaries` `BoundaryTests`
- [ ] 3.3 Move `HostClient+Pairing.swift` and `HostClient+Clients.swift` onto the generated client,
  keeping their `token:` arguments, which now only reach `HostRules`; `askPairing`'s `tooSoon` reads
  the generated 429's optional `Retry-After`. Verify `HostClientPairingTests`,
  `PairedClientsTests`, `HostPairingTests` and `HostConnectionPairingTests` pass unchanged in what
  they assert, then remove `HTTPStatus.swift` if nothing uses it
- [ ] 3.4 Update `.claude/kb/agent/project-map.md`'s host side for `HostAPI`, `SavedContract`,
  `HostRules` and the transport, and verify it names no file that no longer exists

## 4. Live state (ConsoleCore)

- [ ] 4.1 Add `PanelState` (`PanelState.swift`): the condition, the scene's name, the capture's
  device and rate, analysis p99 and budget, calibration status and age, the display's size, `since`, and
  each section's `unavailable` reason, each optional, made from the generated `State`;
  `HostIdentity` (`HostClient+Pairing.swift`) is made from the generated `Host`. Verify
  `PanelStateTests` from a whole state, a down state with empty sections, a section given as
  `{"unavailable": …}`, and a state with unknown extra fields
- [ ] 4.2 Add `EventSource`, the socket seam, with `WebSocketEventSource` over
  `URLSessionWebSocketTask`, its handshake built under `HostRules`' rules (design D6). Verify
  `EventSourceTests` that the handshake carries the token and no `Origin`
- [ ] 4.3 Add `LiveState` (`LiveState.swift`), `@MainActor @Observable`: `watch()` holds the newest
  `PanelState` and `isLive`; on a close keeps the state, marks it not live and reopens after 1 s
  doubling to 30 s, back to 1 s after a message; on a refused handshake reads `/v1/host`, and on its
  401 forgets the token and returns; cancellation closes the socket. Verify `LiveStateTests` with a
  scripted `EventSource` and a test clock for each `host-client` scenario: a pushed change, a closed
  socket coming back, the backoff's cap, a revoked token, and cancellation
- [ ] 4.4 Run `watch()` against the proving host from a test target the default run skips, and
  verify states arrive and the handshake is not refused, which rules out an added `Origin` (design
  risks); record the run in `pitfalls.md` only if something surprised

## 5. The Overview's rows (ConsoleCore)

- [ ] 5.1 Add `OverviewRows` (`OverviewRows.swift`), a pure function of the connection's state,
  `HostIdentity?` and `PanelState?` giving Panel, Capture and Calibration's labelled text and any
  section's unavailable reason, with `—` for every nil and everything while not paired, the words of
  design D7, and `DisplayShape` reducing a size to `16:9` (design
  D7). Verify `OverviewRowsTests` for the `panel-window` scenarios (paired and up, not paired, down), a
  section unavailable, and an unknown calibration status shown as the host's text
  and `DisplayShapeTests` for 1920 × 1080, 2560 × 960 and 3840 × 2160
- [ ] 5.2 Give `HostConnection` `host: HostIdentity?`, kept from the `/v1/host` read `isPaired(at:)`
  already makes and cleared when not paired, and a `liveState()` that makes a `LiveState` for the connected, paired host; remove
  `showClients()` and `clients`, with `makeClients()` kept for the inline list (design D8). Verify
  `HostConnectionTests` and `HostConnectionPairingTests` for the host kept on connect and pairing, and
  cleared on a refused token and on revoking this app; the two `showClients` tests
  (`HostConnectionPairingTests`, near lines 119 and 127) become `makeClients()` tests

## 6. The panel window (app target)

- [ ] 6.1 Move `SketchShell` to `PanelWindow.swift` and `SketchOverviewPage` to `OverviewPage.swift`
  out of `Sketches/`; make `PanelWindow` the app's one `Window` scene in `AudioVueConsoleApp.swift`,
  out of `#if DEBUG`, with `SceneStore` and `ArrangeCommands`; drop `SketchSection.access`; the
  picker shows the connection's panel by `HostIdentity` or address with its up mark, and the other
  pages take `SketchData`'s first sample panel; the `SketchOverviewPage` preview in `SketchPages.swift`
  moves with it (design D8). Verify a
  Release build through `BuildProject`, and a screenshot of the window open on Overview with the
  sidebar's six pages
- [ ] 6.2 Move `ConnectionStatus` and `PairingSection` out of `ConnectView.swift` and `ClientsForm` out
  of `ClientsSheet.swift` into files of their own, then add `AddPanelSheet.swift` from `ConnectForm`'s
  address field, `ConnectionStatus` and Connect, opened by the picker's Add Panel…; move
  `connectAtLaunch()` from `ConnectView`'s `.task` to `PanelWindow`'s.
  Verify previews for each connection state and a screenshot of connecting to the proving host
- [ ] 6.3 Fill `OverviewPage` from `OverviewRows`, starting `LiveState.watch()` in a `.task`, saying
  when the state is not live, and add the Pairing section last: address, connection, paired or not,
  Pair or Pair Again opening `PairingSheet`, and `ClientsForm` inline with revoke and its confirmation. Verify
  previews for not paired, paired and up, and down, and a screenshot paired with the proving host
- [ ] 6.4 Remove `ConnectView.swift`, `ClientsSheet.swift` and `HostCommands.swift`. Verify the
  Debug and Release builds, `xcrun swift test`, and `project-map.md`'s app-target section updated to
  match

## 7. Against the proving host

- [ ] 7.1 With the maintainer, run the app against the proving host: a first launch adds the panel by
  its address, pairs, and the Overview shows live values; a scene switched on the host shows without
  asking; restarting the agent shows not live and then live again; revoking this app from the inline
  list leaves it not paired with every value `—`. Record anything surprising in `pitfalls.md`, and
  update `working-notes.md`'s panel-client note

## Workflow follow-up

- Verify the change against its artifacts (`openspec-verify-change`).
- Archive the change and sync its specs once the maintainer's run passes.
