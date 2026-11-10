# Design

## Context

See `proposal.md` for why. As read on 2026-11-09:

- **The Input section.** `InputSection` (`AudioVueConsole/Calibration/InputSection.swift`, 344
  lines) shows `PanelInput`'s device and rate through `InputFields`. A choice is an `InputChoice`
  `(device, rate)`. It asks before a restart unless the panel is down, then calls
  `PanelInput.write(device:rate:)`, which builds the document with `InputEdit.doc` and returns
  nothing. Its pickers are disabled for any `InputLock` other than `.free`.
- **The capture format.** `input.fmt` is declared in audio-vue's `src/schema/install.py` as a chain
  `choice` of `S16_LE` and `S32_LE` ("24 bits in 32"), default `S16_LE`. The schema export gives it
  as an `enum`. `SchemaFacts` reads `input.rate`'s choices (`inputRates`) and nothing for `fmt`.
- **The output device.** `CalibrateSheet` lists `CoreAudioOutputDevices().list()` and picks one,
  remembered per host id in `PlaybackDeviceMemory` (`UserDefaults`). `OutputDevice` holds `uid`,
  `name` and `availableRates`. The app reads no device's current rate or format and sets nothing.
  `cal-play rate` sets the rate and holds 12 s after a change. `cal-play play` opens the device with
  a 32-bit float client format and never touches the physical format
  (`../audio-vue/cal-play/src/play.rs`, `macos.rs`).
- **The pass.** `CalibrationPass` is held by the app delegate and outlives the window. It takes a
  device name, runs `CalibrationSession` per rate, and clears `isUnderWay` in `perform`'s `defer`.
  Design D7 of `input-and-rates` left the output at the last rate played. That rule is in its
  design only, not in a spec.
- **The sandbox.** The bundled `cal-play` sets device rates from inside the App Sandbox
  (`pitfalls.md`, "cal-play works from inside the App Sandbox"), so the app's own process can set
  them through Core Audio too.

## Goals / Non-Goals

**Goals:**

- One Core Audio seam behind a protocol, so the output model and the synchronization rules are
  tested without hardware.
- The synchronization rules as pure functions, apart from the views that apply them.
- `InputSection` stays under the gate's file size by moving the output rows to a file of their own.

**Non-Goals:**

- Setting a device with more than one output stream stream by stream. The first output stream is
  shown and set (D3).
- A settling wait after a manual change. Only an arm needs the chain settled.

## Decisions

### D1. The capture format joins the device and rate

