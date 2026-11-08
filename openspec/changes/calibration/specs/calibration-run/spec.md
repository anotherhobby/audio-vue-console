# Spec Delta

## Purpose

How the app runs a calibration of the panel from the Mac feeding it: what a run states, where its
file comes from, the order of its steps, how it is followed and cancelled, and what each ending says.

## ADDED Requirements

### Requirement: Calibrate is offered only where a run can work

The Calibration page SHALL offer Calibrate… while the app is paired and the panel is up, and no
run is under way. Otherwise it SHALL be disabled, saying why. The page SHALL say that calibration plays
from this Mac and works only from the machine whose output feeds the panel.

Source: `product.md`, "Calibration": the app can calibrate only from the machine feeding the panel,
and has to say so. audio-vue `control-commands`: an arm needs a running panel.

#### Scenario: The panel is down

- **WHEN** the Calibration page shows a paired host whose panel is down
- **THEN** Calibrate… is disabled and says the panel is not running

#### Scenario: A panel up and drawing

- **WHEN** the Calibration page shows a paired host whose panel is up
- **THEN** Calibrate… is enabled, beside the note that it plays from this Mac

### Requirement: A run names the output device feeding the panel

Calibrate… SHALL ask for the output device to play through, from this Mac's output devices, and SHALL
remember the device chosen for each panel, offering it first the next time.

Source: Recommended. `product.md`, "The model": the app never assumes where a panel runs, so it
cannot know which output feeds it.

#### Scenario: The second run on a panel

- **WHEN** a run on panel `audio-vue` played through `D10s`, and Calibrate… is chosen again
- **THEN** `D10s` is chosen already

#### Scenario: The device remembered is gone

- **WHEN** the device remembered for a panel is not among this Mac's outputs
- **THEN** no device is chosen, and the run cannot start until one is

### Requirement: A run is a calibration, or a calibration with a characterization

A run SHALL be a calibration unless Calibration + Characterization is chosen, and the app SHALL name
a characterization as Calibration + Characterization, since it runs the calibration too. A run SHALL
state nothing it cannot measure.

Source: Decision (maintainer, 2026-11-08): no maximum input level or folding frequency is stated,
replacing the same day's Advanced section; a characterization is named with the calibration it
includes. audio-vue `calibration-stimulus`, "There are two runs".

#### Scenario: Nothing chosen

- **WHEN** Calibrate… starts a run with nothing changed
- **THEN** the run is a calibration, stating its kind and rate alone

#### Scenario: The choice

- **WHEN** Calibrate… is opened
- **THEN** it offers Calibration and Calibration + Characterization

### Requirement: Calibrate… warns before anything plays

Above Start, Calibrate… SHALL say in a warning colour that the computer's volume should be at
maximum, and that amplifiers or speakers downstream should be muted or turned down very low, since
the run plays full-scale tones that will damage speakers.

Source: Decision (maintainer, 2026-11-08), with the wording the maintainer gave.

#### Scenario: Opening Calibrate…

- **WHEN** Calibrate… is opened
- **THEN** both warnings show above Start, in orange

### Requirement: The file and the arm state the same run

The file played SHALL be rendered for the run's kind at the panel's installed capture rate, as the
host's install settings give it. The arm SHALL state the same kind and rate.

Source: Decision (maintainer, 2026-11-08). audio-vue `calibration-stimulus`, "A calibration
captures at the rate it calibrates"; `calibration-lifecycle`, "An arm is for one kind of run".

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

### Requirement: The stimulus is rendered from the code the panel runs

The app SHALL render the stimulus with the audio-vue code it carries, and only while that code's
digest is the panel's. A rendered file SHALL be rendered whole before the run goes on and removed
once the run ends.

Source: Decision (maintainer, 2026-11-08): render locally, since the bundle holds the writer and
the digest check guarantees the panel listens for the same file. `card-code`: the app compares its
code's digest with the panel's.

#### Scenario: The app's code differs from the panel's

- **WHEN** the card code the app carries differs from the panel's
- **THEN** Calibrate… is disabled, saying the app and the panel run different audio-vue code

