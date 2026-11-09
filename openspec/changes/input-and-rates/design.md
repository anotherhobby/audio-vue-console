# Design

## Context

See `proposal.md` for why. As read on 2026-11-08:

- **A stated rate captures at that rate.** When an arm states `file_rate`, the panel rebuilds the
  calibration scene at that rate and restores the installed rate after the run (audio-vue
  `src/scene.py`, `_arm`, design D9 there; `calibration-stimulus`, "A calibration captures at the
  rate it calibrates"). An every-rate pass therefore needs no install writes.
- **The hold.** After a completed run the panel keeps the calibration scene, at that run's rate,
  until audio returns above the floor. An arm during the hold starts a new run and rebuilds the
  scene at the newly stated rate (audio-vue `calibration-lifecycle`, "A finished run holds the
  screen until audio returns" and "The calibrate action during the hold arms a new run";
  `control-commands`, "Back-to-back runs"). So a pass arms rate after rate with no switch back
  between them, and the installed rate returns when the hold after the last run ends.
- **Calibration's rates** are `calibration.RATES`, `(44_100, 48_000, 88_200, 96_000, 192_000)`. Only
  `check_stated`'s refusal text exposes them. `install.input.rate` is declared as an `int` with
  `min=1` and default 48 000 (`src/schema/install.py`), with no choices.
- **The install read.** `HostClient.install` (`GET /v1/install`) maps each block's `doc` by name and
  drops each `InstallBlock`'s `rev`. Its callers are `CalibrationRuns.load` and `PanelScenes`.
  `CalibrationRuns.rate(install:schema:)` derives the installed rate. Nothing writes install
  settings yet. `PUT /v1/install/{block}` takes `Edit {doc, base_rev}`, where `base_rev` is 0 for a
  block never written. It answers `InstallWritten` (`applies`, `chain_changed`, `calibration`: what
  a chain change does to calibration), 409 `Stale`, 422 `Invalid`, or 404. The host restarts the
  panel on a chain change whenever its condition is not `down` (audio-vue
  `control_service/settings.py`, `put_install`). During a calibration it refuses with 409
  `{"detail": "a calibration has the panel -- cancel it first"}`, which carries no `current_rev`.
  The contract declares 409 only as `Stale`, so the generated client cannot decode that answer.
- **Capture devices.** `GET /v1/host/devices` gives `Devices {devices: [String], reason?}`, the
  devices as ALSA names. The client has no call for it yet.
- **A run.** `CalibrationSession.start(_:device:host:)` returns whether it started. It drives
  render, settle, arm and play, takes its ending from `observe(_ state:)`, and publishes `step` and
  `ending`. `CalibrationPage` opens the report on a completed ending. `StatedRun.rate` is
  documented as the installed rate. The app delegate holds the one session
  (`AudioVueConsoleApp.calibration(using:)`). `applicationShouldTerminate`, `PanelWindow`'s
  switch of panel (`RunUnderWay.settle`), `CalibrateSection` and `CalibrationReadiness` all ask
  `session.isUnderWay`, and `PanelWindow` forwards each live state to `session.observe`.
- **Output devices.** `CoreAudioOutputDevices.list()` reads names and UIDs from Core Audio. The app
  reads no device's rates; `cal-play rate <name>` prints them, but as text for a person to read.
- **The sidebar.** `PanelSection` in `AudioVueConsole/PanelWindow.swift` is `panel, scenes, input,
  calibration, display, history`. `.input` shows `SketchInputPage`
  (`AudioVueConsole/Sketches/SketchPages.swift`), and `.calibration` shows `CalibrationPage`, whose
  sections are the calibration in force, Calibrate… and "Runs" (`CalibrationForm`).
- **The runs list.** `GET /v1/runs` gives `run_id`, `has_report`, `kind` and `applicable`, and no
  rate. audio-vue's `runs.listing` reads `kind` and `applicable` from each record's JSON, and the
  record also holds the run's rate (`record.py`, the record's `rate` and `conditions`'
  `capture_rate_hz`). `RunEntry` (`HostClient+Calibration.swift`) holds `id`, `hasReport` and
  `kind`, and `RunRow` shows the title, the kind and the report.

## Goals / Non-Goals

**Goals:**

- One source for the rate list, the host's schema, shared by the Input section and the pass.
- The pass as a thin driver over `CalibrationSession`, so a pass's rate behaves as a run does with
  no second copy of the run's steps.
