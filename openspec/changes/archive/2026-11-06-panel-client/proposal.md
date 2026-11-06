# Proposal

## Why

Pairing gave the app a token, so every route of the host's API is now open to it, but the app still
reaches the host through two hand-written calls in a debug-sized window, and the panel window it is
meant to be is a sketch of made-up values. This change gives the app one client for the whole API,
generated from the host's own contract, and makes the panel window real, starting with its Overview.

## What Changes

- **A generated client for the host API.** The host's OpenAPI contract is saved in this repository,
  refreshed from `make openapi` in `../audio-vue`, and the client is generated from it in the core
  package. The token and the no-`Origin` rule are applied in one place for every call. The hand-written
  version, pairing and clients calls move onto it.
- **Live state.** The app takes the panel's state from `/v1/events`, a WebSocket the contract cannot
  describe, written by hand, and keeps it current while the window shows a panel.
- **The supported API is the saved contract's.** The connect-time check compares the host's major
  version with the saved contract's, instead of a number written into the app.
- **The panel window becomes the app's window.** It ships in every build, and the Host Connection
  window is retired. An address is typed in the panel picker's Add Panel…, for one panel at a time.
- **A real Overview.** Its sections stay as sketched and in the same order, Panel, Capture and
  Calibration, filled from the host's state and `/v1/host`, with `—` for any value not read from the
  host yet. A Pairing section is added last: connected or why not, paired or not, Pair, and the host's
  clients inline with revoke. Entering the code stays a sheet.
- **Access goes.** The sidebar's Access page and the Host menu are removed; pairing and the clients
  list live in the Overview's Pairing section.
- The other sidebar pages (Scenes, Input, Calibration, Display, History) are unchanged.
- The host's software-update routes are not wired to anything.

## Capabilities

### New Capabilities

- `host-client`: How the app talks to a host's API: the saved contract it is generated from and how
  that contract is refreshed, the one place every call gets its token and loses any `Origin` header,
  and the live state pushed on `/v1/events`, its token, and what happens when the socket closes.
- `panel-window`: The app's one window for a panel: the panel picker with Add Panel…, the sidebar's
  pages, and the Overview's sections, what each shows from the host, `—` for what it does not, and the
  Pairing section with the clients list.

### Modified Capabilities

- `host-connection`: The address is typed in Add Panel… rather than a connect window; the supported
  major version is the saved contract's; the relaunch scenario names the panel window.

`host-pairing` is unchanged: its requirements do not say where pairing is offered, and `panel-window`
places it in the Overview.

## Impact

- **Code:** `ConsoleCore` gains the generated client, the saved contract and the events socket;
  `HostConnection` and the pairing and clients models move onto them. The app target loses
  `ConnectView`, `ClientsSheet` and `HostCommands`, and `SketchShell` and `SketchOverviewPage` become
  the real window and page, out of `#if DEBUG`.
- **Dependencies:** `swift-openapi-generator` (build plugin), `swift-openapi-runtime` and
  `swift-openapi-urlsession`, added to `ConsoleCore`.
- **Tooling:** a command to refresh the saved contract from `../audio-vue`, in `commands.md`.
- **Referenced specs:** `audio-vue:control-api` (the contract, the version read, the refused `Origin`,
  the pushed state, the host's read), `audio-vue:control-service` (tokens, pairing, clients, the
  panel's condition), `audio-vue:control-state` (the state's sections and its nulls).
