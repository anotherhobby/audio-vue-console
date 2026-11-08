# Tasks

Groups 1 to 5 build on routes already in the saved contract. Group 6 waits on audio-vue's change
`calibration-from-the-app` (planned 2026-11-08 and still being built: the helper's `stimulus`
request, the rate's schema default, the lifecycle enum, `calibration.ended`, `ArmOutcome`,
`CancelOutcome`, and `kind` and `applicable` in the listing), brought in by `tools/refresh-contract.sh` and the build's bundle refresh once audio-vue
has built it, and needing audio-vue deployed to the panel, since the app refuses a host at any
version but the saved contract's (`host-connection`) and draws nothing from code that differs. Names
are taken from audio-vue's plan; 6.1 checks them against what was built.

## 1. cal-play in the app

- [x] 1.1 Add `tools/embed-cal-play.sh` (design D1): build `${AUDIO_VUE:-$SRCROOT/../audio-vue}/cal-play`
  with `${CARGO:-$HOME/.cargo/bin/cargo} build --release --target-dir "$SRCROOT/local/cal-play-target"`,
  then copy the binary to `$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/Helpers/cal-play`. Missing
  checkout or `cargo` prints `error:` with the fix and exits 1. Add the phase "Build and embed
  cal-play" to `AudioVueConsole.xcodeproj/project.xcproj` as a `"kind": "script"` object run on
  every build, so cargo decides what changed (Xcode's own last save of the file dropped phase
  `"id"`s, and the project loads without one). Verify a build (`mcp__xcode__BuildProject`) leaves an executable
  `Contents/Helpers/cal-play` whose `codesign -dv` names the app's signature, and that renaming
  `~/.cargo/bin/cargo` for one build fails it with the message.
- [x] 1.2 Measure `cal-play` inside the sandbox before building on it (design, Risks): from the
  sandboxed app, a throwaway debug button runs `Helpers/cal-play rate <device> 96000` and
  `rate <device> 48000`, then `play <device> <file>` on a stimulus copied into the container's temporary directory,
  on the proving rig (the D10s). Verify the device's rate changes both ways and the file plays; record
  the result in `.claude/kb/agent/pitfalls.md` and remove the button. If CoreAudio refuses inside the
  sandbox, stop and raise it with the maintainer.
- [x] 1.3 Add `CalibrationPlayer.swift` in `ConsoleCore` (design D1): a `PlayerLauncher` protocol
  launching `cal-play` with arguments and returning a `RunningPlayer` (`wait() async -> PlayerExit`
  with status and standard error, `stop()`), a `ProcessPlayerLauncher` over `Process` given the
  binary's URL, and `CalibrationPlayer` with `setRate(device:hz:)` and `play(device:file:)`, refusing
  a call while one runs, throwing `PlayerFailure.failed(reason)` with the trimmed standard error on a
  non-zero exit, and stopping the child when its task is cancelled. Verify `CalibrationPlayerTests`
  with a scripted launcher: arguments `rate D10s 96000` and `play D10s <path>`; exit 1 with
  `no output device matches "x"` gives that reason; a second call while one runs is refused;
  cancelling a play stops the child.
- [x] 1.4 Terminate a running player when the app quits, in `AppDelegate`
  (`AudioVueConsole/AudioVueConsoleApp.swift`), as the render helper is ended. Verify by running the
  app, starting a play from 1.2's measurement (before removing the button), and quitting: playback
  stops.
- [x] 1.5 Record `tools/embed-cal-play.sh`, its Rust requirement and `CARGO` in
  `.claude/kb/agent/commands.md`, and the `Helpers/cal-play` location in `project-map.md`. Verify
  the command runs as written.

## 2. The calibration in force and the runs list

- [x] 2.1 Keep the whole calibration section in `PanelState` (`ConsoleCore/.../PanelState.swift`,
  design D7): add `calibrationRunID`, `calibrationTrimDB`, `calibrationNoiseFloorDBFS` and
  `calibrationLifecycle`. Verify `PanelStateTests` reads each from a state fixture and leaves each nil
  where the section is null or absent.
