# Spec Delta

## Purpose

The Capture page's Input section: which capture device the panel listens to and the rate it
captures at. Both are read from and written to the host's install settings, and each rate shows
whether a calibration holds for it.

## ADDED Requirements

### Requirement: The Input section shows the installed device and rate

While paired, the Capture page's Input section SHALL show the panel's capture device and rate as
the host's `input` install block holds them, a key it lacks as the schema's default, and an unset
device as the default device.

Source: audio-vue `settings-store` (a block is on its defaults until written) and `settings-schema`
(`input.device` unset is the default device). Decision (maintainer, 2026-11-08): on Capture.

#### Scenario: A block never written

- **WHEN** the Capture page opens on a paired host whose `input` block has never been written
- **THEN** it shows the default device and the schema's default rate, `48 kHz`

### Requirement: The Input section shows nothing while not paired

While not paired, the Input section SHALL say to pair and show no device or rate.

Source: `panel-window`: pages show no sample values once built.

#### Scenario: Not paired

- **WHEN** the Capture page opens on a host the app is not paired with
- **THEN** it says to pair with the panel to set its input, and shows no device or rate

### Requirement: The device is chosen from the host's capture devices

The device choices SHALL be the default device and the capture devices the host lists, each by the
name the host gives it. An installed device the host does not list SHALL stay chosen, marked as not
attached. Where the host lists none, the section SHALL show the host's reason.

Source: audio-vue `control-api`: `/v1/host/devices` lists the capture devices attached, with why
the list is empty.

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
schema and never held by the app. An installed rate outside them SHALL show as it is, marked as
one the host does not offer.

Source: Decision (maintainer, 2026-11-08): the rates come from the host, as calibration's rates.
`.claude/CLAUDE.md`, "Host Versions": follow the host.

#### Scenario: The rates offered

- **WHEN** the schema declares `input.rate`'s rates as 44 100, 48 000, 88 200, 96 000 and 192 000
- **THEN** the rate choices are 44.1, 48, 88.2, 96 and 192 kHz, in that order

#### Scenario: An installed rate the host does not offer

- **WHEN** the installed rate is 32 000 Hz and the schema does not declare it
- **THEN** the section shows 32 kHz, marked as a rate the host does not offer

### Requirement: Each rate says whether a calibration holds for it

Each rate choice SHALL say whether a valid calibration holds for it on the installed device, as
calibrated or stale, or that none does, as the host reports it per rate. Where the host's report
cannot be read, the section SHALL show no calibration marks.

Source: Decision (maintainer, 2026-11-08): a scene may capture at any calibrated rate. audio-vue
`calibration-record`: the newest valid record for device and rate is in force. Asked for in
`scene-settings-handoff.md`.

#### Scenario: Calibrated at two rates

- **WHEN** the host reports valid calibrations at 48 000 and 96 000 Hz for the installed device
- **THEN** 48 and 96 kHz say calibrated, and the other rates say not calibrated

#### Scenario: Another device chosen

- **WHEN** a new device is written and the host reports no calibration for it
- **THEN** every rate says not calibrated

### Requirement: A change is written to the host on the block's revision

Choosing another device or rate SHALL write the `input` block to the host, keeping every other key
the block holds and naming the revision it was read at. Where the host refuses the write as stale,
the section SHALL read the block again, show the host's values and say they changed elsewhere.

Source: audio-vue `settings-store`: a write names its base revision, and a stale one is refused
with the current revision. audio-vue `control-api`: `PUT /v1/install/{block}`.

#### Scenario: A new rate

- **WHEN** the `input` block holds `pair` `[2, 3]` at revision 4, and the user chooses 96 kHz
- **THEN** the host is sent the block with `pair` `[2, 3]` and `rate` 96 000, on revision 4

#### Scenario: Changed elsewhere

- **WHEN** another client wrote the `input` block after the section read it, and the user chooses a
  device
- **THEN** the write is refused as stale, and the section shows the host's current values and says
  they changed elsewhere

### Requirement: A change asks first while the panel runs

Unless the panel is down, choosing another device or rate SHALL ask before writing, saying the
panel restarts. Declining SHALL write nothing and show the installed value again. After a write,
the section SHALL show what the host says the change does to calibration.

Source: audio-vue `settings-store`: a chain write restarts a running panel. audio-vue `control-api`:
the write's answer says what a chain change does to calibration.

#### Scenario: Declining

- **WHEN** the panel is up, the user chooses 192 kHz and declines when asked
- **THEN** nothing is written and the section shows the installed rate

#### Scenario: The panel stopped

- **WHEN** the panel is stopped and the user chooses another device
- **THEN** it is written without asking

#### Scenario: After a rate change

- **WHEN** the user chooses 96 kHz and the host stores it
- **THEN** the section shows the host's words on what the change does to calibration

### Requirement: Input cannot change during a calibration

While a calibration from this app is under way, or the panel's calibration state is not off, the
device and rate SHALL be disabled, saying a calibration is running. A write the host refuses SHALL
show the host's reason and the installed values.

Source: audio-vue `settings-store`: a chain write is refused while a calibration has the panel.

#### Scenario: A pass under way

- **WHEN** a calibration at every rate is under way
- **THEN** the device and rate are disabled, saying a calibration is running

#### Scenario: Refused by the host

- **WHEN** another client arms the panel just as the user chooses a rate, and the host refuses the
  write
- **THEN** the section shows the host's reason and the installed rate

### Requirement: The hold after a calibration is explained

While the panel holds the calibration scene after a run has ended, the Input section SHALL say that
the panel shows the last run's result at the rate it captures at, and returns to its scene and
installed input when audio plays. The device and rate SHALL stay disabled.

Source: audio-vue `calibration-lifecycle`, "A finished run holds the screen until audio returns".
Decision (maintainer, 2026-11-09).

#### Scenario: After a pass of every rate

- **WHEN** a pass has ended with its 192 kHz run, the panel installed at 96 kHz and no audio playing
- **THEN** the section says the panel shows the last run's result at 192 kHz and returns to its
  input when audio plays, with the device and rate disabled

### Requirement: Return to Scene ends the hold

During the hold, the Input section SHALL offer Return to Scene, which sends the panel a cancel. The
hold SHALL end with the run's record kept. A cancel the panel refuses SHALL show its words.

Source: audio-vue `calibration-lifecycle` (a cancel ends the hold) and `control-commands` (a cancel
during the hold keeps the record). Decision (maintainer, 2026-11-09).

#### Scenario: Returning to the scene

- **WHEN** the user chooses Return to Scene during the hold
- **THEN** the panel is sent a cancel, the hold ends with the record kept, and the device and rate
  can be chosen again
