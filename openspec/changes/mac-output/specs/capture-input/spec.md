# Spec Delta

## ADDED Requirements

### Requirement: Each row names the side it sets

The Input section SHALL name the panel's rows Capture Device, Capture Rate and Capture Format, each
marked as audio-vue's, and this Mac's rows Output Device, Output Rate and Output Format, each marked
as this Mac's, followed by Synchronize Rates.

Source: Decision (maintainer, 2026-11-09).

#### Scenario: Paired

- **WHEN** the Capture page opens on a paired host
- **THEN** the section lists Capture Device (audio-vue), Capture Rate (audio-vue), Capture Format
  (audio-vue), Output Device (this Mac), Output Rate (this Mac), Output Format (this Mac) and
  Synchronize Rates, in that order

### Requirement: The format is chosen from the formats the host declares

The capture format choices SHALL be the formats the host's schema declares for `input.fmt`, each
named by its bit depth, and an unknown format by its name. An installed format outside them SHALL
show as it is, marked as one the host does not offer.

Source: audio-vue `settings-schema`: `input.fmt` declares `S16_LE`, and `S32_LE` for 24 bits in 32.
Decision (maintainer, 2026-11-09).

#### Scenario: The formats offered

- **WHEN** the schema declares `input.fmt`'s choices as `S16_LE` and `S32_LE`
- **THEN** the capture format choices are 16-bit and 24-bit in 32-bit

### Requirement: A 16-bit capture is flagged

Where the capture format is `S16_LE`, the section SHALL say that it limits the noise floor the panel
can read.

Source: Decision (maintainer, 2026-11-09).

#### Scenario: The schema's default

- **WHEN** the `input` block has never been written
- **THEN** Capture Format shows 16-bit, flagged as limiting the noise floor the panel can read

## MODIFIED Requirements

### Requirement: The Input section shows the installed device and rate

While paired, the Capture page's Input section SHALL show the panel's capture device, rate and
format as the host's `input` install block holds them, a key it lacks as the schema's default, and
an unset device as the default device.

Source: audio-vue `settings-store` (a block is on its defaults until written) and `settings-schema`
(`input.device` unset is the default device). Decision (maintainer, 2026-11-08): on Capture.
Decision (maintainer, 2026-11-09): the format too.

#### Scenario: A block never written

- **WHEN** the Capture page opens on a paired host whose `input` block has never been written
- **THEN** it shows the default device, the schema's default rate, `48 kHz`, and the schema's
  default format, 16-bit

### Requirement: A change is written to the host on the block's revision

Choosing another device, rate or format SHALL write the `input` block to the host, keeping every
other key the block holds and naming the revision it was read at. Where the host refuses the write
as stale, the section SHALL read the block again, show the host's values and say they changed
elsewhere.

Source: audio-vue `settings-store`: a write names its base revision, and a stale one is refused
with the current revision. audio-vue `control-api`: `PUT /v1/install/{block}`.

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

### Requirement: A change asks first while the panel runs

Unless the panel is down, choosing another device, rate or format SHALL ask before writing, saying
the panel restarts. Declining SHALL write nothing and show the installed value again. After a
write, the section SHALL show what the host says the change does to calibration.

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
device, rate and format SHALL be disabled, saying a calibration is running. A write the host refuses
SHALL show the host's reason and the installed values.

Source: audio-vue `settings-store`: a chain write is refused while a calibration has the panel.

#### Scenario: A pass under way

- **WHEN** a calibration at every rate is under way
- **THEN** the device, rate and format are disabled, saying a calibration is running

#### Scenario: Refused by the host

- **WHEN** another client arms the panel just as the user chooses a rate, and the host refuses the
  write
- **THEN** the section shows the host's reason and the installed rate

### Requirement: The hold after a calibration is explained

While the panel holds the calibration scene after a run has ended, the Input section SHALL say that
the panel shows the last run's result at the rate it captures at, and returns to its scene and
installed input when audio plays. The device, rate and format SHALL stay disabled.

Source: audio-vue `calibration-lifecycle`, "A finished run holds the screen until audio returns".
Decision (maintainer, 2026-11-09).

#### Scenario: After a pass of every rate

- **WHEN** a pass has ended with its 192 kHz run, the panel installed at 96 kHz and no audio playing
- **THEN** the section says the panel shows the last run's result at 192 kHz and returns to its
  input when audio plays, with the device, rate and format disabled
