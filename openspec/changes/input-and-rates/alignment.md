# Code alignment

## Read

Pass 1, 2026-11-08, on `dev` at `a5b6576`, with `card-settings`, `scene-settings` and `styles`
planned and not built.

- `ConsoleCore/Sources/ConsoleCore/CalibrationSession.swift`: `start`, `cancel`, `observe`,
  `perform`, `render`, `settle`, `arm`, `play`, `cancelAtHost`, `finish`. One run at a time.
  `run == nil` gates `start`, and the file is removed on every ending.
- `CalibrationReadiness.swift`: paired, then not under way, then `.up`, then the code verdict, then
  the installed rate.
- `CalibrationRuns.swift`: `load` reads install and schema; `rate(install:schema:)`.
- `StatedRun.swift`: `kind`, `rate`. `HostClient+Commands.swift` `stated(_:)`: the arm sends `kind`
  and `file_rate` = `run.rate`. `HelperStimulus.file(for:)`: renders at `run.rate`.
- `HostClient+Scenes.swift` `install(at:token:)`: drops `rev`. Its callers are
  `CalibrationRuns.swift:45` and `PanelScenes.swift:72`.
- `HostClient+SceneWrites.swift` `writeScene`: maps 409 to `.stale(currentRev:)` by decoding
  `Stale`, and 422 to `.invalid`. `HostClient.swift`: `HostFailure` already has `stale(currentRev:)`
  and `conflict(String)`. `body(_:)` maps a decode failure to `.unexpectedAnswer`.
- `OutputDevices.swift`: `OutputDevice(uid, name)`, `CoreAudioOutputDevices.list()`. No rates read.
- `LiveState.swift`: `state`, `isLive`. `PanelState.swift`: `condition`, `calibrationLifecycle`.
- `AudioVueConsole/AudioVueConsoleApp.swift`: the delegate holds `player` and `calibration`;
  `applicationShouldTerminate` asks via `RunUnderWay.confirm` while `calibration.isUnderWay`.
- `AudioVueConsole/Calibration/RunUnderWay.swift`: `settle`, `confirm`, `waitForEnd`, all on a
  `CalibrationSession`.
