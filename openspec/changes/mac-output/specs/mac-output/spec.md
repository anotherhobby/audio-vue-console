# Spec Delta

## Purpose

This Mac's output on the Capture page: the device that feeds the panel, its rate and bit depth as
Core Audio holds them, and keeping its rate the panel's capture rate, so that the path the panel
measures stays the path that was calibrated.

## ADDED Requirements

### Requirement: The output feeding the panel is chosen in the Input section

While the Input section shows the panel's input, it SHALL show Output Device (this Mac), chosen from
this Mac's output devices and remembered for the panel. A remembered device this Mac no longer lists
SHALL leave none chosen.

Source: Decision (maintainer, 2026-11-09): the output's picker moves from Calibrate… to the Input
section. `product.md`, "The model": the app never assumes where a panel runs.

#### Scenario: Chosen before

- **WHEN** `D10s` was chosen for panel `audio-vue`, and the Capture page opens on it
- **THEN** Output Device shows `D10s`

#### Scenario: The device is gone

- **WHEN** the device remembered for the panel is not among this Mac's outputs
- **THEN** no output device is chosen, and Output Rate and Output Format show nothing

### Requirement: The output's rate and format are shown as Core Audio holds them

Output Rate (this Mac) and Output Format (this Mac) SHALL show the chosen device's rate and bit depth
as Core Audio reports them, and SHALL follow a change made outside the app.

Source: Decision (maintainer, 2026-11-09).

#### Scenario: Changed in Audio MIDI Setup

- **WHEN** the output is at 96 kHz and the user sets it to 48 kHz in Audio MIDI Setup
- **THEN** Output Rate shows 48 kHz without the page being opened again

### Requirement: The output rate is chosen from the host's rates the output offers

The output rate choices SHALL be the rates the host's schema declares for `input.rate` that the
device offers. A device rate outside them SHALL show as it is, marked as not one the panel captures
at.

Source: Decision (maintainer, 2026-11-09). `capture-input`: the rates come from the host.

#### Scenario: An output without 192 kHz

- **WHEN** the host declares 44.1, 48, 88.2, 96 and 192 kHz, and the device offers 44.1 to 96 kHz
- **THEN** the output rate choices are 44.1, 48, 88.2 and 96 kHz

#### Scenario: A rate the panel does not capture at

- **WHEN** the device is at 384 kHz
- **THEN** Output Rate shows 384 kHz, marked as a rate the panel does not capture at

### Requirement: The output format is chosen from the formats the output offers

The output format choices SHALL be the formats the device offers at its current rate, each named by
its bit depth and whether it is integer or float.

Source: Decision (maintainer, 2026-11-09). Audio MIDI Setup names a format the same way.

#### Scenario: A USB DAC

- **WHEN** the device offers 16-bit, 24-bit and 32-bit integer formats at its rate
- **THEN** the output format choices are 16-bit Integer, 24-bit Integer and 32-bit Integer

### Requirement: Choosing the output's rate or format sets the device at once

Choosing an output rate or format SHALL set the device to it, without waiting for the chain to
settle. A device that refuses SHALL show why, with the device's values read again.

Source: Decision (maintainer, 2026-11-09): only an arm waits for the chain to settle.

#### Scenario: A new format

- **WHEN** the device is at 16-bit Integer and the user chooses 24-bit Integer
- **THEN** the device is set to 24-bit Integer and Output Format shows it

#### Scenario: Refused

- **WHEN** Core Audio refuses the rate chosen
- **THEN** the section says the output was not changed and why, and shows the device's rate

### Requirement: Synchronize Rates is remembered for each panel

The section SHALL offer Synchronize Rates, on until the user turns it off, and remembered for each
panel.

Source: Decision (maintainer, 2026-11-09).

#### Scenario: A panel not seen before

- **WHEN** the Capture page opens on a panel for the first time
- **THEN** Synchronize Rates is on

#### Scenario: Turned off

- **WHEN** the user turns Synchronize Rates off for panel `audio-vue`, and opens it again later
- **THEN** Synchronize Rates is off for `audio-vue`

### Requirement: A synchronized output follows the capture rate

