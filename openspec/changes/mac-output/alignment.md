# Code alignment

## Read

Pass 1, 2026-11-09:

- `AudioVueConsole/Calibration/InputSection.swift`: `InputChoice`, `InputShown`, `InputLock`,
  `InputSection` (ask, then write), `InputFields`, `HoldRow`, `InputNoteRow`. 344 lines.
- `AudioVueConsole/Calibration/CalibrateSheet.swift`: the output picker, the
  `PlaybackDeviceMemory` calls in `load` and `begin`, `CalibrateFields.plan`, and `rateNote`.
- `AudioVueConsole/Calibration/CapturePage.swift`: `.task(id:)` making and loading `PanelInput`,
  `start(_:_:on:)` passing `device.name`, `inputLock`, and `ended`.
- `AudioVueConsole/AudioVueConsoleApp.swift`: `calibration(using:)` makes
  `CalibrationPass(session:)`.
- `ConsoleCore/.../PanelInput.swift`: `load`, `write`, `refused` (`.unreachable` re-reads), `show`.
- `ConsoleCore/.../InputEdit.swift`: `doc(block:device:rate:)`.
- `ConsoleCore/.../OutputDevices.swift`: `OutputDevice`, `offers`, the `OutputDevices` protocol,
  `CoreAudioOutputDevices` (names, UIDs and rates read, nothing set).
- `ConsoleCore/.../PlaybackDeviceMemory.swift`: `remember` and `chosen`, per host id.
- `ConsoleCore/.../CalibrationPass.swift`: `start(kind:plan:device:host:)`, `perform`'s `defer`, and
  `mayGoOn`.
- `ConsoleCore/.../CalibrationSession.swift`: `perform` (render, settle, arm, play) and `settle`
  through `player.setRate`.
- `ConsoleCore/.../CalibrationPlayer.swift`: `setRate` runs `cal-play rate`.
- `ConsoleCore/.../PassPlan.swift`: `make(hostRates:output:)`.
- `ConsoleCore/.../SchemaFacts.swift`: `inputRates` reads `$defs.install.input.properties.rate.enum`.
- `ConsoleCore/.../HostConnection.swift`: `makePanelInput` and `makeCalibrationRuns`.
- `ConsoleCore/Tests/.../Fixtures/schema-trimmed.json`: `input.fmt` is present with its `enum`.
- `../audio-vue/src/schema/install.py`: `input.fmt`, a chain `choice`, `S16_LE` default.
- `../audio-vue/src/schema/export.py`: `_shape` and `setting` export choices as `enum`.
- `../audio-vue/cal-play/src/play.rs` and `macos.rs`: a float32 client format; only `set_rate`, no
  physical format.
