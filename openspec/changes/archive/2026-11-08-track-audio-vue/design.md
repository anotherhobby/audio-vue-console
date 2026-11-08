# Design

## Context

See `proposal.md` for why. The state today, read on 2026-11-08:

- **The version check.** `SavedContract` reads the saved contract's `info.version` and keeps only
  its `major`. `APIVersion.compatibility(with:)` compares majors alone: `hostNewer`, `hostOlder` or
  `compatible`. `HostConnection.connect(at:announcedID:)` reads the open version, saves the address,
  and sets `.incompatible(address, version)` unless the host is `compatible`. `ConnectionStatus`
  words that state "speaks API *x*, newer (older) than this app supports. Update the app (host)."
  Tests build their versions from `SavedContract.bundled.major` (`FakeTransport.supportedAPI`,
  `newerAPI`, `olderAPI`).
- **The render bundle.** `tools/refresh-render-bundle.sh` runs `make render-bundle` in the audio-vue
  checkout (`AUDIO_VUE`, default `../audio-vue`), rsyncs `local/render-bundle/` with `--delete`,
  then rebuilds `local/python-runtime/` only when its stamp (Python version and requirements hash)
  changed. It takes about one second when the runtime is current (measured 2026-11-08). The app
  target's script phase "Embed the render runtime" runs `tools/embed-render-runtime.sh`, which only
  rsyncs `local/` into the app's resources. Its inputs are the two `local/` directories, so it runs
  when Xcode sees them change, and never refreshes them. `ENABLE_USER_SCRIPT_SANDBOXING` is off, so
  the phase can read the checkout beside this one.

## Goals / Non-Goals

**Goals:**

- One version comparison, in `ConsoleCore`, against the saved contract's whole numeric core.
- A plain build carries the card code audio-vue's checkout holds now.

**Non-Goals:**

- Refreshing the saved contract during a build. A changed contract changes the generated client and
  can need code changes, so it stays a step at the start of project work (`.claude/CLAUDE.md`).
- Filtering found panels in the picker by their announced `api`. A refused host is said so on
  connect, as today.

## Decisions

### D1. The contract keeps its whole version

`SavedContract` keeps `version: APIVersion` in place of `major`. `APIVersion.compatibility(with:)`
compares `(major, minor, patch)` with the contract's: greater is `hostNewer`, less is `hostOlder`,
equal is `compatible`. Pre-release and build suffixes are still ignored, as `APIVersion` reads only
the numeric core. The `Compatibility` cases stay, so `HostConnection` and its tests keep their shape.

Rejected: comparing `description` strings, which would refuse `2.5.0+abc` against `2.5.0` and order
nothing; keeping major and minor only, which the maintainer ruled out (2026-11-08).

### D2. The refusal says what to do

`ConnectionStatus.incompatible` names both versions and the step:

- older: "*name* runs host API *x*; this app speaks *y*. Deploy audio-vue to the panel."
- newer: "*name* runs host API *x*; this app speaks *y*. Refresh this app's contract and build
  again."

The app's version comes from `SavedContract.bundled.version`. The status stays the orange triangle
it is today.

### D3. The embed phase refreshes first, on every build

`tools/embed-render-runtime.sh` runs `tools/refresh-render-bundle.sh` before copying, so one phase
does both, in order. Its own existence check stays, for a runtime the refresh could not build. Where
the checkout is missing or `make render-bundle` fails, the script prints `error: ...` naming the
checkout and `AUDIO_VUE`, and exits 1, so Xcode fails the build and shows the line. The phase must
run on every build: its inputs are directories outside what Xcode tracks by content, so dependency
analysis would skip it after a card changes. The phase sets the project format's `"run-on-every-build": true`,
Xcode's "Based on dependency analysis" unchecked (found when building, task 2.1).

Rejected: a separate phase before the embed, which Xcode may order or skip independently; a
pre-action in the scheme, which a build from the command line or the MCP tool does not run.

## Risks / Trade-offs

- [Each build runs audio-vue's `make render-bundle`] → about a second; the runtime is rebuilt only
  when its stamp changes, which may download a Python on that build.
- [The checkout holds uncommitted card code] → the app carries it. The panel shows the code of its
  last deploy, and the card-code check says where they differ, as it should.
- [Xcode's environment lacks `uv` on `PATH`] → only a runtime rebuild needs it. The script names
  the missing tool in its error, and running it by hand once fixes the runtime.