#### Scenario: A rate a calibration has no schedule for

- **WHEN** the installed capture rate is one a calibration cannot run at
- **THEN** the run ends before the device's rate is set, saying why

#### Scenario: The run ends

- **WHEN** a run that played a rendered file ends, however it ends
- **THEN** the file is gone from the app's container

### Requirement: A run's steps go in calibration's order

A run SHALL render its file, set the device's rate and let the chain settle, arm the panel, and play
the file only once the arm is done, each step after the one before ends.

Source: audio-vue `control-api`, "The contract states a calibration's order"; audio-vue
`control-commands`, "An arm that hears nothing ends itself": a wait after the arm spends its
deadline.

#### Scenario: A run from start to finish

- **WHEN** a calibration starts with the device at another rate than the file's
- **THEN** the file is rendered, the device's rate set and the chain settled, the panel armed, and
  the file played, in that order

### Requirement: A refused arm plays nothing

Where the host answers an arm with anything but done, the run SHALL end without playing, and SHALL
show the host's reason.

Source: audio-vue `control-commands`, "Arming never cancels": a different arm while one listens, or
an arm while a run is capturing, is refused with the reason.

#### Scenario: Another run is listening

- **WHEN** the panel is already armed by another client for a characterization, and this app arms a
  calibration
- **THEN** nothing plays, and the run shows the host's reason, which says to cancel first

### Requirement: The run shows where it is

While a run is under way, the page SHALL show its step: rendering, settling, armed,
playing with its time left, then measuring and analysing as the panel's calibration state reports
them. The page SHALL NOT take a run's ending from that state's step.

Source: Decision (maintainer, 2026-11-08). audio-vue's reply (2026-11-08): an ended run's word
passes to `off`, an expiry possibly between two reads.

#### Scenario: The marker heard

- **WHEN** the panel's calibration state moves from listening to the marker heard, then running
- **THEN** the page shows the run measuring for both

#### Scenario: The panel analysing

- **WHEN** the file has finished playing and the panel's calibration state is analysing
- **THEN** the page shows the run analysing

### Requirement: Cancel stops a run at any step

Every step of a run SHALL offer Cancel. Before the arm, Cancel SHALL stop the step and arm nothing.
After the arm, Cancel SHALL stop playback and send the host's cancel, and SHALL show the host's answer.

Source: audio-vue `control-commands`, "A cancel works at any moment of a calibration": it writes no
record and gives the panel back.

#### Scenario: Cancel while settling

- **WHEN** the user cancels while the chain settles
- **THEN** the panel is never armed

#### Scenario: Cancel while playing

- **WHEN** the user cancels while the file plays
- **THEN** playback stops, the host is sent a cancel, and the run says it was cancelled

#### Scenario: Cancel too late

- **WHEN** the host refuses the cancel because the record is being written
- **THEN** the page shows the host's reason and follows the run to its ending

#### Scenario: Cancel after the run completed

- **WHEN** the host answers the cancel done, saying the run's record stands
- **THEN** the page says the run had already completed and opens its report

### Requirement: A run's ending says what became of it

The page SHALL take a run's ending from the ended calibration the panel's state names for this
run's arm, and SHALL say whether it completed, failed or expired. A completed run SHALL open its
report, and say where it cannot apply or its report was not written. A failed run SHALL say why.

Source: Decision (maintainer, 2026-11-08). audio-vue's `calibration-from-the-app` (planned):
`control-state` names the ended calibration by arm; a failed run writes no record.

#### Scenario: A run that completes

- **WHEN** the panel's state names the run as completed
- **THEN** the page says the run completed and opens its report

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

### Requirement: A run under way is not ended without asking

Quitting the app, or switching to another panel, while a run is under way SHALL ask first, and going
on SHALL cancel the run as Cancel does.

Source: Recommended, as `scene-saving` asks before unsaved scenes are lost: a run cut off mid-file
is measured as a stimulus missing.

#### Scenario: Quitting while playing

- **WHEN** the user quits while the file plays
- **THEN** the app asks to cancel the run or keep going, and on cancel stops playback and sends the
  host's cancel before quitting
