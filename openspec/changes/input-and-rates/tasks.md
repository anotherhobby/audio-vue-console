# Tasks

Run the core suite with `cd ConsoleCore && xcrun swift test --disable-xctest` (`commands.md`). Four
tasks wait on audio-vue. The rate list (2.2), the calibration refusal's words (3.4) and the runs'
rates (3.6) wait on its answer to the handoff in 1.1. The per-rate calibration mark (4.5) waits on
its answer to `scene-settings-handoff.md`. Every other task can be built now, against a schema fixture that
declares the rates.

## 1. The ask

- [x] 1.1 Write `../audio-vue/input-and-rates-handoff.md` with these asks:
  - Declare the rates `install.input.rate` takes, as `calibration.RATES`, in `/v1/schema` (an `enum`
    is suggested), so the console's Input section and its every-rate pass read one list. Explain why:
    the maintainer ruled the list comes from the host, and a capture rate outside it can never be
    calibrated.
  - Give each run's capture rate in Hz, as `rate`, in `GET /v1/runs` (`RunEntry`), read from the
    record as `runs.listing` reads `kind`. The Capture page lists each run's rate (maintainer,
    2026-11-08).
  - Declare `PUT /v1/install/{block}`'s 409 refusal during a calibration
    (`{"detail": CALIBRATING}`, no `current_rev`) in the contract beside `Stale`. Today the
    generated client cannot decode it.
  - Reword `calibration-record`'s "A run at another rate leaves the panel's own rate uncalibrated,
    and says so", so a report says the installed rate is uncalibrated only where no valid record
    holds at it. A pass calibrates the installed rate too (maintainer, 2026-11-08; alignment F8).

  Verify the file exists, and record the ask in `.claude/kb/agent/working-notes.md`.

## 2. The host's rates

- [ ] 2.1 Add `SchemaFacts.inputRates(_:) -> [Int]?`: the rates declared on
  `$defs["install.input"].properties.rate`, ascending, and `nil` where none are declared (design
  D1). Add `install.input` with a declared `enum` of the five rates to
  `Fixtures/schema-trimmed.json`, shaped as the handoff asks. Verify with `SchemaFactsTests`: the
  fixture gives `[44100, 48000, 88200, 96000, 192000]`, and a schema with no choices gives `nil`.
- [ ] 2.2 Once audio-vue answers, refresh the saved contract (`tools/refresh-contract.sh`) and
  regenerate the fixture's `install.input` from its `json_schema()`. Adjust `inputRates` if the
  declared form differs from an `enum`. Verify with `SchemaFactsTests` against the regenerated
  fixture.

## 3. Install settings and devices in the client

- [ ] 3.1 Add `HostClient.installBlocks(at:token:) -> [String: InstallBlockState]` (`doc`, `rev`)
  for `GET /v1/install`, and rebuild `install(at:token:)` on it with an unchanged signature, so
  `CalibrationRuns` and `PanelScenes` need no change (design D2). Verify with
  `HostClientScenesTests`: a block's `rev` and `doc` are read, and a block never written reads as
  revision 0 with an empty doc. `CalibrationRunsTests` and `PanelScenesTests` should pass unchanged.
- [ ] 3.2 Add `HostClient.captureDevices(at:token:) -> (devices: [String], reason: String?)` for
  `GET /v1/host/devices`. Verify with a `HostClientTests` case over `FakeTransport`: two devices
  read, and an empty list carries its reason.
- [ ] 3.3 Add `HostClient.writeInstall(_ doc:, block:, base:, at:, token:) -> InstallWritten` for
  `PUT /v1/install/{block}`. Map 409 `Stale` to `.stale(currentRev:)` and 422 to `.invalid`, as
  `writeScene` does. The calibration refusal arrives as `.unexpectedAnswer` until 3.4. Verify with a
  new `HostClientInstallWritesTests`: the body carries `doc` and `base_rev`; `calibration` and
  `chain_changed` are read; a stale and an invalid answer each map; and a 409 with only `detail`
  gives `.unexpectedAnswer`.
- [ ] 3.4 Once the contract declares the calibration refusal, map it to `.conflict` with the host's
  words. Change the last case of 3.3's test to expect `.conflict("a calibration has the panel --
  cancel it first")`.
- [ ] 3.5 Lift `PanelRows.rate(_:)` to a public `RateText.text(_:)` in ConsoleCore, and use it in
  `PanelRows` (design D9). Verify with `PanelRowsTests` unchanged, plus a `RateTextTests` case:
  44 100 gives `44.1 kHz`, and 96 000 gives `96 kHz`.
