# Tasks

Run the core suite with `cd ConsoleCore && xcrun swift test --disable-xctest` (`commands.md`). Only
5.3, a calibration setting the output's bit depth, waits on audio-vue's answer to the handoff in 1.1.
Every other task can be built now.

## 1. The ask

- [x] 1.1 Write `../audio-vue/mac-output-handoff.md`. It asks that `cal-play rate <device> <hz>`:
  - sets the deepest integer physical format the device offers at the rate
  - holds its settle where either the rate or the format changed
  - prints the format it set

  Give the reason: the bit-perfect claim in `cal-play.md` holds only for a device at 24 bits or
  more, and nothing sets it today (design D10). Also ask that `settings-schema` state that a choice
  setting exports its choices as an `enum`. The console reads `input.fmt`'s choices from it, and
  only `export.py` says so today (alignment F2). Verify the file exists, and record the ask in
  `.claude/kb/agent/working-notes.md`.

## 2. The capture format

- [x] 2.1 Add `SchemaFacts.inputFormats(_:) -> [String]?`, reading `input.fmt`'s `enum` as
  `inputRates` reads the rate's. Add `fmt` with `S16_LE` and `S32_LE` to
  `Fixtures/schema-trimmed.json` where it lacks it. Verify with `SchemaFactsTests`: the two formats
  in order, and nil for a schema without the key.
- [x] 2.2 Add `fmt` to `InputEdit.doc(block:device:rate:format:)`. A nil format removes the key, so
  the schema's default applies. Verify with `InputEditTests`: `fmt` set, `fmt` removed, and `pair`
  kept.
- [x] 2.3 Give `PanelInput` `format`, `formats`, `isFormatOffered` and `formatChoices` (design D1).
  Make `write(device:rate:format:)` return `Bool`, true only where the host stored the write.
  Verify with `PanelInputTests`:
  - a block never written shows `S16_LE`
  - a write sends `fmt` on the block's revision
  - the return is false on a stale or conflicting write
  - an unanswered write returns true where the block read back holds the choice, and false where
    it does not
- [x] 2.4 Add `FormatText.capture(_:)` and `FormatText.output(_:)` (design D1, D2). Verify with a
  new `FormatTextTests`: `S16_LE` is "16-bit", `S32_LE` is "24-bit in 32-bit", `S8` is `S8`, and an
  output of 24 bits integer is "24-bit Integer".
- [x] 2.5 In `InputSection.swift`:
  - `InputChoice` gains `format`.
  - `InputFields` names its rows "Capture Device (audio-vue)" and "Capture Rate (audio-vue)", adds
    "Capture Format (audio-vue)" with the 16-bit flag, and renames the header "Input and Output".
  - `HoldRow` and the lock's footer cover the format.

  Verify the Paired, Disabled during a run and Holding after a pass previews in Xcode, and the
  `capture-input` scenarios by hand on the proving host: the format written, the restart asked, and
  the 16-bit flag.

## 3. This Mac's output

- [x] 3.1 Add `OutputFormat` and `OutputFormatRange`, and `OutputDevice.formats`, `formats(at:)`
  and `deepestInteger(at:)` (design D2). Verify with `OutputDeviceTests`: formats offered only at
  some rates, deepest first, float and integer both kept, and nil with no integer format.
- [x] 3.2 Add the `OutputControl` protocol, `OutputCurrent` and `OutputFailure`. In a new
  `OutputControl.swift`, add `CoreAudioOutputControl`, which lists devices with their formats,
  reads the current rate and format, sets either, and follows changes through listener blocks
  removed when the stream ends (design D3). Delete `OutputDevices.swift`'s `OutputDevices` and `CoreAudioOutputDevices`, keeping
  `OutputDevice`. Move `PlaybackDeviceMemoryTests`' live listing to `CoreAudioOutputControl().list()`.
  Verify the suite builds, and that a new `OutputControlLiveTests`, skipped without
  `AUDIO_VUE_LIVE_OUTPUT=<device name>`, reads the D10s's rate and format and finds them again after
  setting each and restoring.
- [x] 3.3 Give `PlaybackDeviceMemory` `isSynchronized(for:)`, true where unset, and
  `setSynchronized(_:for:)`. Verify with `PlaybackDeviceMemoryTests`: unset is true, off is kept per
  host, and another host is unaffected.
