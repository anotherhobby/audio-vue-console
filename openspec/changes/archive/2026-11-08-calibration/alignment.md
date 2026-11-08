# Code alignment

## Read

Pass 1, 2026-11-08, against `dev` with `scene-save` built in the working tree, and the saved contract
matching audio-vue's (`tools/refresh-contract.sh --check`):

- Saved contract: `/v1/runs` (`Runs` of `RunEntry`: `run_id`, `has_report`), `/v1/runs/{id}` (open
  object), `/v1/runs/{id}/report` (`text/html`, 404); `/v1/commands/arm` (`Arm.stated`, body
  optional; 200, 409, 503, 504, 401, 422) and `/v1/commands/cancel` (no body; 200, 409, 503, 504,
  401); `Calibration` (`status`, `run_id`, `age_days`, `schedule_version`,
  `detector_schedule_version`, `trim_db`, `noise_floor_dbfs`, `lifecycle` as a string); `Capture`
  (`rate_hz`); no stimulus or audio route.
- `PanelState.swift`: keeps `calibrationStatus` and `calibrationAgeDays` of the calibration section,
  and `rateHz` from capture.
- `PanelRows.swift`: the Calibration section's Status and Age, the status words `calibrated`,
  `stale`, `shifted_by_hand`, `obsolete`, `uncalibrated`.
- `HostClient.swift` `call(at:token:_:)`, `body`, `sessionTransport()`: one middleware, `HostRules`;
  `requestTimeout` 5 s on an ephemeral session.
- `HostRules.swift` `intercept`: strips `Origin`, adds Bearer unless the operation is open, 401 to
  `TokenRefused`.
- `HostClient+Commands.swift`: `CommandOutcome`, `switchScene`, `resetPanel`, the private
  `outcome` readers a new `arm` and `cancel` can share.
- `HostClient+Scenes.swift` `install(at:token:)`: reads `GET /v1/install` into blocks (not needed
  after the rate ruling).
- `HostConnection.swift`: `host: HostIdentity?` carries the host's id; no `GET /v1/host` call.
- `AddressStore.swift`: `UserDefaults` keys for the last address and host id.
- `HelperProcess.swift`: `HelperLauncher`, `RunningHelper`, `ChunkChannel`, the seam `CalibrationPlayer`
  copies.
- `AudioVueConsoleApp.swift`: `renderer` held as app `@State`; `AppDelegate.applicationShouldTerminate`
  settles unsaved scenes first, the hook task 7.3 extends.
- `PanelWindow.swift`: `PanelSection`, `SamplePage` routing `.calibration` to `SketchCalibrationPage`.
- `Sketches/SketchPages.swift`, `SketchData.swift`, `sketch.json`: `SketchCalibrationPage` and
  `calibratedDaysAgo`, read only by it.
- `ConsoleCore/Tests/ConsoleCoreTests/`: `FakeTransport`, `HostClientCommandsTests`,
  `PanelStateTests`, `PanelRowsTests`, `BoundaryTests` (forbids SwiftUI and AppKit in the core;
  Network and `URLSession` in the app target; not WebKit).
- swift-openapi-urlsession `URLSessionTransport.Configuration`: `httpBodyProcessingMode`
  `.platformDefault`, streaming on macOS.
- `AudioVueConsole.xcodeproj/project.xcproj`: sandbox on, user-selected files read-only, network
  client on, `ENABLE_USER_SCRIPT_SANDBOXING` `NO` for the app target.
- audio-vue `cal-play/src/main.rs` and `macos.rs` `find`: commands, exit 1 with standard error, a
  case-insensitive substring match on the name, `SETTLE_S` 12.
- audio-vue `src/panel_state.py` `_calibration`, `src/scene.py` `state_of` and `UNDER_WAY`,
  `src/products/calibration.py`: the lifecycle words `off`, `arming`, `waiting`, `running`,
  `analysing`, `done`, `failed`, `expired`.
- audio-vue `src/control_service/poller.py` `condition_of`: `no_audio` is capture frames older than
  `NO_AUDIO_S`, not silence.