- [x] 2.2 Add `HostClient+Calibration.swift`: `runs(at:token:) -> [RunEntry]` (`GET /v1/runs`) and
  `report(_ runID:at:token:) -> String` (`GET /v1/runs/{id}/report`), mapping 404 to `.notFound` and
  401 to `.tokenRefused` as the other calls do. `RunEntry` holds `id` and `hasReport`, and parses
  `date: Date?` from an id `yyyy-MM-dd'T'HH-mm-ss'Z'` in UTC. Verify `HostClientCalibrationTests`
  over `FakeTransport`: the list in the host's order, the Bearer token and no `Origin`, a report's
  HTML, a 404; and that `2026-10-25T23-16-08Z` parses to that UTC instant and `manual-1` to nil.
- [x] 2.3 Add `CalibrationRows.swift` in `ConsoleCore`, as `PanelRows` decides the Panel page's
  text: status, run, age, trim (`+0.01 dB`), noise floor, and why none applies, `—` for any value not
  read. Verify `CalibrationRowsTests`: a calibrated fixture's text, and every value `—` with the panel
  down.
- [x] 2.4 Add `CalibrationRuns` (`@MainActor @Observable`, `ConsoleCore`) holding the listed runs,
  read on `load()`, with a failure kept for the page. Verify `CalibrationRunsTests`: a load lists the
  runs newest first; a failed load keeps the earlier list and the failure.
- [x] 2.5 Add `AudioVueConsole/Calibration/CalibrationPage.swift`: a grouped form with the
  calibration in force from `CalibrationRows`, the note that calibration plays from this Mac and works
  only from the machine feeding the panel, a disabled Calibrate… (enabled by group 7), and the runs
  list, each row its date in the Mac's time zone or its id, and a report mark. Route `.calibration`
  to it in `PanelWindow.swift`, remove `SketchCalibrationPage` from `Sketches/SketchPages.swift`, and
  load the runs when the page opens. Verify by running the app against the proving host: the page
  lists the host's runs newest first and shows its calibration as the Panel page's Calibration
  section does, and with the panel stopped (`/v1/panel/stop`) still lists them with `—` above. Remove
  `calibratedDaysAgo` from `SketchPanel` (`Sketches/SketchData.swift`) and `sketch.json`, which only
  the removed page read.

## 3. A run's report in the app

- [x] 3.1 Add `AudioVueConsole/Calibration/ReportView.swift` (design D5): an `NSViewRepresentable`
  `WKWebView` loading the fetched HTML with `loadHTMLString(_:baseURL: nil)`, a `WKContentRuleList`
  blocking every load, and a `WKNavigationDelegate` that allows the first load and cancels every other navigation. Opening a run
  with a report fetches it through `CalibrationRuns.report(_:)` and shows it; a run without one shows
  that it has no report and fetches nothing. Verify by running the app: a report opens and scrolls
  with its inline charts drawn; the boundary tests (`--filter BoundaryTests`) still pass.

## 4. The output device

- [x] 4.1 Add `OutputDevices.swift` in `ConsoleCore` (design D2): a protocol listing output devices
  as `OutputDevice` (`uid`, `name`), and `CoreAudioOutputDevices` reading
  `kAudioHardwarePropertyDevices` and keeping those with output streams. Verify
  `PlaybackDeviceMemoryTests.thisMacListsAnOutputDevice` lists at least one device with a non-empty UID and name on the build machine,
  and a fake serves the tests below.
- [x] 4.2 Add `PlaybackDeviceMemory` (`ConsoleCore`): the device chosen per panel, by
  `HostConnection.host`'s `id`, stored as UID and name in the container beside the addresses, with
  `chosen(for:among:)` answering the remembered device only where its UID is among those listed.
  Verify `PlaybackDeviceMemoryTests`: remembered for one host and not another; a remembered UID not
  listed answers nil.

## 5. A run's steps