- Pure, tested functions for the write's document, the pass's rate plan and its summary.

**Non-Goals:**

- The input's `pair`, `fmt` and `stream_channels`. The Input section leaves room for them, and a
  write keeps them as the block holds them.
- Probing which rates the panel's capture device supports. A rate it cannot open shows up as that
  rate's failed or expired ending.

## Decisions

### D1. The rates are read from the schema's `install.input.rate`

`SchemaFacts.inputRates(_ schema:) -> [Int]?` reads the choices audio-vue declares on
`$defs["install.input"].properties.rate`, sorted ascending. The handoff asks for an `enum`; the
reader follows whatever form audio-vue answers with. It returns `nil` where the schema declares
none. The Input section then offers the installed rate alone, and the every-rate option is disabled,
saying the host declares no rates.

Why: `.claude/CLAUDE.md`, "Host Versions", and the maintainer's ruling. Alternative: carry `RATES`
in the app. It can be built today, but it drifts silently from audio-vue's calibration.

### D2. `PanelInput` holds the `input` block with its revision

A new `@Observable @MainActor` model, `PanelInput`, built like `CalibrationRuns` from the
connection. It loads the `input` block's doc and `rev` from `HostClient.installBlocks`, new, which
returns each block's doc with its revision. `install` keeps its signature, built on top of
`installBlocks`, so `CalibrationRuns` and `PanelScenes` do not change. It also loads the schema and
the devices (`HostClient.captureDevices`, new). It exposes `device: String?`, `rate: Int`, `devices`,
`devicesReason`, `rates` and a `note` for the host's words.

`InputEdit.doc(block:device:rate:) -> [String: JSONValue]` is pure. It copies the block, sets or
removes `device` (the default device removes the key, since unset means default), and sets `rate`.
`PanelInput.write(device:rate:)` sends it with `base_rev` through `HostClient.writeInstall(_:block:
base:)`, new, which returns `InstallWritten` or throws a `HostFailure`. It maps failures as
`writeScene` does: 409 `Stale` to the existing `HostFailure.stale(currentRev:)`, and 422 to
`.invalid`. The calibration refusal's 409 cannot be decoded until the contract declares it (task
1.1 asks), so until then it arrives as `.unexpectedAnswer`. The page then reloads and says the host
refused the change. Once the contract declares it, the refusal maps to `.conflict` with the host's
words. On `stale` the model reloads and sets a note saying the values changed elsewhere.

The Input section asks before writing (an alert with Restart Panel and Cancel) unless the live state says
the panel is `.down`. The host restarts the panel in every other condition, and a panel whose state
is unknown is asked about. It disables both pickers while the app's calibration is under way (D4)
or the live calibration lifecycle is not `.off`, so the refusal is seldom reached.

### D3. The per-rate calibration mark is optional until audio-vue answers

`scene-settings-handoff.md` asks for a read of each rate's valid calibration for the installed
device. Until the saved contract has that route, `PanelInput.calibrations` stays `nil` and the
section shows no marks, as the spec allows. When the route lands, the tasks add one `HostClient`
call, and `scene-settings` and this section share it.

Why: the rest of the section and the whole pass can be built and run now. Alternative: wait for the
reply. That blocks the parts that do not need it.

### D4. `CalibrationSession` gains an awaited run

`CalibrationSession.run(_ stated:, device:, host:) async -> Ending` starts a run as `start` does and
returns when it finishes. `start` becomes a wrapper that launches `run` in a task. The session
still owns render, settle, arm, play, cancel and the file's removal, unchanged.

`CalibrationPass` (ConsoleCore, `@Observable @MainActor`) wraps the session and becomes the app's
one calibration. A single run is a pass of one rate: the installed rate, of either kind. The app
delegate holds the pass in place of the session. The quit prompt, the switch-of-panel prompt
(`RunUnderWay`), `CalibrateSection`, `CalibrationReadiness` and the Input section ask
`pass.isUnderWay`, which is true from Start until the last rate ends, the gaps between rates
included. `PanelWindow` forwards live states to `pass.observe`, which keeps the latest and passes
it to the session.

`pass.start(kind:rates:device:host:)` calls `session.run` once per rate, in order. Before each rate
after the first, it stops, leaving the rest "not run", where the latest state is not `.up`, the
live state is not live (`LiveState.isLive`, which `PanelWindow` forwards beside each state), or the
previous ending was `.hostFailed(.tokenRefused)`. Those are the spec's "the panel
going down" and "a lost pairing". `cancel()` sets a flag and calls `session.cancel()`. The pass
publishes `current: (rate, index, count)?`, `outcomes: [RateOutcome]` and `isMultiRate`.

