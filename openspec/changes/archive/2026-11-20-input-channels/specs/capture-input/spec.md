# Spec Delta

## ADDED Requirements

### Requirement: The channel pair is chosen where a device streams more than two channels

Where the host says the installed device streams more than two channels as installed, the Input
section SHALL offer which channel is measured as left and which as right. Otherwise it SHALL offer
no pair. It SHALL never ask how many channels a device streams.

Source: Decision (maintainer, 2026-11-20): fix the cause, not the setting. audio-vue
`settings-schema` and `control-api`.

#### Scenario: A four-channel device

- **WHEN** the installed device is the miniDSP 2x4HD, which the host lists as four channels of
  `S32_LE`
- **THEN** the section offers Left Channel and Right Channel, each from Channel 1 to Channel 4,
  showing Channel 1 and Channel 2 for an unset pair

#### Scenario: A two-channel device

- **WHEN** the installed device streams two channels
- **THEN** no channel pair is offered

#### Scenario: A device the host cannot read

- **WHEN** the host lists the installed device with no ways of streaming known
- **THEN** no channel pair is offered, and every declared format and rate is

### Requirement: A chosen input is fitted to its device

A chosen input SHALL be fitted to what its device streams before it is asked about or written: its
format, then its rate, then its pair, each kept where the device takes it. An input on the default
device, or on one the host cannot read, SHALL be written as chosen.

Source: Decision (maintainer, 2026-11-20): no input the panel cannot open. audio-vue
`settings-store`: such a write is refused.

#### Scenario: Choosing the four-channel device

- **WHEN** the input is the default device at 96 kHz in 16-bit, and the user chooses the miniDSP
  2x4HD, which offers `S32_LE` alone
- **THEN** the input asked about is that device at 96 kHz in 24-bit in 32-bit

#### Scenario: Leaving the four-channel device

- **WHEN** the input measures channels 3 and 4 of a four-channel device at 96 kHz, and the user
  chooses a device that streams two channels in 16-bit up to 48 kHz
- **THEN** the input asked about is that device at 48 kHz in 16-bit, measuring channels 1 and 2

### Requirement: A capture the panel cannot open is said

While the panel waits on a capture it cannot open as configured, the Input section SHALL say the
panel is waiting for its input, with the panel's own sentence.

Source: audio-vue `capture-device` and `panel-screen`, "Unattended, a capture that will not open is
waited for": the sentence is the state's `run.screen_status` while `run.phase` is `waiting`. Found
on the proving host (2026-11-20), where the panel restarted with nothing said.

#### Scenario: A pair the device cannot stream

