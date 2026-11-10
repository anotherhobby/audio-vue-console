# Spec Delta

## ADDED Requirements

### Requirement: Calibrate… warns about an output at 16 bits

Where the chosen output offers no format deeper than 16 bits at a rate the run covers, Calibrate…
SHALL say that the record's noise floor will be the output's 16 bits rather than the chain's.

Source: audio-vue `cal-play.md`, "The float32 path is bit-perfect": it holds for a device at 24 bits
or more. Decision (maintainer, 2026-11-09).

#### Scenario: A 16-bit output

- **WHEN** the chosen output offers only 16-bit Integer at 96 kHz, and Calibrate… is opened for a
  run at 96 kHz
- **THEN** Calibrate… says the record's noise floor will be the output's 16 bits, and Start stays
  enabled

## MODIFIED Requirements

### Requirement: The rate is set before the arm

The app SHALL set the output device to the run's rate, and to the deepest integer format it offers
at that rate, with `cal-play`'s rate command, and wait for it to end, before it arms the panel. A
change of either SHALL be left to settle for as long as `cal-play` holds it.

Source: audio-vue `calibration-lifecycle` (the settle, and the deepest integer format) and
`control-api` (a calibration's order). `pitfalls.md`. Decision (maintainer, 2026-11-09).

#### Scenario: The device at another rate

- **WHEN** a run at 96 000 Hz starts and the device is at 48 000 Hz
- **THEN** the device is set to 96 000 Hz, the chain settles, and only then is the panel armed

#### Scenario: The device at 16 bits

- **WHEN** a run at 96 000 Hz starts, and the device is at 96 000 Hz and 16-bit Integer and offers
  24-bit Integer
- **THEN** the device is set to 24-bit Integer, the chain settles, and only then is the panel armed

#### Scenario: The device already at the rate

- **WHEN** a run at 96 000 Hz starts and the device is at 96 000 Hz and its deepest integer format
- **THEN** the panel is armed with no wait
