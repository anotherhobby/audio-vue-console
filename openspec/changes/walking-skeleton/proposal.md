# Proposal

## Why

The app is still Xcode's "Hello, world!" template. Before building the canvas or pairing, we need the
thinnest real path from window to host: launch, reach a host agent over the LAN, and confirm this app
speaks its API. That path carries the riskiest assumptions: networking from the sandbox, the host
refusing any `Origin` header, the version check on connect, and macOS's local network privacy. It
also sets the package layout every later change builds on.

## What Changes

- Add a local Swift package, `ConsoleCore`, that holds the app's logic and cannot import SwiftUI or
  AppKit. It has its own tests, run with `swift test`.
- `ConsoleCore` reads the host's `GET /v1/version` and decides whether the app is compatible with
  the host's API.
- The app target's window takes a host address, connects, and shows one of these: connected with the
  API version, the host is newer or older than this app, or why the connection failed. It
  remembers the last address.
- Tests hold the boundaries: `ConsoleCore` imports no UI framework, and the app target does no
  networking of its own.
- The app's Info.plist gains what LAN HTTP needs: a local network usage description, and an App
  Transport Security setting that allows plain HTTP to any host.
- The template's `ContentView` and `MyApp` are replaced.

Out of scope: pairing and tokens, the generated OpenAPI client, `/v1/events`, discovering hosts
automatically, more than one host, and the canvas.

## Capabilities

### New Capabilities

- `host-connection`: reaching a host agent at an address the user gives, checking API compatibility
  on connect, and reporting the outcome.
- `app-boundaries`: the structural rules that keep logic portable and networking in one place: the
  core cannot import a UI framework, and the UI does no networking.

### Modified Capabilities

None. There are no specs yet.

## Impact

- New: `ConsoleCore/` (Swift package and tests) at the repository root, added to the Xcode project
  as a local package dependency.
- Changed: `AudioVueConsole/` sources and the app target's Info.plist settings.
- The host is unchanged. The app relies on `GET /v1/version` and the no-`Origin` rule from audio-vue's
  `control-api` spec.
- The quality gate type-checks `ConsoleCore`, since it's a SwiftPM package. App-target code is
  checked file by file only (`pitfalls.md`), so the shell stays thin.