`InputChoice` gains `format: String?`, `nil` meaning the schema's default. `PanelInput` gains
`format` and `formats` (`SchemaFacts.inputFormats(_:) -> [String]?`, from `input.fmt`'s `enum`),
and `isFormatOffered` and `formatChoices` built the same way as for the rate. `InputEdit.doc`
writes `fmt`. `write(device:rate:format:)` returns `Bool`, whether the host stored it, so the rate
sync acts only on a stored write (D6). An unanswered write already reads the block again
(`pitfalls.md`, "A chain install write answers only after the panel has restarted"). There it
returns whether the block read back holds the choice, since the host often stores a write it was
too slow to answer. `FormatText.capture(_:)` names `S16_LE` "16-bit", `S32_LE`
"24-bit in 32-bit", and any other format by its own name.

Alternative: a separate write for `fmt`. Rejected: the block is written whole on one revision, and
two writes would restart the panel twice.

### D2. Each output device carries its formats

`OutputDevice` gains `formats: [OutputFormatRange]`, where each range is `bits`, `isFloat` and the
rates it is offered at, read from the first output stream's
`kAudioStreamPropertyAvailablePhysicalFormats`. These pure helpers serve the rows and Calibrate…:

- `formats(at:) -> [OutputFormat]`, the distinct formats offered at a rate, deepest first.
- `deepestInteger(at:) -> Int?`.
- `offers(_:)` stays as it is.

`OutputFormat` is `bits` and `isFloat`. Its text is "24-bit Integer" or "32-bit Float", as Audio
MIDI Setup words a format.

### D3. `OutputControl` reads, sets and follows one device

A new protocol, `OutputControl` (`Sendable`):

- `list() -> [OutputDevice]`
- `current(uid:) -> OutputCurrent?`, the nominal rate and the first output stream's physical format
- `setRate(uid:hz:) throws(OutputFailure)`
- `setFormat(uid:_:) throws(OutputFailure)`
- `changes(uid:) -> AsyncStream<Void>`

`CoreAudioOutputControl` implements it in a new file. It writes
`kAudioDevicePropertyNominalSampleRate`. It writes `kAudioStreamPropertyPhysicalFormat` with the
available description matching the bits, kind and current rate. Its listener blocks, on the device's
rate, the stream's physical format and the system's device list, yield to an `AsyncStream`. It
replaces `CoreAudioOutputDevices`, whose `list()` moves into it, and `OutputDevices` goes. Tests use
a scripted control.

Alternative: set the rate with `cal-play rate`. Rejected for a manual change. It holds 12 s after
any change, for an arm the manual path never makes, and it cannot set a format.

### D4. `MacOutput` is the output's model

`MacOutput` (`@MainActor @Observable`, ConsoleCore) is made per panel by `HostConnection`, as
`PanelInput` is.

- It holds the devices, the chosen device (`PlaybackDeviceMemory`), its `OutputCurrent`, whether
  synchronization is on, and a `Note` for a refused set.
- `load()` lists the devices and reads the current values. `follow()` runs a task over
  `changes(uid:)` that reads them again, so the rows follow Audio MIDI Setup.
- `choose(_:)`, `setRate(_:)`, `setFormat(_:)` and `setSynchronized(_:)` change one thing each.
- A refused set re-reads the device and keeps `OutputFailure`'s words.

`PlaybackDeviceMemory` gains `isSynchronized(for:) -> Bool`, true where nothing is stored, and
`setSynchronized(_:for:)`.

### D5. The mismatch is a pure value

`RateMatch.of(output: OutputCurrent?, device: OutputDevice?, capture: Int?) -> RateMatch` is:

- `.noOutput` where no device or no capture rate is known
- `.same`
- `.different(output:capture:)`
- `.cannotPlay(capture:)` where the device does not offer the capture rate

The rows show its words. It ignores whether synchronization is on, since a mismatch is worth saying
either way.

### D6. Synchronization is decided by `RateSync` and applied by the views

`RateSync` holds the rules as pure functions:

- `afterCapture(stored:synchronized:output:device:) -> Int?`: the rate to set the output to after
  the host stores a capture rate, or nil where it is off, the same already, or not offered.
- `onOutputChosen(_:synchronized:capture:) -> Action`: `.setOutput(rate)` while off, and
  `.writeCapture(rate)` while on. When on, a rate equal to the capture rate also gives
  `.setOutput`, since writing an unchanged capture rate changes nothing and the output would never
  be set (found while building, 2026-11-09).
- `onSynchronize(capture:output:device:) -> Int?`.

`InputSection` routes an output-rate choice through the same ask-then-write path as a capture
choice. After `write` returns true for a new capture rate, it calls `MacOutput.setRate` with
`afterCapture`'s answer. A write of the device or format alone leaves the output as it is. A
declined ask or a refused write returns before any output change. A rate changed elsewhere reaches
the model only through `changes(uid:)` or a re-read, and nothing calls `RateSync` for it, so it is
never followed.

Alternative: `MacOutput` observes `PanelInput.rate` and follows any change. Rejected: a rate
re-read after another client's write would then be followed, which the maintainer ruled out.

### D7. The output rows are their own view

`OutputFields` (`AudioVueConsole/Calibration/OutputFields.swift`) shows Output Device, Output Rate,
Output Format, Synchronize Rates, the mismatch row and the 16-bit flag, for given values, with
previews. `InputSection.swift` would pass 400 lines with the wiring, so its small row views
(`CaptureFormatRow`, `ShallowRow`, `HoldRow`, `InputNoteRow`) move to `InputRows.swift`.
`InputFields` renames its pickers to "Capture Device (audio-vue)" and the rest, adds
Capture Format and its flag, and places `OutputFields` after them in the same section. The section
header becomes "Input and Output". Both are disabled together under the same `InputLock`. Output
Rate's choices are `PassPlan.make(hostRates:output:).runs`. Where the host declares no rates, the
device's current rate is the only choice, as the capture rate is then.

### D8. Calibrate… plays through the device chosen in the Input section

`CalibrateSheet` loses its picker. It is given the `OutputDevice?` that `MacOutput` holds, names it,
and disables Start with "Choose this Mac's output in Input and Output" where it is nil.
`CalibrateFields.plan` is unchanged. A `formatNote` says the record's noise floor will be the
output's 16 bits where `deepestInteger(at:)` is under 24 for a rate the plan runs.

### D9. The pass returns a synchronized output to the capture rate itself

`CalibrationPass.start(kind:plan:device:host:returnTo:)` takes the `OutputDevice` (its name for
`cal-play`, its uid for Core Audio) and `returnTo: Int?`, the capture rate where synchronization is
on. `perform`'s ending sets the output to `returnTo` through the `OutputControl` the pass is made
with, where its rate differs, before `isUnderWay` clears. A refusal is not an ending of the pass and
is left to the rows, which show the mismatch.

The pass does it, not the page, because the pass outlives the window and the page may not be open
when the last rate ends. The capture rate cannot change during a pass (`capture-input`), so the rate
taken at Start is still the capture rate at the end. Setting the rate during the hold does not end
the hold: the hold ends on a held level, not a click (audio-vue `calibration-lifecycle`).

### D10. The bit depth of a calibration is `cal-play`'s

The app does not set the format before an arm. `mac-output-handoff.md` asks audio-vue's
`cal-play rate` to do it in the same call:

- set the deepest integer physical format the device offers at the rate
- hold its settle if either the rate or the format changed
- print what it set

`CalibrationPlayer.setRate` is unchanged. The requirement is met once the bundled `cal-play` does
this, and a test with a scripted launcher cannot show it, so the task verifies it on the D10s.

Alternative: the app sets the format after `cal-play rate` returns. Rejected: whether a format change
re-locks the chain, and for how long, is unmeasured. `cal-play` already owns the settle and the
bit-perfect claim, and `make calibrate` would then miss the fix.

## Risks / Trade-offs

- **A format change mid-playback clicks.** Setting a rate or format while music plays can drop out
  or click on the chain → only on a user's choice or at the end of a pass, never on a change made
  elsewhere.
- **Devices with several output streams.** Only the first is read and set → shown as the first
  stream's format. No such device is in use (the D10s has one).
- **Core Audio listeners run off the main actor.** → They only yield to an `AsyncStream`. The model
  re-reads on the main actor.
- **Synchronized before the host answers.** If the host stores the rate and the output set then
  fails, the two differ → the mismatch row shows it, and the note gives Core Audio's reason.
- **A capture format the device cannot open.** The host lists capture devices by name only, so the
  section cannot tell whether a device takes `S32_LE`. A format it refuses leaves the panel unable
  to capture after the restart → the Panel page shows the panel's condition, as it does for a device
  or rate the interface refuses. Offering only what the device takes is out of scope, as the rates
  were in `input-and-rates`.
- **The calibration bit depth waits on audio-vue.** Until `cal-play` sets the format, a run at 16
  bits records a 16-bit floor → Calibrate…'s 16-bit warning (D8) can be built now and covers it in
  the meantime.

## Open Questions

- The exact words the rows use for the mismatch and the 16-bit flags are settled while building,
  with previews for each.
