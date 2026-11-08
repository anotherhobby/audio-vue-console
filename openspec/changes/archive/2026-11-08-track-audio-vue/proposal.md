# Proposal

## Why

On the maintainer's first run of `scene-save` (2026-11-08), the panel's host lacked a route the
saved contract has, and the app connected anyway. Reset then failed with "answered in a way this app
didn't expect", with nothing pointing at the cause. The app speaks exactly the saved contract's API
(`.claude/CLAUDE.md`, "Host Versions"), but `host-connection` lets through any host whose version
shares the contract's major. Once the panel was deployed, the app refused to draw scenes because its
card code differed from the panel's. A rebuild in Xcode did not fix it: a build copies only the
mirror `tools/refresh-render-bundle.sh` writes, and that script runs only when someone remembers to.

## What Changes

- **A host is used only at the saved contract's version** (maintainer, 2026-11-08). The app connects
  to a host only when the API version it reads is the saved contract's, by its numeric core. Any
  other version is refused on connect, as another major is today. The status says the host is
  newer or older than this app, and what to do: deploy audio-vue to the panel where the host is
  older, or refresh the app's contract where it is newer. This replaces "any minor and patch of the
  contract's major is compatible".
- **Every build carries audio-vue's current card code** (maintainer, 2026-11-08). The app target's
  build refreshes the render bundle's mirror from the audio-vue checkout before embedding it, on
  every build, so a rebuild after audio-vue's cards change draws them. The interpreter is still
  rebuilt only when its version or requirements change. The script stays runnable by hand, and its
  check mode is unchanged.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `host-connection`: "The app checks API compatibility on connect" takes the saved contract's whole
  version, not its major.
- `host-client`: "The supported API is the saved contract's" names the version, not the major.
- `render-runtime`: "The render bundle is mirrored from audio-vue" is refreshed by each build, not
  only by hand.

## Impact

- Code: `APIVersion` and `SavedContract` (`ConsoleCore`), `HostConnection.connect`, the incompatible
  status in `ConnectionStatus.swift`, and their tests (`APIVersionTests`, `SavedContractTests`,
  `HostConnectionTests`, `FakeTransport`'s versions). The app target's "Embed the render runtime"
  build phase in `AudioVueConsole.xcodeproj/project.xcproj` and `tools/embed-render-runtime.sh`.
- A build now needs the audio-vue checkout and its `make render-bundle` each time, as building the
  runtime already did once.
- Referenced specs: `audio-vue:control-api` ("The API states its version": the open version read),
  `audio-vue:render-bundle` ("The bundle holds what the helper needs": what `make render-bundle`
  writes).