- audio-vue `src/scene_model.py` `installed_rate`, `capture_rate_for`; `src/calibration.py` `RATES`.
- audio-vue `Makefile` `calibrate`, `cal-fetch`, `cal-fetch-audio`; `tools/calibrate.py` `main`.
- WAV headers of `local/calibration-{48,96,192}k.wav` and `local/characterization-96k.wav`; a kept
  run's audio in `local/renders/calibration/`; a report in `calibration/runs/` scanned for loads.
- audio-vue specs in full where relied on: `control-api` (runs, a run named never pathed, the
  calibration's order, declared results), `control-commands` (an arm, arming never cancels, an arm
  that hears nothing, what an arm states, a cancel), `calibration-lifecycle` (all), `control-state`
  (the calibration section), `calibration-stimulus` (step lengths and rate, a calibration captures at
  the rate it calibrates, two runs). `openspec list --store audio-vue`: no active changes.
- This project's open changes: `scene-save` (modifies `panel-window`'s add and choose requirements
  and the Status section), `gallery-sections` (`scene-apply`, `scene-gallery`), `track-audio-vue`
  (`host-connection`, `host-client`, `render-runtime`).
- `.claude/kb/agent/open-questions.md`: no items. `pitfalls.md`: calibration's order, `Origin`, the
  sandbox and a child, Xcode's script sandbox and a phase's `id`, keep logic in packages, a host
  lacking a route.
- Each task read against the code as the tasks before it leave it.

Pass 2, 2026-11-08, after the maintainer dropped saving a run's audio and the ask for each run's kind
in the listing: the proposal, `calibration-history`, design (D6 removed, D7 to D9 now D6 to D8) and
tasks (group 8 removed, integration now group 8) reread against each other. Nothing in the code
changed between the passes. The app's sandbox stays read-only for user-selected files.

Pass 3, 2026-11-08, on audio-vue's reply (`calibration-reply-handoff.md`), its claims checked at the
line in `../audio-vue/`:

- `src/frame.py` `Calibration.state`: `waiting` is armed and watching for the marker, `arming` the
  marker found, then `running`, `analysing`, `done`, `failed`, `expired`, resting at `off`.
- `src/products/calibration.py`: `calibrate` sets `waiting`; `_listen` sets `arming` or `expired`;
  `_analyse_and_store` sets `done` after `analyse_run` returns, `off` on `RunCancelled`, `failed` on
  any exception; `audio_lost` sets `failed`.
- `src/scene.py` `CalibrationLifecycle`: `_arm_refused` returns `replaying a clip -- a calibration
  needs live input`, `capture has stopped`, `a calibration is under way`, `still arming`; `cancel`
  refuses with `nothing to cancel` and `too late -- the record is being written`, and finishes done
  with `record_stands`.
- `src/control_service/runs.py` `listing`: `run_id` and `has_report` from filenames only.
- Every artifact reread against the reply and revised: the proposal, `calibration-run`,
  `calibration-history`, design D3, D4, D6, D7 and risks, tasks 3.1, 5.2, 5.3, group 6, 7.2, 8.1, 8.2.

Pass 4, 2026-11-08, after the maintainer moved the stimulus to the app:

- `local/render-bundle/manifest.json`: holds `src/calibration.py`, `src/calibration_run.py` and
  `src/products/calibration.py`.
- audio-vue `tools/calibrate.py` `main`: `--write` is `calibration.make_schedule(rate=, maximum_dbfs=,
  internal_folding_hz=, kind=)` then `calibration.write_wav(path, schedule)`.
- audio-vue `src/render_service.py` `handle`: `hello`, `prepare`, `render` only.
- `ConsoleCore` `RenderHelper.ask(_:)`, `Renderer.checkCode(with:)`, `CardCodeVerdict` (`same`,
  `differs`, `damagedBundle`), `PanelScenes.load()` (reads install and schema), `PanelRows` (Rate is
  `capture.rate_hz`).
- audio-vue `schema.export.json_schema()`: `install.input.rate` has no `default`; its help says
  "unset is 48,000 Hz". audio-vue `settings-schema`, "Every setting is declared once": each with a
  default.
