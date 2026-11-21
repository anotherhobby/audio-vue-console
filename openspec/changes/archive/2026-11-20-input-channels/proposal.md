# Proposal

## Why

The Capture page writes the input's device, rate and format, and nothing else. A device that
streams more than two channels, such as the miniDSP 2x4HD (four), then leaves the host's
`stream_channels` at its default of 2, and the panel restarts in a loop (proving Pi, 2026-11-20,
after the store was rebuilt). The app let the user choose an input the panel cannot open, and
showed nothing of why. The cause is fixed on the host (audio-vue `capture-channels`, archived and
deployed 2026-11-20, answering the console's hand-off of that day); this change is the app's side
(maintainer, 2026-11-20: fix the cause, not the setting).

## What Changes

- **The Input section offers the channel pair** where the chosen device streams more than two
  channels: which two are measured, as left and right, from the count the host reports for the
  device. A two-channel device shows none. The app never asks how many channels a device streams.
- **The format and rate choices are the device's**, where the host reports them, so one the device
  does not offer cannot be chosen.
- **A capture the panel cannot open is said**, with the panel's own sentence, on the Capture page,
  in place of a panel that silently restarts.
- **Choosing a device writes an input the panel can open**: the format, the rate and the pair are
  fitted to the new device before the restart is asked about.
- **A refused input shows the host's own sentences.**

## Capabilities

### Modified Capabilities

- `capture-input`: the device's channels and formats come from the host's listing; the channel
  pair is chosen; a capture that cannot open is said.

## Impact

- **Code:** `HostClient`'s device listing, `InputChoice`, `InputEdit` and `PanelInput` in
  `ConsoleCore`; `InputSection` and `InputRows` in the app target.
- **Host:** none outstanding; `capture-channels-handoff.md` (2026-11-20) states what audio-vue
  built. Referenced specs relied on: `audio-vue:control-api` ("Each capture device says how it
  streams"), `audio-vue:settings-store` ("An input write the attached device cannot stream is
  refused"), `audio-vue:settings-schema` ("The input block holds no channel count"),
  `audio-vue:capture-device` and `audio-vue:panel-screen` ("Unattended, a capture that will not
  open is waited for").
