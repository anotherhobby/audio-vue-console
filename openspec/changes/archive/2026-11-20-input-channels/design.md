# Design

## Context

Read on 2026-11-20, with audio-vue's `capture-channels` archived and deployed
(`capture-channels-handoff.md`):

- **The listing.** `GET /v1/host/devices` gives `{devices: [{name, streams}], reason}`; `streams`
  is a list of `{format, channels, rates}` or absent for unknown. `HostClient.captureDevices` read
  bare names.
- **The block.** `install.input` is `device`, `fmt`, `pair` (default `[0, 1]`) and `rate`;
  `stream_channels` is gone. `InputEdit.doc` wrote device, rate and format; `PanelInput.write` took
  the three; the app's `InputChoice` held the three.
- **The host's check.** A write to a listed device with known streams is refused with 422 and one
  failure per setting; `HostClient.writeInstall` throws `.invalid([DocumentFailure])`, which
  `PanelInput` worded as an unexpected answer.
- **The state.** `sections.run` carries `phase` and `screen_status`; `PanelState` read neither.

## Goals / Non-Goals

**Goals:**

- No input the panel cannot open leaves the app, where the host says what the device streams.
- The rules live in `ConsoleCore`, tested without a view.

**Non-Goals:**

- Listing a device's ways of streaming, or choosing among altsets.
- A health row for the capture on the Panel page.

## Decisions

### D1. `CaptureDevice` holds what a device streams

`CaptureDevice { name, streams: [Stream]? }` in `ConsoleCore`, nil for unknown. Its three questions
are the host's check in the host's order: `formats(among:)` (the declared formats the device
streams), `rates(among:format:)` (the declared rates it takes in that format) and
`channels(format:rate:)` (the most channels among the ways taking both). Unknown answers "all" to
the first two and nil to the third, so a device the host cannot read is offered as before.

### D2. `InputChoice` moves to the core and gains the pair

`InputChoice { device, rate, format, pair }` replaces the app target's type. `fitted(to:formats:
rates:)` is the only rule that changes a choice: the format kept or the device's first, the rate
kept or the nearest the device takes, the pair kept or `[0, 1]`. `PanelInput.fitted(_:)` applies it
with the listing and the schema's choices; `InputSection.choose` fits every choice before it asks
about the restart, so what the user confirms is what is written.

Nearest rate, not lowest: a user at 96 kHz moving to a device that stops at 48 kHz wants 48, and
the write asks first, so the change is seen.

### D3. The pair is two pickers, shown over more than two channels

Left Channel and Right Channel, each "Channel 1" to "Channel n", from `PanelInput.channels`. Any
two may be chosen, the same one twice included, since the host accepts it and a mono feed on one
channel is a real wiring. The block counts from 0; the labels count from 1, as the device's own
panel does. The pair is written as the key unset where it equals the schema's default, as the
device and format are (`InputEdit.doc`).

### D4. The panel's waiting sentence is read from the run

`PanelState.captureWaiting` is `run.screen_status` while `run.phase` is `waiting`, else nil. The
Capture page passes it to the Input section, which shows it as a warning row. It is not a health
fault on the host, so nothing else in the app shows it.

### D5. A refused write shows the host's sentences

`.invalid(failures)` becomes `Note.refused` with the failures' messages joined, so "pair:
hw:CARD=CODEC,DEV=0 streams 2 channels" reaches the user as the host wrote it.

## Risks / Trade-offs

- [The installed device's choices are shown while another device waits on the restart question] →
  the pickers show the asked choice's values; its lists are the installed device's for that moment,
  and the choice was fitted before it was asked.
- [A device unplugged, or the default device, cannot be fitted] → written as chosen; the host does
  not check it either, and the panel's waiting sentence says what is wrong.
