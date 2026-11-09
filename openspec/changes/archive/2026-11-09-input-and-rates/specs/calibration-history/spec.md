# Spec Delta

## MODIFIED Requirements

### Requirement: The page shows the calibration in force

The Capture page SHALL show, from the panel's live state, whether a calibration is in force, the
run it comes from, named as the runs list names it, its age, its trim and its noise floor, and why
none applies where none does. A value not read SHALL show `—`.

Source: audio-vue `control-state`, "The state says which reference frame the readings are in".
`panel-window`, "A value not read shows a dash". Decision (maintainer, 2026-11-08): the Calibration
page is renamed Capture.

#### Scenario: Calibrated

- **WHEN** the panel's state names run `2026-10-25T23-16-08Z`, 14 days old, trimming +0.01 dB
- **THEN** the page shows it calibrated by that run, by its start in the Mac's time zone as the
  runs list shows it, 14 days ago, with a trim of +0.01 dB

#### Scenario: The panel is down

- **WHEN** the panel is down
- **THEN** every value of the calibration in force is `—`

### Requirement: The page lists the host's runs

The page SHALL list the host's calibration runs under Calibration History, newest first, each with
its date and time in the Mac's time zone, its kind (a characterization as Calibration +
Characterization), its rate and whether it has a report. It SHALL read them when the page opens and
when a run ends, and show them with the panel down.

Source: audio-vue `control-api`, "Calibration runs are served from their files";
`calibration-record`. Decisions (maintainer, 2026-11-08).

#### Scenario: Runs with the panel stopped

- **WHEN** the page opens on a paired host whose panel is stopped
- **THEN** it lists the host's runs, newest first

#### Scenario: A run whose id is not a time

- **WHEN** the host lists a run whose id is not a date and time
- **THEN** the run is listed by its id

#### Scenario: Each run's rate

- **WHEN** the host lists a calibration captured at 96 000 Hz and one at 44 100 Hz
- **THEN** the first shows `96 kHz` and the second `44.1 kHz`, beside each run's kind

#### Scenario: A run with no rate

- **WHEN** the host lists a run without its rate
- **THEN** the run shows `—` for its rate