- [ ] 3.6 Once the contract gives `rate` on `RunEntry`, add `RunEntry.rate: Int?` and read it in
  `HostClient.runs` (`HostClient+Calibration.swift`), with `nil` where absent. Verify with
  `HostClientCalibrationTests`: a run with `rate` 96 000 reads 96 000, and one without reads
  `nil`.

## 4. The Capture page and its Input section

- [ ] 4.1 Add `InputEdit.doc(block:device:rate:)`, pure (design D2): copy the block, set or remove
  `device`, set `rate`. Verify with `InputEditTests`: `pair` `[2, 3]` is kept; the default device
  removes `device`; an empty block gains only `rate`.
- [ ] 4.2 Add `PanelInput` (`@Observable @MainActor`, made by a new `HostConnection.makePanelInput()`
  like `makeCalibrationRuns()`). It loads the `input` block and revision, the schema's rates and
  the devices. It exposes `device`, `rate`, `devices`, `devicesReason`, `rates`, `note` and
  `write(device:rate:)`. On `.stale` it reloads and notes that the values changed elsewhere. On
  `.conflict` it keeps the host's words. On `.unexpectedAnswer` it reloads and says the host refused
  the change. After a write it shows `InstallWritten.calibration`. Verify with `PanelInputTests` over
  `FakeTransport`: defaults when the block was never written; an installed device that is not
  listed is marked not attached; a write sends revision 4 and keeps `pair`; a stale write reloads
  and sets the note.
- [ ] 4.3 Rename the Calibration page to Capture (design D9). `PanelSection.calibration` becomes
  `.capture`, titled Capture. Remove `.input`, and delete `SketchInputPage` and
  `SketchChainWarning`, which only it uses. Rename `CalibrationPage` to `CapturePage` and
  `CalibrationForm` to `CaptureForm`, with `navigationTitle("Capture")`. Rename the "Runs" section
  to Calibration History. Search `AudioVueConsole/`, `ConsoleCore/` and the Xcode project for
  every reference to the old names. Verify that the app builds, the sidebar lists Panel, Scenes,
  Capture, Display and History, and the previews show.
- [ ] 4.4 Add `AudioVueConsole/Calibration/InputSection.swift` at the top of `CaptureForm`: Device
  and Rate pickers, the not-paired prompt, the host's reason beside an empty device list, and the
  note. A change asks first ("Changing the input restarts the panel.") unless the live state says
  `.down`. Both pickers are disabled while `pass.isUnderWay` is true or the live calibration
  lifecycle is not `.off`. Verify with SwiftUI previews of paired, not paired, no devices, and
  disabled during a run, and by running the app against the proving host: choose 96 kHz, confirm,
  and see the panel restart and the host's calibration words.
- [ ] 4.5 Once audio-vue answers `scene-settings-handoff.md` and the contract is refreshed, add its
  per-rate calibration read to `HostClient`, and mark each rate in the picker as calibrated, stale
  or not calibrated (design D3). Until then, show no marks. Verify with a `HostClient` test of the
  read, and a preview with 48 and 96 kHz calibrated.

## 5. The pass in the core

- [ ] 5.1 Give `OutputDevice` `availableRates: [ClosedRange<Double>]` from
  `kAudioDevicePropertyAvailableNominalSampleRates` in `CoreAudioOutputDevices.list()`, and
  `offers(_:)` within 0.5 Hz (design D6). Keep `init(uid:name:)` for tests, defaulting to no
  ranges. Verify with `OutputDeviceTests`: ranges `[44100…48000, 96000…96000]` offer 44 100, 48 000
  and 96 000, but not 88 200 or 192 000. Check `PlaybackDeviceMemoryTests` still pass, since
  `OutputDevice` is `Hashable`.
- [ ] 5.2 Add `CalibrationSession.run(_:device:host:) async -> Ending`, and make `start` launch it
  (design D4). Verify that `CalibrationSessionTests` and `CalibrationSessionCancelTests` pass
  unchanged, plus one case where `run` returns `.completed` once the scripted state names the arm.
- [ ] 5.3 Add `PassPlan.make(hostRates:outputRates:)` and `RateOutcome` (`.ended`, `.skipped`,
  `.notRun`) (design D5). Verify with `PassPlanTests`: five host rates on an output without 192 kHz
  give four runs and 192 kHz skipped, in ascending order; no rate in common gives no runs.