- KB: `pitfalls.md` (headings, and in full: the `.task` trap, MODIFIED scenarios, the sandbox,
  `cal-play` in the sandbox, the chain write's answer, the hanging suite); `open-questions.md`
  (none open); `project-map.md` lines 78–97.
- Referenced specs, read in full where relied on: `audio-vue:settings-schema`;
  `audio-vue:calibration-lifecycle` ("A finished run holds the screen until audio returns");
  `audio-vue:calibration-record` ("The newest valid record for the device and rate is in force").
  `settings-store` and `control-api` were checked by `input-and-rates` on 2026-11-08 for the same
  write, and are unchanged here.
- audio-vue's open changes: `card-colours` and its deltas.
- Removals searched: `OutputDevices` and `CoreAudioOutputDevices` across `AudioVueConsole/`,
  `ConsoleCore/`, the Xcode project and the KB.

## Findings

- **F1. An unanswered write can still be stored** (resolved)
  - Plan: the sync follows the capture rate only where `write` returns true.
  - Code: `PanelInput.refused` treats `.unreachable` as unanswered and reads the block again. The
    host answers a chain write only after the panel restarts, and often after the client has
    stopped waiting (`pitfalls.md`, "A chain install write answers only after the panel has
    restarted").
  - Goes to: design and task.
  - Resolution: D1 returns whether the block read back holds the choice. Task 2.3 tests both ways.
- **F2. No spec says a choice setting is exported as an `enum`** (resolved, host ask)
  - Plan: the capture format choices come from `input.fmt`'s `enum`.
  - Code: `export.py` `_shape` writes `enum` for every choice, and the fixture has it. The
    `settings-schema` requirement "The declarations export as JSON Schema" names type, default,
    label, help, class, standard and step, but not choices. Only "A capture rate is one the
    calibration is built for" says the export declares a set, and only for the rate.
  - Goes to: task.
  - Resolution: task 1.1's handoff asks audio-vue to state it.
- **F3. audio-vue has an open change to `settings-schema`** (resolved, no effect)
  - Plan: relies on `audio-vue:settings-schema`.
  - Code: `card-colours` adds "A colour setting says what it overrides" to `settings-schema`. It
    touches colour settings only, not `input` or how choices export. Its Impact names
    `card-settings` and `scene-rendering`, not a spec this change modifies.
  - Goes to: noted.
  - Resolution: nothing to change.
- **F4. Output Rate with no host rates** (resolved)
  - Plan: the output rate choices are the host's rates the device offers.
  - Code: `SchemaFacts.inputRates` returns nil where the schema declares none, and `PanelInput`
    then offers the installed rate alone.
  - Goes to: design.
  - Resolution: D7 offers the device's current rate alone there.
- **F5. A capture format the device refuses** (deferred, as `input-and-rates` deferred rates)
  - Plan: the capture format is chosen from the schema's formats.
  - Code: `GET /v1/host/devices` lists names only, so the app cannot know whether a device takes
    `S32_LE`. A refused format leaves the panel unable to capture after the restart.
  - Goes to: design.
  - Resolution: a risk in the design. The Panel page shows the condition, as it does for a refused
    device or rate.
- **F6. The removal's references** (resolved)
  - Plan: task 3.2 removes `OutputDevices` and `CoreAudioOutputDevices`.
  - Code: callers are `CalibrateSheet.load` (task 4.1), `PlaybackDeviceMemoryTests` (task 3.2), and
    `project-map.md` lines 82 and 96 (task 5.4). The Xcode project uses a synchronized folder, so
    new and removed files need no project edit.
  - Goes to: task.
  - Resolution: each reference is assigned as listed.
- **F7. The pass's device parameter changes type** (resolved)
  - Plan: `start` takes an `OutputDevice` and `returnTo`.
  - Code: `CalibrationPass.start(kind:plan:device:host:)` takes a `String`. Its callers are
    `CapturePage.start` and `CalibrationPassTests`. Five parameters is the gate's limit, not over
    it.
  - Goes to: task.
  - Resolution: task 4.2 updates both.

- **F8. An output rate equal to the capture rate** (resolved while building, 2026-11-09)
  - Plan: with Synchronize Rates on, an output rate is written as the capture rate first.
  - Code: `InputSection.choose` ignores a choice equal to what is shown. So repairing a mismatch by
    choosing the capture rate for the output wrote nothing, and set nothing.
  - Goes to: design.
  - Resolution: `RateSync.onOutputChosen` takes the capture rate and sets the output alone when the
    two are equal (D6, `RateSyncTests`).
- **F9. `InputSection.swift` would pass the file limit** (resolved while building)
  - Plan: D7 adds the output rows in a file of their own.
  - Code: the wiring alone took `InputSection.swift` past 400 lines.
  - Goes to: design.
  - Resolution: its small row views moved to `InputRows.swift` (D7).
- **F10. The pitfall task 5.4 named is unmeasured** (resolved)
  - Plan: record that setting a rate or format clicks a playing chain.
  - Code: nothing measured it. The design's Risks already hold it as a risk.
  - Goes to: task.
  - Resolution: `pitfalls.md` instead records what was measured: Core Audio's generic reads and
    listener blocks under Swift 6, and the live test on the D10s.

- **F11. Calibrate… offered a stale installed rate** (resolved while testing, 2026-11-09)
  - Found by the maintainer: with the capture rate changed to 48 kHz in the Input section, the
    sheet still said "At the installed rate, 96 kHz".
  - Code: `CapturePage`'s readiness took `CalibrationRuns.installedRate`, read once as the page
    opened. Only `PanelInput` is updated by a write. This came in with `input-and-rates`.
  - Goes to: task.
  - Resolution: readiness takes `PanelInput.rate`. `CalibrationRuns` no longer reads the install
    block or the schema (`pitfalls.md`).

## Questions for the maintainer

None open. The maintainer agreed every behavioural choice on 2026-11-09:

- the four rows and Synchronize Rates
- formats shown and flagged, not synchronized
- the output chosen in the Input section
- the capture rate leading, and changes made elsewhere not followed
- a mismatch shown where the output cannot play the rate
- the output returned after a calibration
- manual changes made through Core Audio without the settle

The two calls made within those choices are recorded here so they can be overruled:

- Synchronize Rates is on for a panel not seen before.
- A 16-bit output warns in Calibrate… but does not block Start.

## Confirmed

- `InputSection.swift` is 344 lines, so the output rows need a file of their own under the 400-line
  limit (D7).
- `PanelInput.write` returns nothing today, and `InputEdit.doc` writes only `device` and `rate`.
- `input.fmt` is a chain `choice`, `S16_LE` or `S32_LE`, default `S16_LE`, and is exported with an
  `enum`.
- `cal-play` sets the nominal rate and never the physical format. It plays a 32-bit float client
  format.
- The app reads output devices' available rates and sets nothing through Core Audio.
- `CalibrationPass` is owned by the app delegate, and clears `isUnderWay` in `perform`'s `defer`.
- The capture input is locked for the whole pass and the hold, so the capture rate taken at Start
  is the capture rate at the end (D9).
- The hold ends on a held level, not a click (audio-vue `calibration-lifecycle`), so setting the
  rate after a pass leaves the hold in place.
- A record applies by device and rate only (audio-vue `calibration-record`).
- Setting a device's rate works from inside the App Sandbox (`pitfalls.md`).
- `openspec validate mac-output --strict` passes, and every MODIFIED block keeps each scenario its
  main spec names.
