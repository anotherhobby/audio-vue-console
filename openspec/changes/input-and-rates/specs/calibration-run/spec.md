# Spec Delta

## MODIFIED Requirements

### Requirement: Calibrate is offered only where a run can work

The Capture page SHALL offer Calibrate… while the app is paired and the panel is up, and no
run is under way. Otherwise it SHALL be disabled, saying why. The page SHALL say that calibration plays
from this Mac and works only from the machine whose output feeds the panel.

Source: `product.md`, "Calibration": the app can calibrate only from the machine feeding the panel,
and has to say so. audio-vue `control-commands`: an arm needs a running panel. Decision (maintainer,
2026-11-08): the Calibration page is renamed Capture.

#### Scenario: The panel is down

- **WHEN** the Capture page shows a paired host whose panel is down
- **THEN** Calibrate… is disabled and says the panel is not running

#### Scenario: A panel up and drawing

- **WHEN** the Capture page shows a paired host whose panel is up
- **THEN** Calibrate… is enabled, beside the note that it plays from this Mac

### Requirement: The file and the arm state the same run

The file played SHALL be rendered for the run's kind at the run's rate: the panel's installed
capture rate, as the host's install settings give it, or in a pass at every rate the rate the pass
is on (`calibration-pass`). The arm SHALL state the same kind and rate.

Source: Decision (maintainer, 2026-11-08). audio-vue `calibration-stimulus`, "A calibration
captures at the rate it calibrates"; `calibration-lifecycle`, "An arm is for one kind of run".
Decision (maintainer, 2026-11-08): calibrate at every rate in one pass.

#### Scenario: A characterization at the installed rate

- **WHEN** Calibration + Characterization starts on a panel installed at 96 000 Hz
- **THEN** a characterization file is rendered at 96 000 Hz and played, and the arm states a
  characterization at 96 000 Hz

#### Scenario: A scene capturing at another rate

- **WHEN** a calibration starts on a panel installed at 96 000 Hz whose scene on screen captures at
  48 000 Hz
- **THEN** the file is rendered and played at 96 000 Hz, and the arm states 96 000 Hz

#### Scenario: No rate installed

- **WHEN** the host's install settings name no capture rate
- **THEN** the run uses the default rate the host's settings schema declares

#### Scenario: A rate of a pass

- **WHEN** a pass at every rate reaches 44 100 Hz on a panel installed at 96 000 Hz
- **THEN** a calibration file is rendered and played at 44 100 Hz, and the arm states a calibration
  at 44 100 Hz

### Requirement: A run's ending says what became of it

The page SHALL take a run's ending from the ended calibration the panel's state names for this
run's arm, and SHALL say whether it completed, failed or expired. A completed run SHALL open its
report, unless it is a rate of a pass, and say where it cannot apply or its report was not written.
A failed run SHALL say why.

Source: Decision (maintainer, 2026-11-08). audio-vue's `calibration-from-the-app` (planned):
`control-state` names the ended calibration by arm; a failed run writes no record. `calibration-pass`:
a pass opens no report by itself.

#### Scenario: A run that completes

- **WHEN** the panel's state names the run as completed
- **THEN** the page says the run completed and opens its report

#### Scenario: A rate of a pass that completes

- **WHEN** the panel's state names a pass's 48 kHz run as completed
- **THEN** the pass keeps it as completed and opens no report

#### Scenario: A completed run not applied

- **WHEN** the panel's state names the run as completed, with its record unable to apply
- **THEN** the page says the run completed but is not in force, with the segment missing, and opens
  its report

#### Scenario: A completed run whose report failed

- **WHEN** the panel's state names the run as completed, and the host lists it with no report
- **THEN** the page says the run completed and its report was not written, with the panel's reason

#### Scenario: A failed run

- **WHEN** the panel's state names the run as failed
- **THEN** the page says the run failed and why, and opens no report

#### Scenario: An ending from an earlier arm

- **WHEN** the panel's state still names an ended calibration from an arm before this run's
- **THEN** the page takes no ending from it

#### Scenario: An arm that hears nothing

- **WHEN** the panel's state names the arm as expired, though its step passed from armed to off
  between two reads
- **THEN** the page says the panel heard no file, and to check that this Mac's output feeds the panel