- [ ] 5.4 Add `CalibrationPass` (`@Observable @MainActor`, design D4). It wraps the session, with
  `start(kind:rates:device:host:)`, `cancel()`, `observe(_:isLive:)`, `isUnderWay`, `current`,
  `outcomes` and `isMultiRate`. It runs `session.run` per rate. It goes on past `.failed`,
  `.expired`, `.refused`, `.stimulusRefused`, `.stimulusFailed`, `.playerFailed` and
  `.hostFailed` other than `.tokenRefused`. It ends on `.cancelled`. Before each later rate it
  stops where the latest state is not `.up` or not live, or the last ending was
  `.hostFailed(.tokenRefused)`. It holds a `ProcessInfo` activity that disables idle sleep from
  start to end. Verify with `CalibrationPassTests` over the scripted host and player:
  - each arm states its rate in ascending order;
  - an expired 88.2 kHz goes on to 96 kHz;
  - cancel at 96 kHz leaves 192 kHz not run;
  - a state going `.down` stops the pass;
  - `isUnderWay` stays true between two rates;
  - a one-rate pass of a characterization arms a characterization;
  - no `PUT /v1/install` is sent.
- [ ] 5.5 Order `CalibrationPass.outcomes` by the host's rates, with each skipped and not-run rate
  in place, so the app only words them. Verify with a `CalibrationPassTests` case: a pass that
  skipped 192 kHz and was cancelled at 48 kHz gives 44.1 ended, 48 cancelled, 88.2 and 96 not run,
  and 192 skipped.

## 6. The pass in the app

- [ ] 6.1 Hold a `CalibrationPass` in the app delegate in place of the session
  (`AudioVueConsoleApp.calibration(using:)` returns the pass, made around the session). Switch
  `applicationShouldTerminate`, `RunUnderWay.settle`/`waitForEnd`, `PanelWindow` (its
  `calibration` property, `observe` forwarding with `live.isLive`, the switch of panel),
  `AddPanelSheet`, `CapturePage`, `CalibrateSection`, `RunProgress` and `InputSection` to it. Verify that the
  app builds, and that quitting mid-pass between two rates asks first.
- [ ] 6.2 In `CalibrateSheet`/`CalibrateFields`, add the rate choice (At the installed rate, At
  every rate). It is disabled for Calibration + Characterization and where the host declares no
  rates. Name the rates the chosen output skips, and disable Start where it offers none. `start`
  takes the kind and the rates. Verify with previews: every rate on an output without 192 kHz; a
  characterization chosen; no rate in common.
- [ ] 6.3 In `CapturePage` and `RunProgress`, show "Rate 3 of 5 · 88.2 kHz" above the run's step
  during a multi-rate pass, and the summary list when it ends (`PassSummaryRow` beside `EndingRow`
  in `RunProgress.swift`, wording an ended rate with `EndingText`), with Open Report on each completed
  rate whose run the host lists with a report. Open no report by itself for a multi-rate pass, and
  read the runs list after each rate ends. A one-rate pass keeps `EndingRow` and opens its report as
  now. Verify with previews of a pass under way and of a summary.
- [ ] 6.4 Update `StatedRun.rate`'s doc comment to say it is the run's rate (the installed rate, or
  the rate a pass is on). Verify by reading it.
- [ ] 6.5 Show each run's rate in `RunRow` beside its kind, as `RateText.text(_:)`, or `—` where
  `RunEntry.rate` is `nil`, and word a pass's rates the same way. Verify with the
  `CaptureForm` preview "Calibrated, with runs" given runs at 96 000, at 44 100, and with no rate.

## 7. Integration

- [ ] 7.1 Run a pass from the app on the proving host with the D10s. Check that five runs are
  listed under Calibration History on the Capture page, each with a report and (once 3.6 is built)
  its rate, and that the panel captures at its installed rate once the hold ends. Check that the
  Input section's rate marks (once 4.5 is built) show all five calibrated. Record the pass's length and anything surprising in
  `.claude/kb/agent/working-notes.md`.
- [ ] 7.2 Update `.claude/kb/agent/host-contract.md` (devices, install writes, the stated rate's
  capture, back-to-back arms in the hold, the runs' rate) and `project-map.md` (`CapturePage`,
  `InputSection`, `PanelInput`, `CalibrationPass`, `RateText`). Verify that `openspec validate input-and-rates --strict` passes.

## Workflow follow-up

- Archive the change after the maintainer's run, syncing `capture-input`, `calibration-pass`,
  `calibration-run`, `calibration-history` and `panel-window`.
- At archive, update `openspec/specs/calibration-history/spec.md`'s Purpose, which names the
  Calibration page, to name the Capture page.