- `AudioVueConsole/Calibration/CalibrationPage.swift`: `readiness`, `start`, `ended` (reloads runs,
  opens a completed run's report). `CalibrateSheet.swift`: `rate`, `start(StatedRun, OutputDevice)`,
  `CalibrateFields`. `RunProgress.swift`: `CalibrateSection`, `RunProgress`, `EndingRow`,
  `EndingText` (app target; uses `ReadFailureText`).
- `AudioVueConsole/PanelWindow.swift`: `.input` shows `SketchInputPage`; `observe` forwarding;
  `RunUnderWay.settle(calibration, before: "Switch Panels")`. `AddPanelSheet.swift`: holds
  `calibration` for the same prompt.
- `AudioVueConsole/Sketches/SketchPages.swift`: `SketchInputPage`, `SketchChainWarning` (used only
  by `SketchInputPage`).
- Saved contract: `PUT /v1/install/{block}` (`Edit`, `InstallWritten`, 409 `Stale` only),
  `GET /v1/install` (`InstallBlocks` of `InstallBlock` with `rev`), `GET /v1/host/devices`
  (`Devices`).
- audio-vue code: `src/schema/install.py` (`INPUT`: `device` text, `rate` int min 1 default
  48 000, both chain); `src/calibration.py` (`RATES`, `STATED`, `check_stated`, `make_schedule`);
  `src/scene.py` `_arm` (rebuilds at the stated `file_rate`, restores after);
  `src/control_service/settings.py` `put_install` (restart unless `DOWN`; 409 `CALIBRATING` as
  `{"detail"}`) and `Refused.response`; `src/control_service/app.py` `/v1/host/devices`;
  `src/control_service/host.py` `capture_devices`; `src/render_service.py` stimulus;
  `cal-play/src/main.rs` (`devices`, `rate <name>` printing rates as text, `SETTLE_S` 12).
- audio-vue specs read for what the plan relies on: `calibration-stimulus` ("A calibration captures
  at the rate it calibrates", "The helper refuses a stimulus an arm would refuse"),
  `calibration-lifecycle` ("A finished run holds the screen until audio returns", "The calibrate
  action during the hold arms a new run"), `control-commands` ("Back-to-back runs", "An arm that
  hears nothing ends itself"), `settings-store` ("A chain write restarts the panel"),
  `calibration-record` ("A run at another rate leaves the panel's own rate uncalibrated, and says
  so", "A record says which kind of run wrote it"). `openspec list --store audio-vue`: one active
  change, `loudness-scope`. Its only delta is to its own `loudness-scope` spec, and its Impact names
  our `scene-rendering`, which this change does not modify.
- KB: `pitfalls.md` ("Calibration: set the rate, wait, then arm"; "cal-play works from inside the
  App Sandbox"), `open-questions.md` (no held items for this code).
- Designed numbers: `make_schedule(rate=r, kind="calibration")` is 10.0 s at every rate in `RATES`,
  plus `LEADIN_S` 2.0 s, so 12 s of playback per rate. With `SETTLE_S` 12 s, render, arm and analysis,
  a rate takes about 35 to 45 s, and a five-rate pass about 3 to 4 minutes.

Pass 2, 2026-11-08, after the maintainer ruled that there is no Input page: the input goes on the
Calibration page, renamed Capture, and the runs show their rate under Calibration History.

- `AudioVueConsole/PanelWindow.swift`: `PanelSection` (`panel, scenes, input, calibration, display,
  history`), its titles and symbols, the detail switch (`.calibration` → `CalibrationPage`), and
  `SamplePage`'s switch (`.input` → `SketchInputPage`; `.calibration` among the later pages).
- `AudioVueConsole/Calibration/CalibrationPage.swift`: `CalibrationPage`, `CalibrationForm`, the
  `Section("Runs")`, `RunsList`, `RunRow`, and two previews that name `CalibrationForm`.
- `AudioVueConsole.xcodeproj`: `project.xcproj` names no source file, so renaming a file needs no
  project edit.
- `ConsoleCore/Sources/ConsoleCore/HostClient+Calibration.swift`: `RunEntry` (`id`, `hasReport`,
  `kind`) and `runs(at:token:)`. Saved contract `RunEntry`: `run_id`, `has_report`, `kind`,
  `applicable`, and no rate.
- `PanelRows.swift`: private `rate(_:)` words a rate as `44.1 kHz` or `96 kHz`.
- audio-vue `src/control_service/runs.py` `listing` and `_facts`: kind and applicability read from
  each record's JSON. `src/record.py`: the record holds `rate`, and `conditions` holds
  `capture_rate_hz`.
- Main specs naming the Calibration page: `calibration-run` ("Calibrate is offered only where a
  run can work"), `calibration-history` (Purpose and "The page shows the calibration in force") and
  `panel-window` ("The sidebar has no Access page"). No other open change of ours names it.
- `.claude/kb/agent/project-map.md:71` names `CalibrationPage` (task 7.2).

## Findings

- **F1. The install read has two callers** (resolved)
  - Plan (first draft): change `HostClient.install` to return revisions.
  - Code: `CalibrationRuns.load` and `PanelScenes` both call it for docs alone.
  - Goes to: design and task.
  - Resolution: D2 and task 3.1 add `installBlocks` and rebuild `install` on it, unchanged.
- **F2. The calibration refusal cannot be decoded** (resolved, host ask)
  - Plan: show the host's words when it refuses a write during a calibration.
  - Code: `put_install` answers 409 `{"detail": "a calibration has the panel -- cancel it first"}`.
    The contract declares 409 as `Stale`, which requires `current_rev`, so the generated client's
    decode fails and `body(_:)` gives `.unexpectedAnswer`.
  - Goes to: design and task.
  - Resolution: the handoff (1.1) asks audio-vue to declare it. Until then the page reloads and
    says the host refused the change (D2, 4.2), and the pickers are disabled during any
    calibration, so the refusal is seldom reached. Task 3.4 maps it once declared.
- **F3. The host restarts the panel in every condition but down** (resolved)
  - Plan (first draft): ask before writing while the panel is `.up`.
  - Code: `put_install` restarts unless `snapshot["condition"] == DOWN`, so `stale`, `no_audio`
    and `capture_stopped` restart too.
  - Goes to: design and task.
  - Resolution: D2 and 4.3 ask unless the live state says `.down`. The spec's "while the panel
    runs" already reads this way.
- **F4. Every quit and switch check asks the session** (resolved)
  - Plan (first draft): a `CalibrationPass` beside the session.
  - Code: `applicationShouldTerminate`, `RunUnderWay`, `PanelWindow`, `AddPanelSheet`,
    `CalibrateSection` and `CalibrationReadiness` ask `session.isUnderWay`, which is false between
    two rates.
  - Goes to: design and task.
  - Resolution: D4 makes the pass the app's one calibration (a single run is a pass of one rate),
    held by the delegate. Task 6.1 switches every caller, and 5.4 tests that `isUnderWay` holds
    between rates.
- **F5. The hold after a completed run** (resolved)
  - Plan (first draft): the panel captures at its installed rate after a pass.
  - Code/spec: the calibration scene holds at the last run's rate until audio returns
    (`calibration-lifecycle`). An arm during the hold starts a new run and rebuilds at the stated
    rate (`scene.py` `_arm`).
  - Goes to: design and the `calibration-pass` scenario (this change's own draft).
  - Resolution: the Context in design.md states the hold. The scenario "The install is left alone"
    says the installed rate returns once the hold ends. The pass arms back to back during the hold,
    as `control-commands` allows.
- **F6. The ending's words live in the app target** (resolved)
  - Plan (first draft): a `PassSummary` in ConsoleCore reusing the ending text.
  - Code: `EndingText` is in `AudioVueConsole/Calibration/RunProgress.swift` and uses the app's
    `ReadFailureText`.
  - Goes to: design and task.
  - Resolution: ConsoleCore orders the outcomes (5.5, tested), and the app words them beside
    `EndingRow` (6.3).
- **F7. Liveness is not forwarded** (resolved)
  - Plan: the pass stops when the panel goes down or the host is lost.
  - Code: `PanelWindow` forwards `live?.state` only; `LiveState.isLive` says whether it is current.
  - Goes to: design and task.
  - Resolution: `pass.observe(_:isLive:)` (D4, 5.4, 6.1).
- **F8. Other-rate reports say the installed rate is uncalibrated** (resolved, Q1)
  - Plan: a pass leaves a valid record at each rate.
  - Spec: audio-vue `calibration-record`, "A run at another rate leaves the panel's own rate
    uncalibrated, and says so". Every pass run at a rate other than the installed one will report
    "the panel's 96 kHz remains uncalibrated", even when the same pass has just calibrated 96 kHz.
    The rule predates the 2026-11-08 ruling that a scene may capture at any calibrated rate.
  - Goes to: audio-vue (the handoff), not this change's requirements.
  - Resolution: the maintainer ruled yes (2026-11-08). Handoff 1.1 asks audio-vue to say the
    installed rate is uncalibrated only where no valid record holds at it.
- **F9. The Mac's output is left at the last rate** (resolved, Q2)
  - Plan: D7 leaves the output at 192 kHz after a pass.
  - Code: a single run already leaves it at its rate. Restoring costs one more `cal-play rate` and
    12 s of settling.
  - Goes to: design.
  - Resolution: the maintainer ruled to leave it (2026-11-08), as D7 says.

- **F10. The runs list gives no rate** (resolved, host ask)
  - Plan: each run shows the rate it captured at.
  - Code: `GET /v1/runs`'s `RunEntry` has no rate. The record holds one, and `runs.listing` already
    reads each record's JSON.
  - Goes to: task.
  - Resolution: handoff 1.1 asks for `rate` on each run. Task 3.6 reads it once the contract has
    it, and until then a run's rate shows `—`, as the `calibration-history` delta says.
- **F11. Two kHz formatters** (resolved)
  - Plan: the runs, the Input section and the pass all word rates.
  - Code: `PanelRows.rate(_:)` already words a rate, privately.
  - Goes to: design and task.
  - Resolution: D9 and task 3.5 lift it to `RateText.text(_:)`.
- **F12. The rename's references** (resolved)
  - Plan: Calibration becomes Capture, and Input goes.
  - Code: `PanelSection.calibration` and `.input`, `PanelWindow`'s two switches,
    `CalibrationPage`, `CalibrationForm` and its previews, `SketchInputPage`, `SketchChainWarning`,
    and `project-map.md`.
  - Goes to: task.
  - Resolution: task 4.3 covers the code, and 7.2 the KB. The `calibration-history` Purpose names
    the Calibration page, and a delta cannot change a Purpose, so the workflow follow-up updates it
    at archive.

## Questions for the maintainer

- **Q1 (F8).** Should the handoff also ask audio-vue to reword its other-rate report line?
  **Answered** (maintainer, 2026-11-08): yes.
- **Q2 (F9).** After a pass, should the Mac's output go back to the rate it had before?
  **Answered** (maintainer, 2026-11-08): no, leave it at the last rate.
- **Pass 2.** Should the runs section keep the name "Runs" now that the page is Capture?
  **Answered** (maintainer, 2026-11-08): call it Calibration History. Should Input stay in the
  sidebar? **Answered** (maintainer, 2026-11-08): no. Capture holds the input.

## Confirmed

- An arm stating `file_rate` makes the panel capture at that rate and return to the installed rate
  after (`scene.py` `_arm`; `calibration-stimulus`). A pass needs no install write.
- `calibration.RATES` is `(44_100, 48_000, 88_200, 96_000, 192_000)`, the maintainer's list, and
  `check_stated` refuses any other `file_rate`. The helper refuses the same before writing.
- The arm already sends `file_rate` from `StatedRun.rate`, and the stimulus renders at it, so a
  pass needs only a different `StatedRun` per rate.
- `install.input.device` unset means the default device. `rate` is a chain setting with default
  48 000. Both are in the `input` block, alongside `fmt`, `stream_channels` and `pair`, which a
  write must keep.
- `GET /v1/install` gives each block's `rev`, and 0 with an empty doc for one never written.
- `PUT /v1/install/{block}` answers `calibration` and `chain_changed` on a chain change.
- `GET /v1/host/devices` lists ALSA names, with a reason when empty.
- An arm during the hold is accepted and starts a new run (`control-commands`, "Back-to-back runs").
- `HostFailure.stale(currentRev:)` and `.conflict(String)` exist. No new failure case is needed.
- `SketchChainWarning` is used only by `SketchInputPage`. Both go in 4.3.
- No other open change of ours modifies `calibration-run`, `calibration-history` or
  `panel-window`.
- Every record carries its rate (`record.py`), so audio-vue can list it without a new measurement.
