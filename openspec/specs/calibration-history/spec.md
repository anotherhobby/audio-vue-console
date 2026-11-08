# calibration-history Specification

## Purpose

What the Calibration page shows of the panel's calibration and its past runs: the calibration in
force, the host's runs, and a run's report read in the app.

## Requirements

### Requirement: The page shows the calibration in force

The Calibration page SHALL show, from the panel's live state, whether a calibration is in force, the
run it comes from, named as the runs list names it, its age, its trim and its noise floor, and why
none applies where none does. A value not read SHALL show `—`.

Source: audio-vue `control-state`, "The state says which reference frame the readings are in".
`panel-window`, "A value not read shows a dash".

#### Scenario: Calibrated

- **WHEN** the panel's state names run `2026-10-25T23-16-08Z`, 14 days old, trimming +0.01 dB
- **THEN** the page shows it calibrated by that run, by its start in the Mac's time zone as the
  runs list shows it, 14 days ago, with a trim of +0.01 dB

#### Scenario: The panel is down

- **WHEN** the panel is down
- **THEN** every value of the calibration in force is `—`

### Requirement: The page lists the host's runs

The page SHALL list the host's calibration runs, newest first, each by its date and time in the
Mac's time zone, its kind (a characterization as Calibration + Characterization), and whether it
has a report. The list SHALL be read when the page opens and when a
run ends, and SHALL show with the panel down.

Source: audio-vue `control-api`, "Calibration runs are served from their files". Decision
(maintainer, 2026-11-08): the runs live on this page, with each run's kind.

#### Scenario: Runs with the panel stopped

- **WHEN** the page opens on a paired host whose panel is stopped
- **THEN** it lists the host's runs, newest first

#### Scenario: A run whose id is not a time

- **WHEN** the host lists a run whose id is not a date and time
- **THEN** the run is listed by its id

### Requirement: A run's report is read in the app

Opening a run with a report SHALL show its HTML report in the app, as the host wrote it, and a
report SHALL reach nothing on the network. A run
with no report SHALL say it has none.

Source: Decision (maintainer, 2026-11-08): reports are read in the app. `product.md`, "The app": HTML
reports stay HTML (Recommended). `app-boundaries`, "The UI does no networking". audio-vue's reply
(2026-11-08): a report's stylesheet is inline, its charts inline SVG, and it has no links.

#### Scenario: Opening a report

- **WHEN** the user opens a run that has a report
- **THEN** its report shows in the app, fetched from the host

#### Scenario: A run with no report yet

- **WHEN** the user opens a run the host lists with no report
- **THEN** the page says the run has no report, and fetches nothing