- Timed: `tools/calibrate.py --write` at 96 kHz, 1.3 s and 5.9 s; the calibration's file
  byte-identical to `local/calibration-96k.wav`; the characterization's 219.9 MB.

Pass 5, 2026-11-08, on audio-vue's second reply (`calibration-reply-2-handoff.md`):

- audio-vue's open change `calibration-from-the-app` (planned, still being built): its deltas to
  `calibration-lifecycle` (a saved record completes), `calibration-stimulus` (the helper writes the
  stimulus; it refuses what an arm would), `control-api` (the lifecycle enum; `kind` and
  `applicable`; `ArmOutcome` and `CancelOutcome`), `control-state` (the ended calibration, standing
  until the next arm), read in full; they say what the reply says. Its Impact names none of this
  project's standing specs.
- `ConsoleCore` `RenderHelper.accepted`: reads `ok`, then `refused` as `RenderFailure.refused`, else
  `error` as `.failed`, the stimulus answer's shapes. No console code checks the helper's
  `protocol`, so `protocol: 2` needs no change. No console code reads the schema's version.

Pass 6, 2026-11-08, after the maintainer's review of the built app: no Advanced section (a run
states only its kind and rate; `StatedRun`, the arm's body and the stimulus request carry nothing
else), a characterization named Calibration + Characterization, and the run in force named by its
local start as the runs list names it (`RunEntry.title`). `calibration-run` and
`calibration-history` were revised to match; the tests were reshaped, 510 passing.

## Findings

- **F1. The run's rate is not the live capture rate** (resolved)
  - Plan: `calibration-run` took the rate the panel captures at when the run starts.
  - Code: audio-vue `calibration-stimulus` defaults a calibration to the installed capture rate;
    `scene_model.capture_rate_for` lets a scene capture at its own rate, so `capture.rate_hz` can
    differ; an unwritten install block reads back empty, the default being the host's.
  - Goes to: requirement.
  - Resolution: the maintainer ruled (2026-11-08) the host renders the file at the installed rate,
    asked for by kind and stated values, and the app reads the rate from the file. `calibration-run`,
    the proposal, design D3 and D4, tasks 5.1, 5.2, 6.2 and 6.3, and ask 1 follow.
- **F2. The client gives up after 5 s with nothing received** (resolved)
  - Plan: downloads come through `HostClient`.
  - Code: `HostClient.sessionTransport()` sets `timeoutIntervalForRequest` to `requestTimeout`, 5 s.
    A host rendering a characterization (197.5 MB) can pause longer.
  - Goes to: design.
  - Resolution: D5 uses a download client whose session waits 60 s for data, still under
    `HostRules`; task 6.2 names it; ask 1 mentions the render time.
- **F3. The host's id comes from the connection** (resolved)
  - Plan: D2 and task 4.2 read the host's id from `GET /v1/host`.
  - Code: `HostClient` has no such call; `HostConnection.host` carries the id.
  - Goes to: design, task.
  - Resolution: D2 and task 4.2 use `HostConnection.host`'s `id`.
- **F4. A run must outlive the window** (resolved)
  - Plan: task 7.3 asks in `AppDelegate`, but no task said who holds the session.
  - Code: `AudioVueConsoleApp` holds the renderer as app `@State` so it outlives the window, and
    `AppDelegate` reaches the scene store for its quit prompt.
  - Goes to: design, task.
  - Resolution: D3 makes the session the app's, beside the renderer; task 5.2 says so.
- **F5. Removing the sketch page leaves `calibratedDaysAgo` unread** (resolved)
  - Plan: task 2.5 removes `SketchCalibrationPage`.
  - Code: `SketchPanel.calibratedDaysAgo` (`SketchData.swift`) and its `sketch.json` values are read
    only by that page; Periphery would flag them.
  - Goes to: task.
  - Resolution: task 2.5 removes both.
- **F6. A crashed app leaves cal-play playing** (resolved)
  - Plan: `calibration-player` ends a running player when the app quits.
  - Code: `cal-play` reads no standard input, so it does not end with its parent the way the render
    helper does.
  - Goes to: design.
  - Resolution: a quit terminates it (task 1.4); a crash is accepted in D's risks, at most 342.9 s
    of playing into a panel that measures it as usual.
