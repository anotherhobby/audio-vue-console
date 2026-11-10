# calibration-player Specification

## Purpose

How the app carries and runs audio-vue's `cal-play`, the player that sets an output device's rate
and plays the calibration file bit-perfectly: how it is built into the app, run, read and stopped.

## Requirements

### Requirement: The app carries cal-play built from audio-vue

The app SHALL carry `cal-play` built from the audio-vue checkout's `cal-play/` when the app is built,
inside the app's bundle and signed with it. A build SHALL fail, saying how to fix it, when the
checkout or the Rust toolchain is missing.

Source: `product.md`, "Calibration": `cal-play` goes in the app as a helper binary (Recommended).
Decision (maintainer, 2026-11-08): the app does not reimplement playback.

#### Scenario: A build

- **WHEN** the app is built beside an audio-vue checkout
- **THEN** the built app holds a `cal-play` built from that checkout's sources

#### Scenario: No toolchain

- **WHEN** the app is built on a machine with no Rust toolchain
- **THEN** the build fails and says that `cal-play` needs one to build

### Requirement: cal-play runs as a child of the app

The app SHALL run the `cal-play` it carries as a child process, one at a time, and SHALL end a
running one when its run is cancelled or the app quits. The app SHALL run no player it received from a
host.

Source: `render-helper`, "The helper is a child of the app", applied to the player. audio-vue's
`cal-play.md`: the player runs on the playback machine.

#### Scenario: Quitting during a run

- **WHEN** the app quits while `cal-play` is playing
- **THEN** `cal-play` is ended and nothing keeps playing

#### Scenario: A second run while one plays

- **WHEN** a run is asked for while `cal-play` is running for another
- **THEN** the second is refused, and the first plays on

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

### Requirement: A player's failure is read and shown

The app SHALL treat a `cal-play` that exits non-zero as a failure, and SHALL show the reason it
wrote to its error output, such as a device not found, a name matching more than one device, or a
rate the device does not offer.

Source: audio-vue's `cal-play`: every failure exits 1 and writes its reason to standard error.

#### Scenario: A rate the device does not offer

- **WHEN** the device chosen does not offer the run's rate
- **THEN** the run stops before the arm, and shows `cal-play`'s reason

#### Scenario: The device is unplugged during playback

- **WHEN** `cal-play` exits non-zero part-way through playing
- **THEN** the run says playback failed, with `cal-play`'s reason, and cancels the panel's run

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