- [x] 5.1 Add `arm(_ stated: StatedRun, at:token:) -> ArmAnswer` (`POST /v1/commands/arm`, body
  `{"stated": {"kind", "file_rate"}}`) and
  `cancelCalibration(at:token:) -> CancelAnswer` (`POST /v1/commands/cancel`) to
  `HostClient+Commands.swift`, reading `ArmOutcome` (with `arm`, the arm's id, on a done answer) and
  `CancelOutcome` (with `record_stands`) as `switch` reads its result. `StatedRun` holds the kind
  and the rate, and states nothing else (maintainer, 2026-11-08). Verify
  `HostClientCalibrationCommandsTests` for the bodies sent for each kind and a 409 refusal's
  reason.
- [x] 5.2 Add `CalibrationSession` (`@MainActor @Observable`, `ConsoleCore`, design D3), held by
  `AudioVueConsoleApp` beside the renderer, driving render, the file's length from its WAV header
  (`WAVHeader`, frames and rate from the `fmt ` and `data` chunks), rate, arm and play behind a
  `StimulusSource` protocol (`file(for: StatedRun) async throws -> URL`, the run's rate in
  `StatedRun`),
  `CalibrationPlayer` and the client, with `step` and `ending` as D3 names them, and
  `observe(_ state: PanelState)` mapping the lifecycle word to the step: `waiting` to `armed`,
  `arming` and `running` to `measuring`, `analysing` to `analysing`, and no word to an ending. Verify
  `CalibrationSessionTests` with a scripted source, launcher, `FakeTransport` and states: the order
  render, rate, arm, play, with the device's rate and the arm's `file_rate` both 96 000 Hz;
  `WAVHeaderTests` reads 96 000 Hz and 12.2 s from a generated header; a refused arm (`still arming`)
  plays nothing and ends `refused` with the reason; a source refusing the stimulus ends
  `stimulusRefused` before the rate is set; the file is removed on every ending; `waiting`, `arming`, `running` show `armed`, `measuring`,
  `measuring`; `done` then `off`, or `waiting` then `off`, end nothing; a player exiting 1 ends
  `playerFailed` and sends cancel; a second `start` while one runs is refused.
- [x] 5.3 Cancel in `CalibrationSession` (design D3): before the arm it ends the step and sends
  nothing; after it, it stops the player and sends `cancel`, reading `record_stands` from the done
  answer. Verify
  `CalibrationSessionTests`: cancel while settling sends no arm; cancel while playing stops the child
  and sends one cancel, ending `cancelled`; a done answer with `record_stands` true ends `completed`;
  a refusal `too late -- the record is being written` shows its reason and keeps the run going.
  Any refusal, `nothing to cancel` included, is followed the same way, since the run's ending then
  arrives in the panel's ended calibration (`CalibrationSessionCancelTests`).

## 6. audio-vue's calibration change

- [x] 6.1 Run `tools/refresh-contract.sh` once audio-vue has built `calibration-from-the-app` and it is
  deployed to the panel, build the app so its bundle mirror is refreshed, and read both diffs.
  Verify the saved contract declares the lifecycle enum, `Calibration.ended` (`arm`, `outcome`,
  `kind`, `run_id`, `applicable`, `reason`), `RunEntry.kind` and `applicable`, `ArmOutcome.arm` and
  `CancelOutcome.record_stands`; `GET /v1/schema` gives `install.input.rate` `default: 48000`; the
  bundle's helper answers `hello` with `protocol: 2` and takes `stimulus`; any name that differs from
  this plan is carried into tasks 6.2 to 6.5 before they are built; `xcrun swift test` passes in
  `ConsoleCore/`; `PanelState.calibrationLifecycle` becomes the declared enum
  (`CalibrationLifecycle`). Done before group 5 (2026-11-08), since the panel was deployed at the
  new API mid-build; 5.1 and 5.3 read the declared fields from the start.
- [x] 6.2 Add `stimulus(_ run: StatedRun, to file: URL)` to `RenderHelper`
  (`ConsoleCore/.../RenderHelper.swift`, design D4), sending `{"op": "stimulus", "kind", "rate",
  "path"}` through `ask(_:)`, a `refused` answer thrown
  as `stimulusRefused` with its message and an `error` as a failure, and a `HelperStimulus` that is the `StimulusSource` the app uses,
  writing into a fresh file in the container's temporary directory. Verify `HelperStimulusTests` with
  `ScriptedLauncher`: the request sent for a characterization at 96 000 Hz; `refused`
  with `file_rate must be one of [...]` thrown with that message; an `error` thrown as a failure. Then, from the sandboxed app on this Mac, time a calibration and a characterization
  at 96 000 Hz and check the calibration's file is byte-identical to one `tools/calibrate.py --write`
  makes from the same checkout; record both times in design Context.
- [x] 6.3 Add the run's rate and the code gate (design D4): `CalibrationReadiness` in `ConsoleCore`,
  from the install and schema `CalibrationRuns.load()` reads (`install.input.rate`, else the
  schema's `default`; not `PanelScenes`, whose load also reads every scene and image), the
  renderer's `CardCodeVerdict`, the pairing and the panel's condition, answering ready with the
  rate or the reason Calibrate… is disabled. Verify `CalibrationReadinessTests`: a written rate of
  96 000 is the run's even with `capture.rate_hz` 48 000; an unwritten rate takes the schema's
  `default`, 48 000; a verdict other than
  `.same` is not ready, saying the app and the panel run different audio-vue code; the panel not
  `up` is not ready.
- [x] 6.4 End a run from `calibration.ended` (design D3): read it into `PanelState` as
  `EndedCalibration` (`arm`, `outcome`, `kind`, `runID`, `applicable`, `reason`), keep the arm's id
  from 5.1's `ArmOutcome.arm`, and in `CalibrationSession.observe` take an ending only where
  `ended.arm` is that id: `done` to `completed` with run id, `applicable` and `reason`; `failed` and
  `expired` with their `reason`; `cancelled` ends the run cancelled, whoever sent it. Built with 5.2
  (2026-11-08), the contract already carrying the field. Verify `CalibrationSessionTests`: a completed
  run ends `completed`; `applicable` false ends `completed` with the missing segment as its reason;
  a failed run ends `failed` with its reason and no run id; an expiry seen only as `waiting` then
  `off` ends `expired` from the field; an `ended` naming an earlier arm is ignored.
- [x] 6.5 Read `kind` into `RunEntry` and show it in the runs list
  (design D6). Verify `HostClientCalibrationTests` reads it, and the page shows each run's kind
  against the proving host.

## 7. Calibrate… in the app

- [x] 7.1 Add `AudioVueConsole/Calibration/CalibrateSheet.swift`: the output device from
  `OutputDevices`, chosen first from `PlaybackDeviceMemory`; Calibration or Calibration +
  Characterization (`RunKindText`, also the runs list's words); no Advanced section; above Start,
  `PlaybackWarning`'s two points in orange (maintainer, 2026-11-08). Enable Calibrate… on the page while `CalibrationReadiness` is ready and no run is
  under way, else disabled with its reason. Verified by the maintainer (2026-11-08): the sheet's
  choices and rate, and the device chosen again on reopening.
- [x] 7.2 Add `AudioVueConsole/Calibration/RunProgress.swift`: the session's step (rendering, settling, armed, playing with time left, measuring, analysing) with Cancel, and its
  ending's text: a completed run opens its report, says where it cannot apply, and where its report
  was not written says so with the panel's reason; a failed run says why and opens no report; a refused arm shows the host's reason, and a
  refused stimulus the helper's. Feed the session each live
  `PanelState` from `PanelWindow`, so a run is followed on any page. Verify on the proving rig: a calibration runs from Calibrate… to its
  report opening, and a run cancelled while playing stops the sound and the panel returns to its
  scene.
- [x] 7.3 Ask before quitting or switching panels while a run is under way, in `AppDelegate` and in
  the panel picker and Add Panel paths that already ask about unsaved scenes; going on cancels the run
  as Cancel does. Verify on the proving rig: quitting while playing asks, and on cancel the panel
  hears a cancel (its lifecycle leaves `waiting` or `running`) before the app quits.

## 8. Integration

- [x] 8.1 On the proving rig, run Calibration + Characterization from Calibrate…, and verify its
  report opens, it heads the runs list as Calibration + Characterization, and the record it names
  states the installed rate (done by the maintainer, 2026-11-08: run 2026-11-08T18-41-37Z). Then play into an arm with the output muted and verify
  the page says the panel heard no file.
- [x] 8.2 Update the agent KB: `host-contract.md` gains a Calibration section (the runs, report
  routes, that no run's audio is served, the helper's `stimulus` request, the arm's `stated` and refusals, the lifecycle words and that endings pass, the ended-run field,
  `record_stands`, as built), `project-map.md`
  the `Calibration/` folder and the `ConsoleCore` types, and `working-notes.md` drops this change's
  notes. Verify `.claude/kb/README.md` still points at each file.

## Workflow follow-up

- Delete `calibration-reply-handoff.md` and `calibration-reply-2-handoff.md` from this repo once
  read (audio-vue asks for it), and `../audio-vue/calibration-handoff.md` and
  `calibration-handoff-2.md` once audio-vue no longer needs them.
- When audio-vue's final reply on `calibration-from-the-app` arrives, carry any name that moved into
  this change before group 6.
- Archive the change once every group is built and verified.
