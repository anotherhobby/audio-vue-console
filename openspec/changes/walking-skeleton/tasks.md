# Tasks

## 1. The core package

- [ ] 1.1 Create `ConsoleCore/` with `Package.swift` (Swift 6 language mode, macOS 27, warnings as
  errors, library `ConsoleCore`, Swift Testing target `ConsoleCoreTests`) and one placeholder test;
  verify `swift test` passes from `ConsoleCore/`
- [ ] 1.2 Add `ConsoleCore` to the Xcode project as a local package and link it to the app target,
  either in Xcode (File > Add Package Dependencies > Add Local) or by editing `project.xcproj` once its
  package format has been checked against a real example; verify the app builds through Xcode MCP
  with `import ConsoleCore` in `MyApp.swift`
- [ ] 1.3 Add the boundary tests from `app-boundaries` (no SwiftUI or AppKit in `ConsoleCore/Sources`,
  no Network or `URLSession` in `AudioVueConsole/`); verify they pass, then fail and name the file
  when a temporary offending import is added
- [ ] 1.4 Record the package layout, `swift test` and the boundary tests in `project-map.md` and
  `commands.md`; verify each recorded command runs as written

## 2. Addresses and versions

- [ ] 2.1 Implement `HostAddress` parsing (hostname or IPv4, optional port 1-65535, default 19200)
  and URL building from its parts; verify tests cover the `host-connection` address scenarios,
  including invalid hosts, ports 0 and 65536, and an empty port
- [ ] 2.2 Implement `APIVersion` parsing and the compatibility verdict against supported major 1
  (compatible, host newer, host older, unreadable); verify tests cover `1.4.2`, `2.0.0`, `0.9.0`, a
  pre-release suffix, and malformed strings

## 3. Reading the version

- [ ] 3.1 Implement `HostTransport`, its `URLSession` version (ephemeral session, 5 s timeout), and
  `HostClient.version(at:)` decoding `{api, schema}`; verify with a fake transport that the request is
  `GET http://<host>:<port>/v1/version` with no `Origin` header
- [ ] 3.2 Map outcomes to the `host-connection` failure kinds (unreachable or timed out, 403 refused,
  any other status or a bad body unexpected); verify a test for each, with the fake transport
  throwing or returning each case

## 4. The connection model

- [ ] 4.1 Implement the `@MainActor @Observable` connection model (address text, state: idle,
  connecting, connected with version and schema, incompatible newer or older, failed with kind) and
  `connect()`; verify tests drive each `host-connection` scenario through it with the fake transport,
  including invalid addresses sending nothing
- [ ] 4.2 Add the last-address store (a protocol over `UserDefaults`, in memory in tests); save when a
  host answers with a version and load it at startup without connecting; verify a test for save,
  reload, and no save on failure

## 5. The app shell

- [ ] 5.1 Replace the template's `ContentView` with a connect view (address field, Connect button,
  status for every state, including the API version and the schema or "panel not answering"), and
  rename `MyApp` to `AudioVueConsoleApp`; verify the build through Xcode MCP and that
  `RenderPreview` shows the view in its idle, connected and failed states
- [ ] 5.2 Add `INFOPLIST_KEY_NSLocalNetworkUsageDescription` and a partial Info.plist outside
  `AudioVueConsole/` with `NSAppTransportSecurity` → `NSAllowsArbitraryLoads`, set as
  `INFOPLIST_FILE`; verify the built app's Info.plist contains both and the build log shows no
  duplicate Info.plist

## 6. Against a real host

- [ ] 6.1 Run the app and connect to the proving host as `audio-vue.cabin.hobbysprawl.com`, as
  `audio-vue`, and by IP address; verify each shows connected with API version 1.0.0 and schema 1,
  which also proves no `Origin` was sent, and record what the local network prompt did in
  `pitfalls.md` or `commands.md`
- [ ] 6.2 Connect to an address where nothing listens, and to a port that answers but isn't the
  agent; verify the app says unreachable and unexpected answer respectively, and that the last good
  address is offered after a relaunch

## Workflow follow-up

- Run `openspec validate walking-skeleton` before review.
- Archive the change once the maintainer has reviewed it and the manual run has passed.