- **F7. The lifecycle words are stated by no spec or contract** (resolved)
  - Plan: the session maps the panel's calibration lifecycle.
  - Code: the words are read from audio-vue's code; the contract declares a string.
  - Goes to: design (ask 2).
  - Resolution: ask 2 asks audio-vue to declare them; D's risks: a word the app does not know shows
    as the panel's word and does not end the run, held by task 5.2's test.
- **F8. Sizes and counts were estimates** (resolved)
  - Plan: "7 MB, about 12 s", "197 MB, about 5.7 min", "about 800 runs".
  - Code: computed from the headers: 7.0 MB and 12.2 s, 197.5 MB and 342.9 s at 96 kHz; 800 is a
    checkout's copy, not the host.
  - Goes to: design.
  - Resolution: design Context carries the measured numbers.
- **F9. The proposal misnamed what `gallery-sections` touches** (resolved)
  - Plan: Sequencing said `scene-save` and `gallery-sections` touch `panel-window`.
  - Code: `gallery-sections` has deltas for `scene-apply` and `scene-gallery` only.
  - Goes to: proposal.
  - Resolution: Sequencing names each change's surface, and that each refresh needs audio-vue
    deployed (`track-audio-vue`); tasks' preamble says so.

- **F10. A run's ending cannot be read from the lifecycle word** (resolved)
  - Plan: D3 ended a run on `done`, `failed` or `expired`, with `armed` covering `arming` and
    `waiting`.
  - Code: `waiting` is listening and `arming` the marker heard for about 50 ms; `done` and `failed`
    pass to `off` after the hold, and `expired` gives the panel back at once (`_give_back`).
  - Goes to: requirement, design, task.
  - Resolution: the maintainer ruled (2026-11-08) the state will name the run that ended and how;
    `calibration-run`'s step and ending requirements, D3 and tasks 5.2 and 6.4 follow, the field's
    name pending audio-vue's second reply.
- **F11. A failed run usually writes no record** (resolved)
  - Plan: a failed run opened its report, found by the listing's difference within 30 s.
  - Code: `audio_lost` and an exception in `_analyse_and_store` set `failed` with nothing written.
  - Goes to: requirement, design, task.
  - Resolution: the maintainer ruled (2026-11-08) a failed run says why and opens a report only where
    it wrote one; the difference heuristic (old D7, task 5.4) is removed.
- **F12. Cancel has a done answer after completion, and a too-late refusal** (resolved)
  - Plan: Cancel showed the host's answer.
  - Code: `CalibrationLifecycle.cancel` answers done with `record_stands` during the hold, and refuses
    with `too late -- the record is being written`.
  - Goes to: requirement (scenarios), design, task.
  - Resolution: `calibration-run` gains both scenarios; D3 and task 5.3 handle them.
- **F13. Each run's kind is back in the list** (resolved)
  - Plan: the list showed no kind (pass 2).
  - Code: none yet; audio-vue will add kind and applied to `GET /v1/runs`.
  - Goes to: requirement, task.
  - Resolution: the maintainer reversed the earlier ruling (2026-11-08); `calibration-history` lists
    the kind, task 6.5 shows it; "applied" waits for its meaning.
- **F14. Reports have no links** (resolved)
  - Plan: a link in a report opened in the browser.
  - Code: audio-vue's reply: inline stylesheet, inline SVG, no links.
  - Goes to: requirement, task.
  - Resolution: `calibration-history` and task 3.1 drop link handling; every navigation but the first
    load is cancelled.

- **F15. The Panel page's rate is not the installed rate** (resolved)
  - Plan: the maintainer noted the installed rate is already pulled down in the Panel view.
  - Code: the Panel page's Rate row is `capture.rate_hz`, the live rate, which a scene can set
    (`scene_model.capture_rate_for`); `install.input.rate` is read already, by `PanelScenes.load()`.
  - Goes to: design, task.
  - Resolution: D4 and task 6.3 read `install.input.rate` from the install settings the app already
    has, not the Panel page's row.
