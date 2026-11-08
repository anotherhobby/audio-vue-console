# Tasks

## 1. The host is used only at the saved contract's version

- [x] 1.1 `SavedContract` (`ConsoleCore/Sources/ConsoleCore/SavedContract.swift`) keeps
  `version: APIVersion` in place of `major` (design D1), its `init(major:openOperations:)` becoming
  `init(version:openOperations:)`. `APIVersion.compatibility(with:)` compares `(major, minor, patch)`
  with the contract's version, and its doc comments drop "minor releases are taken to be additive".
  `APIVersionTests` covers each scenario of `host-connection`, "The app checks API compatibility on
  connect", against a contract stating 2.5.0 (equal, a build suffix, minor behind, patch ahead,
  major ahead and behind), and the bundled-contract test builds its versions from
  `SavedContract.bundled.version`. `SavedContractTests` reads the version in place of the major.
  Verify `cd ConsoleCore && xcrun swift test` passes.
- [x] 1.2 `FakeTransport.supportedAPI` is the bundled contract's version, and `newerAPI` is a minor
  ahead of it, and `olderAPI` a minor behind where its minor is above 0, else a major behind
  (alignment F1), so `HostConnectionTests`' refusal cases test what was let
  through before. Verify the suite passes.
- [x] 1.3 `ConnectionStatus.incompatible` (`AudioVueConsole/ConnectionStatus.swift`) words a
  refusal as design D2, naming the host's version and `SavedContract.bundled.version`, with a
  `#Preview` of each. Verify the app target builds, both previews render, and the quality gate is
  clean on the changed files.

## 2. Every build carries audio-vue's current card code

- [x] 2.1 `tools/embed-render-runtime.sh` runs `tools/refresh-render-bundle.sh` first (design D3),
  printing an `error:` line naming the checkout and `AUDIO_VUE` and exiting 1 where the refresh
  exits non-zero, as when the checkout is missing or its `make render-bundle` fails (alignment F3). The "Embed the render runtime" phase in
  `AudioVueConsole.xcodeproj/project.xcproj` runs on every build: the project format's
  `"run-on-every-build": true` (found in Xcode's DevToolsCore, 2026-11-08; Xcode notes "Based on
  dependency analysis" is unchecked), keeping the phase's input and output paths. Verify: change a file under `local/render-bundle/`, build with `mcp__xcode__BuildProject`,
  and the mirror and the built app's `Contents/Resources/render-bundle/` both match audio-vue's
  `local/render-bundle/` again (`tools/refresh-render-bundle.sh --check` passes, and `diff -r` of the
  app's copy against the mirror is empty); a second build with nothing changed still runs the phase
  (its line in the build log); `AUDIO_VUE=/nonexistent tools/embed-render-runtime.sh`, with the
  build variables set, exits 1 with the error line.
- [x] 2.2 The agent KB says a build refreshes the mirror: `commands.md`'s
  `tools/refresh-render-bundle.sh` and `embed-render-runtime.sh` entries, `project-map.md`'s
  `tools/` line, and `pitfalls.md`'s "The panel's host can lack a route the saved contract has",
  which now ends with the app refusing such a host on connect. `host-contract.md` says the app takes
  only the saved contract's version, recording no number. Verify by reading each entry back against
  the scripts and `APIVersion`.

## 3. The maintainer's run

- [x] 3.1 The maintainer builds in Xcode with nothing else run and opens a scene: the renderer draws
  (no "card code differs"). Against a host at another version than the saved contract's, the Panel
  page says which and what to do.

## Workflow follow-up

- Verify and archive the change after the maintainer's run.
