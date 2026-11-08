# Code alignment

## Read

Pass 1, 2026-11-08, against `dev` with `scene-save` built in the working tree:

- `APIVersion.swift`: `compatibility(with:)` compares majors alone; `init?(parsing:)` reads the
  numeric core and ignores pre-release and build suffixes.
- `SavedContract.swift`: keeps `major` and `openOperations`; `init(major:openOperations:)` is used
  by `APIVersionTests` only; `bundled` reads `ContractFile.url`.
- `HostConnection.swift` `connect(at:announcedID:)`: the only caller of `compatibility`, refusing
  with `.incompatible(address, version)`; `HostClient.version(at:)` throws `unexpectedAnswer` for an
  `api` that is not semantic.
- `ConnectionStatus.swift` `incompatible(_:_:)`: the wording "newer/older than this app supports.
  Update the app/host"; no `#Preview` shows a refused host.
- Every use of `.major`, `compatibility`, `supportedAPI`, `newerAPI`, `olderAPI`: `FakeTransport`,
  `HostConnectionTests` (lines 49, 64-65, 104), `APIVersionTests`, `SavedContractTests` (lines 10,
  19). `AddPanelSheet`'s preview builds an `APIVersion` but never compares it. Discovery reads no
  `api`.
- Saved contract `info.version`: 2.5.0, read as the example in scenarios only.
- `tools/refresh-render-bundle.sh`: `make -s -C "$audio_vue" render-bundle`, rsync with `--delete`,
  runtime rebuilt on a stamp change with `uv`; under a second with the runtime current (timed).
- `tools/embed-render-runtime.sh`: checks `local/` exists, then rsyncs both into the resources.
- `AudioVueConsole.xcodeproj/project.xcproj`: the "Embed the render runtime" script phase with
  directory `input-paths` and `output-paths`; `ENABLE_USER_SCRIPT_SANDBOXING` is `NO`.
- audio-vue `Makefile` `render-bundle`: `./.venv/bin/python tools/render_bundle.py
  local/render-bundle`, so it needs no `PATH` beyond `make`.
- audio-vue `control-api` "The API states its version" and `render-bundle` "The bundle holds what
  the helper needs", in full. `openspec list --store audio-vue`: no active changes.
- `.claude/kb/agent/open-questions.md`: nothing on versions or the bundle. `pitfalls.md`: "The
  panel's host can lack a route the saved contract has" (2026-11-08), carried by task 2.2.
- Each task read against the code as the tasks before it leave it.

## Findings

- **F1. A fixture a minor behind cannot exist at minor 0** (resolved)
  - Plan: task 1.2 makes `olderAPI` differ from the bundled version in minor.
  - Code: `FakeTransport` builds versions from the bundled contract, which may state `x.0.y`.
  - Goes to: task.
  - Resolution: task 1.2 lowers the minor where it is above 0, else the major.
- **F2. The project format's switch for always running a phase is not known** (resolved)
  - Plan: design D3 runs the phase on every build.
  - Code: `project.xcproj` is Xcode 27's text format; its script phase shows `input-paths`,
    `output-paths`, `shell` and `script`. No key for dependency analysis was found in this project
    or in Xcode's resources searched.
  - Goes to: task.
  - Resolution: task 2.1 finds it when building, else drops the paths, and its Verify reads the
    phase's line in a second build's log either way.
- **F3. `refresh-render-bundle.sh` prints its own failures without `error:`** (resolved)
  - Plan: design D3 fails the build with a line naming the checkout.
  - Code: the script runs under `set -eu`, and `make` or `rsync` failing prints their own messages.
  - Goes to: task.
  - Resolution: task 2.1 has `embed-render-runtime.sh` print the `error:` line when the refresh
    exits non-zero, before exiting 1.

## Questions for the maintainer

None. The two rulings this plan needs were given on 2026-11-08: exactly the saved contract's
version, and building this change now beside `scene-save`.

## Confirmed

- A refused host already does not show itself connected and keeps its address saved
  (`HostConnection.connect`); only the comparison changes.
- `make render-bundle` replaces its directory whole (audio-vue `render-bundle`), so the mirror's
  `--delete` rsync stays right when run on every build.
- No `scene-save` file is touched by this plan, except `pitfalls.md`, which task 2.2 edits in the
  entry `scene-save`'s run added.