While Synchronize Rates is on, turning it on or storing a new capture rate SHALL set the output to
the capture rate where the output offers it. A capture write that is declined or refused SHALL leave
the output as it is.

Source: Decision (maintainer, 2026-11-09): the capture rate leads.

#### Scenario: A new capture rate

- **WHEN** Synchronize Rates is on, the output is at 48 kHz and the host stores 96 kHz
- **THEN** the output is set to 96 kHz

#### Scenario: Declined

- **WHEN** Synchronize Rates is on, the user chooses 96 kHz and declines the restart
- **THEN** neither the capture rate nor the output changes

### Requirement: A synchronized output rate is written to the panel

While Synchronize Rates is on, choosing an output rate SHALL write that capture rate first, asking
before a restart as a capture change does, and SHALL set the output only once the host stores it.

Source: Decision (maintainer, 2026-11-09). `capture-input`, "A change asks first while the panel
runs".

#### Scenario: The output rate chosen

- **WHEN** Synchronize Rates is on, the panel is up, and the user chooses 88.2 kHz for the output
- **THEN** the user is asked before the panel restarts, and on yes the host stores 88.2 kHz and then
  the output is set to it

### Requirement: A change made elsewhere is not followed

The app SHALL change neither side when the output's rate is changed outside the app or the capture
rate is changed by another client. The two SHALL then show as mismatched.

Source: Decision (maintainer, 2026-11-09).

#### Scenario: Audio MIDI Setup

- **WHEN** Synchronize Rates is on, both are at 96 kHz, and the user sets the output to 48 kHz in
  Audio MIDI Setup
- **THEN** the capture rate stays 96 kHz, and the section shows the mismatch

### Requirement: A rate mismatch is shown

Where an output is chosen and its rate differs from the capture rate, the section SHALL say that
the panel captures at one rate while this Mac plays at another. Where the output cannot play the
capture rate, it SHALL say that instead.

Source: audio-vue `calibration-design.md`, "We calibrate the composite path": a calibration measures
the path from the file to the capture. Decision (maintainer, 2026-11-09).

#### Scenario: Different rates

- **WHEN** the output is at 48 kHz and the panel captures at 96 kHz
- **THEN** the section says this Mac plays at 48 kHz while the panel captures at 96 kHz

#### Scenario: A rate the output cannot play

- **WHEN** the panel captures at 192 kHz and the output offers nothing above 96 kHz
- **THEN** the section says this output cannot play the capture rate, 192 kHz

### Requirement: An output below 24 bits is flagged

Where the output's format is under 24 bits, the section SHALL say that it limits the noise floor the
panel can read.

Source: audio-vue `cal-play.md`, "The float32 path is bit-perfect": the player's bit-perfect claim
holds for a device at 24 bits or more.

#### Scenario: 16 bits

- **WHEN** the output is at 16-bit Integer
- **THEN** Output Format is flagged as limiting the noise floor the panel can read

### Requirement: The output cannot change during a calibration

While the Input section's capture values are disabled for a calibration, the output's device, rate,
format and Synchronize Rates SHALL be disabled too.

Source: `calibration-player`: the run sets the output's rate and format.

#### Scenario: A pass under way

- **WHEN** a calibration at every rate is under way
- **THEN** Output Device, Output Rate, Output Format and Synchronize Rates are disabled

### Requirement: A synchronized output returns to the capture rate after a calibration

When a calibration from this app ends with Synchronize Rates on, the output SHALL be set to the
capture rate where it is not already at it.

Source: Decision (maintainer, 2026-11-09), revising the one of 2026-11-08 that left the output at
the last rate played. audio-vue `calibration-lifecycle`: the hold ends only on a held level, so
setting the rate does not end it.

#### Scenario: After a pass of every rate

- **WHEN** a pass ends with its 192 kHz run, the panel captures at 96 kHz, and Synchronize Rates is
  on
- **THEN** the output is set to 96 kHz

#### Scenario: Not synchronized

- **WHEN** a pass ends with its 192 kHz run and Synchronize Rates is off
- **THEN** the output stays at 192 kHz