- **WHEN** the panel's run is waiting, saying `hw:CARD=CODEC,DEV=0 streams 2 channels; cannot take
  pair (2, 3)`
- **THEN** the Input section says the panel is waiting for its input, with that sentence

#### Scenario: Drawing

- **WHEN** the panel is drawing its scene
- **THEN** the Input section says nothing of waiting

## MODIFIED Requirements

### Requirement: The device is chosen from the host's capture devices

The device choices SHALL be the default device and the capture devices the host lists, each by the
name the host gives it. An installed device the host does not list SHALL stay chosen, marked as not
attached. Where the host lists none, the section SHALL show the host's reason.

Source: audio-vue `control-api`: `/v1/host/devices` lists the capture devices attached, each with
its name and how it streams, with why the list is empty.

#### Scenario: Two devices attached

- **WHEN** the host lists `hw:CARD=m2x4HD,DEV=0` and `hw:CARD=CODEC,DEV=0`
- **THEN** the device choices are the default device and those two

#### Scenario: The installed device is unplugged

- **WHEN** the installed device is `hw:CARD=m2x4HD,DEV=0` and the host does not list it
- **THEN** it stays chosen, marked as not attached

#### Scenario: No devices

- **WHEN** the host lists no capture devices, saying no capture device is attached
- **THEN** the only choice is the default device, beside the host's reason

### Requirement: The rate is chosen from the rates the host declares

The rate choices SHALL be the rates the host's schema declares for `input.rate`, read from the
schema and never held by the app, less those the host says the installed device does not take in
the installed format. An installed rate outside them SHALL show as it is, marked as one the host
does not offer.

Source: Decision (maintainer, 2026-11-08): the rates come from the host, as calibration's rates.
`.claude/CLAUDE.md`, "Host Versions": follow the host. audio-vue `control-api`, "Each capture
device says how it streams".

#### Scenario: The rates offered

- **WHEN** the schema declares `input.rate`'s rates as 44 100, 48 000, 88 200, 96 000 and 192 000
- **THEN** the rate choices are 44.1, 48, 88.2, 96 and 192 kHz, in that order

#### Scenario: An installed rate the host does not offer

- **WHEN** the installed rate is 32 000 Hz and the schema does not declare it
- **THEN** the section shows 32 kHz, marked as a rate the host does not offer

#### Scenario: A device that stops at 48 kHz

- **WHEN** the installed device takes 44 100 and 48 000 Hz of the declared rates
- **THEN** the rate choices are 44.1 and 48 kHz

### Requirement: The format is chosen from the formats the host declares

The capture format choices SHALL be the formats the host's schema declares for `input.fmt`, less
those the host says the installed device does not stream, each named by its bit depth, and an
unknown format by its name. An installed format outside them SHALL show as it is, marked as one the
host does not offer.

Source: audio-vue `settings-schema`: `input.fmt` declares `S16_LE`, and `S32_LE` for 24 bits in 32.
Decision (maintainer, 2026-11-09). audio-vue `control-api`, "Each capture device says how it
streams": a device's formats may include ones the panel does not capture.

#### Scenario: The formats offered

- **WHEN** the schema declares `input.fmt`'s choices as `S16_LE` and `S32_LE`
- **THEN** the capture format choices are 16-bit and 24-bit in 32-bit

#### Scenario: A device with one format

- **WHEN** the installed device streams `S32_LE` alone
- **THEN** the only capture format choice is 24-bit in 32-bit

### Requirement: A change is written to the host on the block's revision

Choosing another device, rate, format or channel pair SHALL write the `input` block to the host,
keeping every other key the block holds and naming the revision it was read at. A pair at the
schema's default SHALL be written as the key unset. Where the host refuses the write as stale, the
section SHALL read the block again, show the host's values and say they changed elsewhere. Where
the host refuses the values, the section SHALL show the host's sentences.

Source: audio-vue `settings-store`: a write names its base revision, and a stale one is refused
with the current revision; an input the attached device cannot stream is refused, naming each
setting. audio-vue `control-api`: `PUT /v1/install/{block}`.

#### Scenario: A new rate

- **WHEN** the `input` block holds `pair` `[2, 3]` at revision 4, and the user chooses 96 kHz
- **THEN** the host is sent the block with `pair` `[2, 3]` and `rate` 96 000, on revision 4

#### Scenario: A new format

- **WHEN** the `input` block holds `rate` 96 000 at revision 5, and the user chooses 24-bit in
  32-bit
- **THEN** the host is sent the block with `rate` 96 000 and `fmt` `S32_LE`, on revision 5

#### Scenario: Changed elsewhere

- **WHEN** another client wrote the `input` block after the section read it, and the user chooses a
  device
- **THEN** the write is refused as stale, and the section shows the host's current values and says
  they changed elsewhere

#### Scenario: A new pair

- **WHEN** the user chooses Channel 3 as left and Channel 4 as right
- **THEN** the host is sent the block with `pair` `[2, 3]`

#### Scenario: Refused by the device's limits

- **WHEN** the host refuses a write, saying `pair: hw:CARD=CODEC,DEV=0 streams 2 channels`
- **THEN** the section says the host refused the change, with that sentence, and shows the
  installed values
