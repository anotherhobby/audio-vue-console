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

- 2026-11-03: `cd ConsoleCore && xcrun swift test` - builds the core and runs its Swift Testing
  suite, the boundary tests included. Runs from the package folder, not the root. Add
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

- 2026-11-05: `python3 -I tools/test_optional_nullables.py` - the nullable rewrite's tests, plain
  asserts with no pytest, since `tools/` has no environment for the gate to resolve imports in.

- 2026-11-05: `AUDIO_VUE_LIVE_HOST=audio-vue.cabin.hobbysprawl.com AUDIO_VUE_PAIRINGS_DIR="$HOME/Library/Containers/com.hobbysprawl.AudioVueConsole/Data/Library/Application Support" xcrun swift test --filter LiveHostTests`
  in `ConsoleCore/` - watches the real host's `/v1/events` with the app's own pairing, read but
  never written, and prints the first state. Skipped without both variables. Passed on the proving
  host (2026-11-05): states arrive and the handshake is not refused, so URLSession's WebSocket adds
  no `Origin`. Since 2026-11-06 it also browses the LAN for the host by the id `/v1/host` gives and
  checks the resolved address answers (`theHostIsFoundByItsID`); it passed, finding `audio-vue` at
  `audio-vue.local`. `swift test` runs outside the app's sandbox, so any Local Network prompt goes to
  the app that launched it (Terminal or the editor), and a denial there fails this test only.

- 2026-11-07: `tools/refresh-render-bundle.sh` - runs `make render-bundle` in `../audio-vue` (override
  with `AUDIO_VUE=<path>`), mirrors its `local/render-bundle/` into this checkout's
  `local/render-bundle/` (deleting what audio-vue's no longer holds), then builds
  `local/python-runtime/`: uv's relocatable CPython at the version the checkout's `.venv` runs, with
  the bundle's `requirements.txt` installed, `__pycache__` removed. The runtime is rebuilt only when
  that version or the requirements change (`local/python-runtime/.stamp`); downloads are kept in
  `local/python-downloads/`. All of `local/` is ignored by git. `--check` lists how the mirror differs
  and exits 1, copying nothing. Run it after cloning and after audio-vue's card code changes: a build
  without the runtime fails, naming it. First run about 9 s; the runtime is about 358 MB.
- 2026-11-07: the app target's build phase "Embed the render runtime" runs
  `tools/embed-render-runtime.sh`, which rsyncs `local/python-runtime/` and `local/render-bundle/`
  into `Contents/Resources/python/` and `render-bundle/`. The app is about 375 MB (Debug) and
  `codesign --verify` passes on it.

- 2026-11-07: `RENDER_HELPER_LIVE=1 xcrun swift test --filter LiveHelperTests` in `ConsoleCore/` -
  runs the real render helper from `local/` (build it first with `tools/refresh-render-bundle.sh`):
  `hello`, whose digest must equal `local/render-bundle/manifest.json`'s, then the RTA scene
  (`Tests/ConsoleCoreTests/Fixtures/rta-scene.json`, audio-vue's `scenes/rta.yaml` as JSON) at
  1920 x 720, then one plate. It prints its timings. Measured (2026-11-07, M4 Pro), caches empty then
  filled: `hello` 0.44 s / 0.20 s, whole scene 9.7 s / 2.3 s, one plate 0.03 s / 0.03 s. Skipped
  without the variable.
