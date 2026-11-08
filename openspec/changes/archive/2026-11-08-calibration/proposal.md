# Proposal

## Why

Calibrating still means `make calibrate` in an audio-vue checkout: `cal-play` sets the output's rate,
ssh arms the panel, `cal-play` plays a WAV made by `tools/calibrate.py --write`. Reading what a run
found means `make cal-fetch` and opening an HTML file. The product's ruled end game is "open the app, hit calibrate" (`product.md`,
"Calibration"), and calibration is the reason the console is native rather than a web page. The
Calibration page in the sidebar is still a sketch on sample values.

## What Changes

- **Calibrate… runs a calibration from the app** (maintainer, 2026-11-08). On the Calibration page,
  Calibrate… asks for the output device feeding the panel and the kind of run, then: renders the
  stimulus file, sets the device to its rate and lets the chain settle, arms the panel, and plays
  the file once the arm is done. This is `make calibrate`'s order
  (set the rate, wait, then arm), so a settle never spends the arm's deadline.
- **Calibration, or Calibration + Characterization** (maintainer, 2026-11-08). A run is a
  calibration (the default) or a characterization, which runs the calibration too and is named so.
  A run states nothing it cannot measure: no maximum input level or folding frequency (maintainer,
  2026-11-08, replacing the same day's Advanced section). The file played and the arm always state
  the same kind and rate.
- **The app renders the stimulus** (maintainer, 2026-11-08, replacing the same day's ruling that
  the host serves it). The render bundle the app carries already holds audio-vue's writer
  (`calibration.make_schedule` and `write_wav`), and the card-code check already proves it is the
  panel's code, so the file is the one the panel listens for, with no 220 MB download and no render
  on the Pi. Calibrate… is offered only while the app's code digest is the panel's. The file is
  rendered at the panel's installed capture rate, read from the install settings the app already
  reads, so a scene capturing at another rate never changes what is calibrated. A rendered file is
  removed when its run ends.
- **The app says it must be the machine feeding the panel.** The page says that calibration plays
  from this Mac and works only from the machine whose output feeds the panel. The output device chosen
  is remembered for each panel.
- **A run is followed to its end.** While a run is under way the page shows where it is (rendering,
  settling, armed, playing, analysing) from the app's own steps and the panel's live calibration
  state, with Cancel at every step. Cancel stops playback and cancels the panel's run. A refused arm,
  an expired arm, a failed run and a player that stops each say why. The panel's state names the run
  that ended and how (maintainer, 2026-11-08): a completed run opens its report and says where it is
  not in force, and a failed run says why.
- **Past runs and their reports** (maintainer, 2026-11-08). The Calibration page shows the
  calibration in force (status, age, trim, noise floor), then the host's runs, newest first, each
  with its kind. Opening a run shows its HTML report in the app, as the host wrote it, reaching
  nothing on the network. A run with no report says so.
- **A run's audio stays on the host** (maintainer, 2026-11-08). The app saves no run's audio:
  audio-vue's ruling that no run's audio is served stands. Where a run's audio is needed, `make
  cal-fetch-audio` fetches it from the host.
- **`cal-play` is bundled.** The app carries audio-vue's `cal-play`, built from the checkout when
  the app is built, and runs it as a child process to set the rate and to play. The app does not
  reimplement playback: `cal-play`'s float32 path was measured bit-perfect, and it matches the
  device's rate before it plays.

## Capabilities

### New Capabilities

- `calibration-player`: The bundled `cal-play`: how it is built from audio-vue and carried in the
  app, how the app runs it as a child to set a device's rate and to play a file, how its failures are
  read, and how it is stopped.
- `calibration-run`: Running a calibration from the app: the output device, the kind and stated
  values, the stimulus rendered from the bundled code, the order of rate, settle, arm and play,
  following the run through the panel's state, Cancel, and what each failure says.
- `calibration-history`: The calibration in force and the host's runs on the Calibration page: the
  list, and a run's HTML report shown in the app.

### Modified Capabilities

- `panel-window`: "The sidebar has no Access page" holds the Calibration page to requirements,
  leaving Input, Display and History on sample values.

## Impact

- **Code:** In `ConsoleCore`, a `HostClient+Calibration` gains the runs list and a run's report,
  and `HostClient+Commands` the arm and cancel commands. `RenderHelper` gains the `stimulus` request.
  A `CalibrationPlayer` runs `cal-play` as `HelperProcess` runs the render helper. A
  `CalibrationSession` drives one run's steps and reads the live state's calibration lifecycle. In the app target, a Calibration page
  replaces `SketchCalibrationPage`, with a Calibrate sheet, a run's progress, a runs list, a report
  view on `WKWebView`. `PanelWindow` routes `.calibration` to the new page. A build phase builds and
  embeds `cal-play`.
- **Host and audio-vue:** asked by `calibration-handoff.md` and `calibration-handoff-2.md`, and
  planned in audio-vue's change `calibration-from-the-app` (answered 2026-11-08, not built; a name may
  still move in its build, which its final reply would say):
  - the render helper's `stimulus` request (`kind`, `rate`, `path`; the console sends none of its
    optional `maximum_input_db` and `internal_folding_hz`), answering `ok` once the file is whole, `refused` with
    `calibration.check_stated`'s message, or `error`;
  - `install.input.rate` declaring a default of 48,000 Hz;
  - `state.sections.calibration.lifecycle` declared as an enum, and `.ended` naming the calibration
    that last ended (`arm`, `outcome`, `kind`, `run_id`, `applicable`, `reason`) until the next arm
    lands;
  - an arm's done answer giving the arm's id (`ArmOutcome.arm`), and a cancel's `record_stands`
    (`CancelOutcome`);
  - `RunEntry` gaining `kind` and `applicable` ("fit to apply when written");
  - every `failed` run having no record: a run whose record was saved ends `done` even if its
    report fails.

  Running a calibration and showing kinds wait on that change, deployed, with the bundle and the
  contract refreshed. The runs list and reports use routes already in the saved contract, so they
  can be built first.
- **Sequencing:** `scene-save` (archived 2026-11-08) left the quit and panel-switch prompts this
  change extends. `gallery-sections` touches only `scene-apply` and `scene-gallery`. Since
  `track-audio-vue` (archived 2026-11-08), `host-connection` refuses a host at any version but the
  saved contract's, so each contract refresh here needs audio-vue deployed to the panel.
- **Referenced specs:** `audio-vue:control-api` (runs are listed newest first and served with the
  panel down, by id and never by path; a run with no report says so; no run's audio is served; the contract states the
  calibration's order; a command's `Outcome` of done, refused, expired, unknown or no panel),
  `audio-vue:control-commands` (an arm carries what the operator states and never cancels; an arm that
  hears nothing expires; what an arm states is checked before anything changes; a cancel works at any
  moment and writes no record), `audio-vue:calibration-lifecycle` (an arm is for one kind of run;
  the chain settles after a rate change before the arm; a run with a stimulus missing is kept and
  never applied), `audio-vue:control-state`
  (the calibration section says which record is applied, its age, trim and noise floor, and why none
  applies), `audio-vue:calibration-stimulus` (two runs, each with its own file; a calibration captures at the
  rate its file is played at, by default the installed capture rate; the arm states the file's
  rate), `audio-vue:render-bundle` (the bundle holds what the helper needs, its digest the panel's),
  `audio-vue:settings-schema` (every setting declared once, with its default).