- [x] 3.4 Add `RateMatch` and `RateSync` (design D5, D6). Verify with new `RateMatchTests` and
  `RateSyncTests`:
  - each `RateMatch` case, a capture rate the device does not offer included
  - `afterCapture`: nil while off, nil when already the same, nil when not offered
  - `onOutputChosen`: off sets the output, on writes the capture rate
  - `onSynchronize`: the capture rate where it differs and is offered
- [x] 3.5 Add `MacOutput` (design D4), made by `HostConnection.makeMacOutput()`. Give it `load()`,
  `follow()`, `choose(_:)`, `setRate(_:)`, `setFormat(_:)`, `setSynchronized(_:)` and its `Note`.
  Verify with new `MacOutputTests` over a scripted `OutputControl`:
  - the remembered device chosen, and a gone one leaving none
  - a change yielded is read again
  - a refused set keeps its words and the device's values
  - synchronization on by default and remembered
- [x] 3.6 Add `OutputFields` in `AudioVueConsole/Calibration/OutputFields.swift` (design D7). It
  shows Output Device (this Mac), Output Rate (this Mac) from `PassPlan`'s host rates the device
  offers, Output Format (this Mac), Synchronize Rates, the `RateMatch` row and the under-24-bit
  flag, all disabled under the same `InputLock`. Add previews for: matched; different;
  cannot play; 16-bit; no device; and during a run. Verify each preview in Xcode.
- [x] 3.7 Wire the rows into `InputSection` and `CapturePage` (design D6):
  - `CapturePage` makes and loads `MacOutput` beside `PanelInput` and runs `follow()` in its task.
  - An output-rate choice goes through `RateSync.onOutputChosen`, and a capture write through the
    same ask.
  - `afterCapture`'s rate is set only after `write` returns true.
  - Turning on Synchronize Rates applies `onSynchronize`.

  Verify the `mac-output` scenarios by hand on the proving host with the D10s:
  - a capture rate followed by the output
  - an output rate written to the panel after the restart is asked
  - a declined restart changing neither side
  - a rate changed in Audio MIDI Setup shown as a mismatch and not followed

## 4. Calibrate… and the pass

- [x] 4.1 `CalibrateSheet` takes `MacOutput`'s device in place of its picker (design D8). It names
  the device, disables Start with the words to choose it in Input and Output where there is none,
  and adds `formatNote` from `deepestInteger(at:)` over the plan's runs. Remove the picker's
  `PlaybackDeviceMemory` calls. Verify the previews: a 16-bit output with Start enabled, and no
  output with Start disabled.
- [x] 4.2 `CalibrationPass` is made with an `OutputControl`.
  `start(kind:plan:device:host:returnTo:)` takes the `OutputDevice` and the capture rate where
  synchronization is on, and `perform` sets the output to it at its end where it differs (design
  D9). Update `AudioVueConsoleApp`'s `CalibrationPass(…)` and `CapturePage.start`. Verify with
  `CalibrationPassTests`:
  - a pass ending at 192 kHz with `returnTo` 96 000 sets 96 000
  - nil sets nothing
  - an output already at the rate is not set
  - a cancelled pass still returns it
  - a refused set leaves the pass's outcomes as they were

## 5. Integration

- [x] 5.1 Run the core suite and build the app with the quality gate clean. Verify both pass with no
  gate finding left unraised.
- [x] 5.2 On the proving host with the D10s:
  - run a pass of every rate with Synchronize Rates on, and check that the output returns to the
    capture rate while the panel still holds the 192 kHz result
  - run one with Synchronize Rates off, and check the output stays at 192 kHz
- [ ] 5.3 Once audio-vue answers the handoff in 1.1 and the app is rebuilt with its `cal-play`, set
  the D10s to 16-bit Integer in Audio MIDI Setup and run a calibration. Verify the output reads 24-
  or 32-bit Integer after it, and that `calibration-player`'s "The device at 16 bits" scenario
  holds.
- [x] 5.4 Update the KB:
  - `project-map.md`: `MacOutput`, `OutputControl` and `OutputFields`; `OutputDevices` gone from
    its ConsoleCore list; `CalibrateSheet` no longer picking the output; `InputSection` with the
    format
  - `pitfalls.md`: setting a rate or format clicks a playing chain
  - `working-notes.md`: the handoff

  Verify each note names a file that exists.

## Workflow follow-up

- Archive the change once 5.3 is done, and sync its specs.