- **F16. The schema declares no default rate** (resolved)
  - Plan: an unwritten rate takes the schema's default.
  - Code: `install.input.rate` is exported with no `default`, against audio-vue's `settings-schema`.
  - Goes to: design, task (an ask to audio-vue).
  - Resolution: `calibration-handoff-2.md` asks for the default; until then D4 leaves Calibrate…
    disabled on a panel with no rate written, with no default of the app's own.
- **F17. The helper has no request that writes a stimulus** (resolved)
  - Plan: the app renders the stimulus with the bundled code.
  - Code: `render_service.handle` answers only `hello`, `prepare` and `render`; `tools/` is not
    bundled.
  - Goes to: design, task (an ask to audio-vue).
  - Resolution: `calibration-handoff-2.md` asks for a `stimulus` request; D4 and task 6.2 use it.

- **F18. audio-vue's open change amends specs this plan relies on** (open, by design)
  - Plan: the ending, the stimulus, the rate's default and the listing's kind come from
    `calibration-from-the-app`.
  - Code: that change is planned and still being built; a name may move.
  - Goes to: task.
  - Resolution: the plan takes its names from audio-vue's plan; task 6.1 checks them against the
    refreshed contract and bundle before 6.2 to 6.5, and the follow-up carries any moved name from
    audio-vue's final reply.
- **F19. A failed run never has a record; a saved record always completes** (resolved)
  - Plan: a failed run opened a report where it wrote one.
  - Code: `calibration-from-the-app` makes a run with a saved record end `done`, with the report's
    failure as its `reason`.
  - Goes to: requirement, design, task.
  - Resolution: `calibration-run` says a failed run says why, and a completed run whose report was
    not written says so; D3, 6.4 and 7.2 follow.

## Questions for the maintainer

None open. F1 was ruled on 2026-11-08: the host renders the stimulus at the installed capture rate,
and the app reads the rate from the file. Also ruled the same day: no run's audio is saved from the
app; and, on audio-vue's reply, the state names the run that ended, the listing names each run's kind
(reversing pass 2), and the new ending requirement. Then, the same day: the app renders the stimulus,
replacing the host's route. Pending audio-vue's second reply, not a question for the maintainer: the
ended-run field's name and shape, and what "applied" means.

## Confirmed

- Runs are listed newest first and served with the panel down; a run is asked for by id; a report is
  `text/html` with a 404 (audio-vue `control-api`, saved contract).
- The contract states the calibration's order on the arm route (audio-vue `control-api`).
- An arm's `done` means listening on the capture that will measure; the same arm again restarts the
  deadline; a different arm while listening, or any arm during a run, is refused with the reason; an
  arm states `kind`, a file rate within the calibration's rates, a maximum not above 0 dBFS and a
  folding frequency above 0 Hz (audio-vue `control-commands`, `src/calibration.py` `RATES`).
- A cancel works while listening, capturing and analysing, writes no record, and is refused once
  the record is being written (audio-vue `control-commands`).
- An expired arm returns the displaced scene with no hold; a run with a stimulus missing is kept and
  never applied (audio-vue `calibration-lifecycle`).
- No run's audio is served, so the app offers none; `make cal-fetch-audio` fetches it (audio-vue
  `control-api`, "A run is named, never pathed"; `Makefile`).
- `no_audio` means capture frames have stopped arriving, so offering Calibrate… only while `up` is
  right (audio-vue `poller.condition_of`).
- `cal-play` exits 1 with its reason on standard error, matches a device by a case-insensitive
  substring, and holds 12 s after a rate change (audio-vue `cal-play/src`).
- A report is self-contained: no script, stylesheet or image loaded from elsewhere
  (`2026-10-25T23-16-08Z.html`).
- The generated client streams response bodies on macOS (`URLSessionTransport`,
  `.platformDefault`).
- `HostClientCommandsTests`, `PanelStateTests`, `PanelRowsTests`, `FakeTransport` exist where the
  tasks name them; `AppDelegate.applicationShouldTerminate` and the picker's and Add Panel's
  unsaved-scene prompts exist for task 7.3 to extend.
- WebKit in the app target breaks no boundary test, and the core needs no UI framework for
  CoreAudio, `Process` or file moves.
- No audio-vue open change touches a spec this plan relies on, and none names `panel-window`.
