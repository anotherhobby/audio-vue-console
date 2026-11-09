# Proposal

## Why

The user cannot choose which capture device the panel listens to, or the rate it captures at,
without editing the host by hand. A calibration record applies only to the device and rate it was
measured at, and a scene may capture at any rate the host is calibrated at (maintainer,
2026-11-08). So a user who switches rates has to calibrate each one, one run at a time, from the
console, and cannot tell from the list of past runs which rates they covered. A single pass that
calibrates every rate leaves the host with a record for each rate.

## What Changes

- **The Calibration page becomes Capture** (maintainer, 2026-11-08). It holds everything about what
  the panel captures: the input, the calibration in force, Calibrate… and the past runs. Input
  leaves the sidebar, and its sketch goes. The sidebar becomes Panel, Scenes, Capture, Display and
  History.
- **The Capture page picks the panel's capture device and rate**, in an Input section at the top.
  It reads and writes the host's `input` install block:
  - `device` is chosen from the host's capture devices (`GET /v1/host/devices`) or the default
    device.
  - `rate` is chosen from the rates the host's schema declares for it.
  - A write keeps the block's other keys and is made on the block's revision.
  - A write asks first, unless the panel is down, since a chain change restarts it. The host's
    words on what the change does to calibration are shown afterwards.
- **Each rate says whether it holds a calibration** for the installed device. This uses the
  per-rate calibration read that `scene-settings` already asks audio-vue for.
- **Each past run shows the rate it captured at.** The runs section is renamed Calibration
  History (maintainer, 2026-11-08). Records hold their rate, but the host's runs list does not give
  it, so the handoff asks for it.
- **The rate list comes from the host** (maintainer, 2026-11-08). audio-vue declares
  `install.input.rate`'s choices as calibration's rates (44.1, 48, 88.2, 96 and 192 kHz). The Input
  section offers them, and an every-rate pass runs them. The handoff asks for this too.
- **Calibrate… can calibrate at every rate in one pass**, for a calibration only. It runs one
  calibration per rate, lowest first: render the file, set the output's rate and settle, arm
  stating that rate, play, follow the run to its end, then move to the next rate. The panel
  captures at each arm's stated rate and returns to its installed rate afterwards, so the install
  settings are never written. The host keeps one record per rate.
- **A pass goes on past a failed rate** (maintainer, 2026-11-08). A rate that fails, expires or is
  refused is recorded, and the pass moves to the next rate. A rate this Mac's output cannot play is
  skipped before anything plays, and Calibrate… names it beforehand. Cancel ends the whole pass.
- **A pass shows where it is and ends with a summary.** It shows which rate it is on out of how
  many, alongside the usual step. At the end it lists each rate's outcome with its report, and
  opens none of them by itself.

Out of scope: characterization at every rate (maintainer, 2026-11-08); the input's channel pair,
sample format and stream channels; and which rates the panel's capture device supports.

## Capabilities

### New Capabilities

- `capture-input`: the Capture page's Input section. It reads the panel's capture device and rate
  from the host's install settings and writes them back, and shows each rate's calibration.
- `calibration-pass`: a calibration at every rate in one pass. It covers which rates the pass runs
  and in what order, skipping the rates the output cannot play, going on past a failed rate, and
  the pass's progress, cancel and summary.

### Modified Capabilities

- `calibration-run`:
  - "Calibrate is offered only where a run can work" names the Capture page.
  - "The file and the arm state the same run" lets a pass state each rate it runs, in place of the
    installed one.
  - "A run's ending says what became of it" leaves a pass's runs to open no report by themselves.
- `calibration-history`:
  - "The page shows the calibration in force" names the Capture page.
  - "The page lists the host's runs" lists them under Calibration History, each with its rate.
- `panel-window`: "The sidebar has no Access page" lists Capture in place of Input and
  Calibration, and holds Capture to its own requirements.

## Impact

- **Code:**
  - `ConsoleCore` gains the capture devices read, the install block write and the runs list's rate
    (`HostClient`, `RunEntry`).
  - It also gains an input model holding the installed device and rate with the block's revision,
    the schema's rate choices, and a pass that drives `CalibrationSession` once per rate.
  - It reads each output device's available nominal rates from Core Audio (`OutputDevices`).
  - In the app target, `CalibrationPage` becomes `CapturePage` with an Input section. The sidebar's
    `.calibration` becomes `.capture`, `.input` and `SketchInputPage` go, and `RunRow` shows the
    rate. `CalibrateSheet` and `RunProgress` gain the pass choice, its progress and its summary.
- **Sequencing:** three parts wait on audio-vue.
  - The per-rate calibration mark waits on its answer to `scene-settings-handoff.md`.
  - The rate list and the runs' rates wait on its answer to this change's handoff.
  - Everything else can be built now.
- **Host:** one new ask, `input-and-rates-handoff.md` in audio-vue's root. It asks audio-vue to
  declare the rates `install.input.rate` takes, as calibration's `RATES`, in `/v1/schema`, and to
  give each run's capture rate in `GET /v1/runs`.
- **Referenced specs relied on:**
  - `audio-vue:calibration-stimulus`: a calibration captures at its stated rate and returns to the
    installed rate after; the helper refuses a rate an arm would.
  - `audio-vue:control-commands`: an arm is refused while one listens or a run is under way;
    arming never cancels; back-to-back runs during the hold.
  - `audio-vue:control-api`: calibration's order; install writes on a revision; runs served from
    their files.
  - `audio-vue:settings-schema`: the input block's chain class and declared defaults.
  - `audio-vue:settings-store`: an install block stored on its revision; a chain write restarts a
    running panel and is refused during a calibration.
  - `audio-vue:calibration-record`: a record applies at its own rate and carries it; the newest
    valid record for device and rate is in force.
  - `audio-vue:calibration-lifecycle`: settling after a rate change; one kind per arm; the hold
    after a run.
