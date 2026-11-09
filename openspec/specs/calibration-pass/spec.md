# calibration-pass Specification

## Purpose

A calibration at every rate in one pass, so the host keeps a record for each rate. Covers which
rates a pass runs and in what order, the rates it skips, how it goes on past a failure, and its
progress, cancel and summary.

## Requirements

### Requirement: Calibrate… offers a calibration at every rate

Calibrate… SHALL offer a calibration at the installed rate or at every rate. Every rate SHALL be
offered for a calibration only, and choosing Calibration + Characterization SHALL choose the
installed rate.

Source: Decision (maintainer, 2026-11-08): calibrate at every rate in one go, for calibration only.

#### Scenario: Nothing changed

- **WHEN** Calibrate… is opened
- **THEN** the run is a calibration at the installed rate, with every rate offered beside it

#### Scenario: A characterization

- **WHEN** Calibration + Characterization is chosen
- **THEN** every rate cannot be chosen, and the run is at the installed rate

### Requirement: A pass runs the host's rates, lowest first

A pass SHALL run one calibration at each rate the host's schema declares for `input.rate`, from the
lowest to the highest, each starting only after the one before has ended.

Source: Decision (maintainer, 2026-11-08): start at 44.1, calibrate, step up, repeat until done; the
rates come from the host.

#### Scenario: Five rates

- **WHEN** the host declares 44 100, 48 000, 88 200, 96 000 and 192 000 Hz, and a pass starts
- **THEN** it calibrates at 44.1 kHz, then 48, 88.2, 96 and 192 kHz, one after another

### Requirement: Each rate of a pass is a run

Each rate of a pass SHALL be a calibration as `calibration-run` defines a run, stating that rate:
rendered, the output's rate set and settled, armed and played in that order, followed to its
ending, cancelled by Cancel, and asked about before a quit or a switch of panel.

Source: `calibration-run`. audio-vue `calibration-stimulus`: a run armed at a stated rate captures
at it and returns to the installed rate after.

#### Scenario: The second rate

- **WHEN** a pass's 44.1 kHz run has ended
- **THEN** a file is rendered at 48 kHz, the output set to 48 kHz and settled, the panel armed for a
  calibration at 48 kHz, and the file played

#### Scenario: The install is left alone

- **WHEN** a pass completes on a panel installed at 96 kHz
- **THEN** the host's `input` block is as it was, and the panel captures at 96 kHz again once the
  hold after the last run ends

### Requirement: A pass skips the rates the output cannot play

Before Start, Calibrate… SHALL name the rates that this Mac's chosen output does not offer, which
the pass skips. A pass SHALL play nothing at a skipped rate, and SHALL not start where the output
offers none of the host's rates.

Source: Recommended: a rate the output cannot be set to fails before the arm (`calibration-player`),
so it is known before Start.

#### Scenario: An output without 192 kHz

- **WHEN** every rate is chosen on an output offering 44.1 to 96 kHz
- **THEN** Calibrate… says 192 kHz will be skipped, and the pass calibrates the other four

#### Scenario: No rate in common

- **WHEN** every rate is chosen on an output offering none of the host's rates
- **THEN** Start is disabled, saying the output offers none of them

### Requirement: A pass goes on past a failed rate

Where a rate's run fails, expires, is refused or its player fails, the pass SHALL keep that rate's
ending and go on to the next rate. Only Cancel, a lost pairing or the panel going down SHALL end a
pass before its last rate.

Source: Decision (maintainer, 2026-11-08): the pass goes on to the next rate.

#### Scenario: One rate expires

- **WHEN** the 88.2 kHz run expires with the panel hearing nothing
- **THEN** the pass goes on to 96 kHz, and keeps 88.2 kHz as expired

#### Scenario: The panel goes down

- **WHEN** the panel goes down during the 96 kHz run
- **THEN** the pass ends after that run's ending, and runs no further rate

### Requirement: A pass shows which rate it is on

While a pass is under way, the page SHALL show the rate it is on, its place among the rates the
pass runs, and the run's step as `calibration-run` shows it.

Source: Recommended: a pass of five runs is long, and its step alone does not say how far it has
gone.

#### Scenario: The third rate

- **WHEN** a pass of five rates is playing its 88.2 kHz file
- **THEN** the page shows 88.2 kHz, rate 3 of 5, playing with its time left

### Requirement: Cancel ends the whole pass

Cancel during a pass SHALL cancel the rate under way, as `calibration-run` cancels a run, and SHALL
run no further rate. The rates already ended SHALL keep their endings.

Source: Decision (maintainer, 2026-11-08): only Cancel stops the whole pass.

#### Scenario: Cancel at 96 kHz

- **WHEN** the user cancels while the 96 kHz file plays
- **THEN** playback stops, the host is sent a cancel, 192 kHz is not run, and the three rates before
  keep their endings

### Requirement: A pass ends with each rate's outcome

When a pass ends, the page SHALL list each rate it was to run, with that rate's ending as
`calibration-run` words it, or skipped, or not run. Each completed rate with a report SHALL offer
it. The pass SHALL open no report by itself, and SHALL read the host's runs again.

Source: Recommended: five reports opened one over another would hide the summary.

#### Scenario: Four calibrated, one skipped

- **WHEN** a pass completes at 44.1, 48, 88.2 and 96 kHz and skipped 192 kHz
- **THEN** the page lists four rates completed, each offering its report, and 192 kHz skipped, and
  the runs list shows the four new runs

#### Scenario: A cancelled pass

- **WHEN** a pass is cancelled at 48 kHz
- **THEN** the page lists 44.1 kHz with its ending, 48 kHz cancelled, and the rest not run