Why: one run implementation, so cancel, the steps and the endings are the run's own. With one
owner, a quit between two rates is still asked about. Alternatives: a pass-aware session with a
rate queue inside, which mixes two lifetimes in one type. Or a pass beside the session, which
leaves every `isUnderWay` caller to check both and misses the gap between rates.

### D5. The plan is computed before Start

`PassPlan.make(hostRates:outputRates:) -> PassPlan` is pure. It returns `runs`, the host's rates the
output offers, ascending, and `skipped`, the rest. Calibrate… shows `skipped` and disables Start
when `runs` is empty. `RateOutcome` is `.ended(Ending)`, `.skipped` or `.notRun`, listed in the
host's rate order. The app words each outcome, an ended rate with the existing `EndingText`
(`AudioVueConsole/Calibration/RunProgress.swift`, which depends on the app's `ReadFailureText`).

### D6. Output rates come from Core Audio, not `cal-play`

`OutputDevice` gains `availableRates: [ClosedRange<Double>]`, read with
`kAudioDevicePropertyAvailableNominalSampleRates`. `OutputDevice.offers(_ hz: Int) -> Bool` checks
whether any range holds `hz` within 0.5 Hz. Reading is not setting: `cal-play` still sets and
verifies every rate (`calibration-player`).

Why: `cal-play rate <name>` prints for a person to read. Parsing that text ties the app to its
wording. Core Audio is the same source `cal-play` reads from (`describe_rates` over
`available_hz`). Alternative: run `cal-play rate` per device. It is slower and more fragile, and
gives no more information.

### D7. The output is left at the last rate played (maintainer, 2026-11-08)

After a pass, the Mac's output stays at the last rate `cal-play` set, as a single run leaves it.
Restoring the earlier rate would cost another 12 s settle and a fourth player state to cancel, for
no gain to the panel.

### D8. A pass's report is opened from its summary

`CapturePage` opens the report on a completed ending only where `isMultiRate` is false, and shows
`EndingRow` for it as now. For a multi-rate pass it shows the summary list: each rate's outcome,
and an Open Report button where the host lists that run with a report. The runs list is read after each rate ends, as the spec for runs asks, so each new run
appears as the pass goes.

### D9. Capture is the Calibration page renamed, with Input on it

`PanelSection.calibration` becomes `.capture`, titled Capture, and `.input` is removed, with
`SketchInputPage` and `SketchChainWarning`. `CalibrationPage` is renamed `CapturePage`, and
`CalibrationForm` `CaptureForm`. Its sections are Input, the calibration in force, Calibrate…, and
Calibration History (renamed from "Runs"). The folder `AudioVueConsole/Calibration/` keeps its
name, since its other views are about calibration. `InputSection` takes a `PanelInput` and the
pass's `isUnderWay`, and has its own previews. The sidebar symbol stays `tuningfork`.

`RunEntry` gains `rate: Int?`, read from the runs list's `rate` once the contract has it, and `nil`
until then. `RunRow` shows it as `44.1 kHz` or `96 kHz`, or as `—`. The words come from
`PanelRows.rate(_:)`, which is private today. It is lifted to a public `RateText.text(_:)` in
ConsoleCore, so the Panel page, the runs, the Input section and the pass all word a rate one way.

Why: the user picks the input where they calibrate it, and the page's name covers both (maintainer,
2026-11-08). Alternative: keep the Input sidebar item as a sketch for the channel pair and format.
That leaves two places for one block's settings.

## Risks / Trade-offs

- [A capture device that cannot open a rate makes that rate expire after the arm's deadline, and a
  pass can spend several deadlines this way] → The pass goes on as ruled, and the summary names
  each expired rate. Probing the device's rates is left for later.
- [A pass of five calibrations is long, and a Mac that sleeps would cut playback partway] → No run
  takes an activity assertion today. `CalibrationPass` holds
  `ProcessInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled])` from Start to
  its summary. Single runs are left as they are, since a single run has not been cut off.
- [The handoff's answer may shape `input.rate`'s declared choices differently from an `enum`] → D1
  keeps the reader in one function, so the change is local.
- [A stale write after the user picked a value loses their pick] → The note says the values changed
  elsewhere, and the user picks again with the current values on screen.
