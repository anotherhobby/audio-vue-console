# Verified Commands

Record commands that have been verified in this repository.

Format:

- YYYY-MM-DD: `command` - what it checks or does, plus any caveats.

- 2026-11-02: `openspec init --tools claude --profile custom` - created `openspec/` and the twelve
  `openspec-*` skills, with no commands, because the global config (`openspec config list`)
  already sets `delivery: skills` and all twelve workflows. CLI 1.14.3. Regenerate the skills
  with `openspec update`; do not hand-edit them.

- 2026-11-02: `claude mcp add --scope project xcode -- xcrun mcpbridge` - wrote `.mcp.json`, giving
  Claude Code Xcode's MCP tools. Each new session asks once to approve the project server, and
  Xcode may ask to allow the connection. Until Xcode approves the agent, every Xcode tool fails with
  "isn't approved"; call `XcodeOpenWorkspace` on `AudioVueConsole.xcodeproj` first, which is what
  raises the approval. `xcrun mcpbridge run-agent --dry-run claude` prints how Xcode launches its
  own agent.

- 2026-11-03: `cd ConsoleCore && xcrun swift test --disable-xctest` - builds the core and runs its
  Swift Testing suite, the boundary tests included. Runs from the package folder, not the root.
  Without `--disable-xctest` the run also starts an XCTest pass the suite has no tests for, which
  sat idle past 10 minutes on 2026-11-08 (0% CPU, main run loop waiting); with it, 445 tests ran in
  0.06 s. Add
  `--filter BoundaryTests` to run only the boundaries. The runner prints `Target Platform:
  macos14.0`; that is the test host, not the package's platform.

- 2026-11-05: `tools/refresh-contract.sh` - runs `make openapi` in `../audio-vue` (override with
  `AUDIO_VUE=<path>`) and copies its `local/openapi.json` over
  `ConsoleCore/Sources/HostAPI/openapi.json`, the contract the client is generated from, with each
  nullable field written as optional by `tools/optional_nullables.py` (it refuses a required
  nullable, and the saved copy is left as it was; design D9). With
  `--check` it copies nothing, prints the diff and exits 1 on a difference: the start-of-work check in
  `.claude/CLAUDE.md`, "Host Versions". Always regenerates, since audio-vue's `local/openapi.json`
  can be older than its code. Never edit the saved copy by hand.

- 2026-11-09: `AUDIO_VUE_LIVE_OUTPUT=D10s xcrun swift test --disable-xctest --filter
  OutputControlLiveTests` in `ConsoleCore/`: sets the named output's rate and format through Core
  Audio, hears each change, and puts both back. Skipped without the variable. Passed on the D10s
  (2026-11-09). It changes the device for about a second, so mute what it feeds.

- 2026-11-05: `python3 -I tools/test_optional_nullables.py` - the nullable rewrite's tests, plain
  asserts with no pytest, since `tools/` has no environment for the gate to resolve imports in.

- 2026-11-05: `AUDIO_VUE_LIVE_HOST=audio-vue.local AUDIO_VUE_PAIRINGS_DIR="$HOME/Library/Containers/com.hobbysprawl.AudioVueConsole/Data/Library/Application Support" xcrun swift test --filter LiveHostTests`
  in `ConsoleCore/` - watches the real host's `/v1/events` with the app's own pairing, read but
  never written, and prints the first state. Skipped without both variables. Passed on the proving
  host (2026-11-05): states arrive and the handshake is not refused, so URLSession's WebSocket adds
  no `Origin`. Since 2026-11-06 it also browses the LAN for the host by the id `/v1/host` gives and
  checks the resolved address answers (`theHostIsFoundByItsID`); it passed, finding `audio-vue` at
  `audio-vue.local`. `swift test` runs outside the app's sandbox, so any Local Network prompt goes to
  the app that launched it (Terminal or the editor), and a denial there fails this test only.
  The host must be the address the app's `pairings.json` holds it under: since discovery that is
  `audio-vue.local` (2026-11-08), and the FQDN finds no pairing. `--filter LiveGalleryTests`
  (2026-11-08) prints the panel's gallery sections and its library's categories in order; passed
  on the proving host.

