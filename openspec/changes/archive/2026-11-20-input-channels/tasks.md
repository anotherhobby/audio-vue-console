# Tasks

Run the core suite with `cd ConsoleCore && xcrun swift test --disable-xctest` (`commands.md`).

## 1. The host's listing and the choice

- [x] 1.1 Refresh the saved contract (`tools/refresh-contract.sh`). Add `CaptureDevice` and read the
  listing into it in `HostClient.captureDevices` (design D1). Verify with `HostClientTests`: a
  device with no streams reads nil; the miniDSP reads one way, `S32_LE`, four channels.
- [x] 1.2 Move `InputChoice` to `ConsoleCore` with `pair` and `fitted(to:formats:rates:)`; write the
  pair in `InputEdit.doc`, unset at the default (design D2, D3). Verify with `CaptureDeviceTests`
  (the shared formats and rates; channels as the most among the matching ways; a choice fitted to
  the four-channel device; one leaving it takes 48 kHz, 16-bit and the first pair; a pair within
  the channels kept; the default device unchanged) and `InputEditTests` (the pair set, and unset at
  the default).
- [x] 1.3 In `PanelInput`: hold `[CaptureDevice]` and the installed `pair`, narrow `formatChoices`
  and `rateChoices` to the installed device, add `channels`, `installed` and `fitted(_:)`, take an
  `InputChoice` in `write`, and word `.invalid` as the host's sentences (design D2, D5). Verify
  with `PanelInputTests`: a four-channel device offers its one format, its rates and four
  channels; a device the host cannot read offers no pair and every format; a write keeps the
  block's other keys.

## 2. The panel's waiting sentence

- [x] 2.1 Read `run.phase` and `run.screen_status` into `PanelState.captureWaiting` (design D4).
  Verify with `PanelStateTests`: waiting gives the sentence, drawing gives nil.

## 3. The Capture page

- [x] 3.1 In `InputSection` and `InputRows`: fit each choice before asking, add `ChannelPairRows`
  under the format and `CaptureWaitingRow`, and pass the waiting sentence from `CapturePage`
  (design D2 to D4). Verify by building the app with no warnings and the gate clean.

## 4. Integration

- [x] 4.1 Against the proving host: the Input section shows the miniDSP with 24-bit in 32-bit as
  its only format and Left and Right Channel over four channels; choose channels 3 and 4, confirm
  the restart, and see the panel's log say `channels (2, 3) of 4`; choose the UCA202 and see the
  rate, format and pair fitted to it before the restart question; choose the miniDSP again. Record
  the run in `working-notes.md`. Run by the maintainer, 2026-11-20: tested, no issue found.

## Workflow follow-up

- The maintainer's run, then verify and archive the change and sync its specs.
- Delete `capture-channels-handoff.md` and tell the maintainer.