- 2026-11-07: `tools/refresh-render-bundle.sh` - runs `make render-bundle` in `../audio-vue` (override
  with `AUDIO_VUE=<path>`), mirrors its `local/render-bundle/` into this checkout's
  `local/render-bundle/` (deleting what audio-vue's no longer holds), then builds
  `local/python-runtime/`: uv's relocatable CPython at the version the checkout's `.venv` runs, with
  the bundle's `requirements.txt` installed, `__pycache__` removed. The runtime is rebuilt only when
  that version or the requirements change (`local/python-runtime/.stamp`); downloads are kept in
  `local/python-downloads/`. All of `local/` is ignored by git. `--check` lists how the mirror differs
  and exits 1, copying nothing. Every app build runs it (below), so
  run it by hand only for `--check` or outside Xcode. First run about 9 s; the runtime is about 358 MB.
- 2026-11-07: the app target's build phase "Embed the render runtime" runs
  `tools/embed-render-runtime.sh` on every build (`"run-on-every-build": true` in `project.xcproj`,
  2026-11-08): it runs `refresh-render-bundle.sh` first, failing the build with an `error:` line
  naming the checkout where that fails, then rsyncs `local/python-runtime/` and
  `local/render-bundle/` into `Contents/Resources/python/` and `render-bundle/`. About a second when
  the runtime is current. The app is about 375 MB (Debug) and
  `codesign --verify` passes on it.
- 2026-11-08: the app target's build phase "Build and embed cal-play" runs `tools/embed-cal-play.sh`
  on every build: `cargo build --release` of `../audio-vue/cal-play` (`AUDIO_VUE` overrides) into
  `local/cal-play-target/`, copied to `Contents/Helpers/cal-play`. It needs Rust: cargo is taken from
  `CARGO`, else `~/.cargo/bin/cargo` (not on Xcode's `PATH`); a missing cargo or checkout fails the
  build with an `error:` line saying how to fix it. Cargo's no-op rebuild is under a second. The
  binary is linker-signed ad hoc, and `codesign --verify --deep --strict` passes on the app.

- 2026-11-07: `RENDER_HELPER_LIVE=1 xcrun swift test --filter LiveHelperTests` in `ConsoleCore/` -
  runs the real render helper from `local/` (build it first with `tools/refresh-render-bundle.sh`):
  `hello`, whose digest must equal `local/render-bundle/manifest.json`'s, then the RTA scene
  (`Tests/ConsoleCoreTests/Fixtures/rta-scene.json`, audio-vue's `scenes/rta.yaml` as JSON) at
  1920 x 720, then one plate. It prints its timings. Measured (2026-11-07, M4 Pro), caches empty then
  filled: `hello` 0.44 s / 0.20 s, whole scene 9.7 s / 2.3 s, one plate 0.03 s / 0.03 s. Skipped
  without the variable.

- 2026-11-22: `cd ConsoleCore && xcrun swift test --disable-xctest` - 756 tests in 100 suites passed after
  `schema-trimmed.json` was refreshed from audio-vue's `json_schema()` (whole, keeping the tests'
  `x-categories`; `ensure_ascii` left on, as the file was written). `xcodebuild -project AudioVueConsole.xcodeproj
  -scheme AudioVueConsole -configuration Debug build` - succeeded, with no `-derivedDataPath`.

- 2026-11-22: `uv run --project /Users/cunnidm/code/claude-qualty-gate python
  /Users/cunnidm/code/claude-qualty-gate/quality_gate FILE ...` from the repository root - runs the
  quality gate by hand, printing `clean` or its findings per file. The gate's hook runs only on the
  Edit and Write tools, so run this on any Swift file changed by a script or `sed`.
  `cd ConsoleCore && xcrun swift test --disable-xctest` - 796 tests in 102 suites after
  `park-cards`.

- 2026-11-23: refreshing the schema fixture. From `../audio-vue`, `uv run python` with `src` on
  `sys.path`: `json_schema()` from `schema.export`, its `x-categories` replaced by the fixture's
  own, written with `json.dumps(indent=2)` plus a newline over
  `ConsoleCore/Tests/ConsoleCoreTests/Fixtures/schema-trimmed.json`. `Fixtures/rta-scene.json` is
  audio-vue's `scenes/rta.yaml` as `json.dumps(indent=1, sort_keys=True)` with no final newline.
  After both: 799 tests passed, and `RENDER_HELPER_LIVE=1 ... --filter LiveHelperTests` passed.
  `xcodebuild` failed with "database is locked" while Xcode had the project open. The Xcode MCP
  `BuildProject` on the open workspace built it.

- 2026-11-23: `--filter LiveRepairTests`, with the same two variables as `LiveHostTests`, in
  `ConsoleCore/` (read only):
  - It checks every scene on the host against its schema and prints what each needs.
  - It times the gallery's pass. A full walk over 5 scenes took 5 ms in debug and 2 ms with
    `-c release`. Held per scene by `SceneDrafts`, the pass took about 2 µs.
  - On 2026-11-23 the built-ins passed, and Analytical, Primary and Tangarine Meters each needed
    `rta_hold_s`, `rta_peak_fall_db_s` and `rta_weighting` removed from `analysis`.

- 2026-11-23: after audio-vue's `rta-fine-bands`, the schema fixture refresh above (no `rta-scene.json`
  change; `scenes/rta.yaml` sets no RTA setting), then `xcrun swift test --disable-xctest`: 816 tests in
  105 suites passed. `RENDER_HELPER_LIVE=1 ... --filter LiveHelperTests` passed on the refreshed bundle.

- 2026-11-23: `RENDER_HELPER_LIVE=1 xcrun swift test --disable-xctest --filter LiveTrackRenderTests` in
  `ConsoleCore/` - the real helper from `local/` draws `Fixtures/rta-scene.json` at 1920 x 720 from a
  generated 10 s 48 kHz stereo sine (`track`, pictures at 1 s and 5 s), then writes a 2 s clip at 30 fps
  from 3 s through `ClipWriter`. Measured on an M4 Pro (2026-11-23): `track` 0.85 s, each picture about
  0.2 s, the 60-frame clip 2.2 s (going back from 5 s to 3 s restarts the analysis). Skipped without
  the variable.
