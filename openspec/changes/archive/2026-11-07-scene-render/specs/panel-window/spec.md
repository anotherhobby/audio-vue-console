# Spec Delta

## MODIFIED Requirements

### Requirement: The sidebar has no Access page

The sidebar SHALL list Panel, Scenes, Input, Calibration, Display and History, and no Access page and
no panel picker. The pages other than Panel and Scenes are held to no requirement here, and keep their
sample values until their own changes build them.

Source: Decision (maintainer, 2026-11-05): Access goes; the other pages can wait, and sample data is
fine before the project's release. Decision (maintainer, 2026-11-06): Overview is renamed Panel, and
the picker moves to the Panel page.

#### Scenario: The sidebar

- **WHEN** the panel window is open
- **THEN** its sidebar lists Panel, Scenes, Input, Calibration, Display and History, in that order,
  with nothing above them

## ADDED Requirements

### Requirement: Status says whether scenes can be drawn

Status SHALL hold a Renderer row: while the helper starts, that it is starting, with an indicator; once
its code is compared with the panel's, Ready only where it matches; and in a warning colour, why
scenes are not drawn as the panel draws them, or why it could not start. While not paired, `—`.

Source: Decision (maintainer, 2026-11-07): a line under Status in place of a launch screen; it must
not say Ready when the card code differs, and says so in orange. `card-code`.

#### Scenario: Pairing

- **WHEN** the app becomes paired, starts the helper, and its code matches the panel's
- **THEN** the Renderer row says it is starting, with a working indicator, then Ready

#### Scenario: Shared code differs

- **WHEN** the helper is ready and `src/frame.py` differs from the panel's
- **THEN** the Renderer row says scenes are not drawn because the card code differs, in orange, and
  does not say Ready; the Scenes page names `src/frame.py`

#### Scenario: A card's code differs

- **WHEN** the helper is ready and only the waveform card's code differs
- **THEN** the Renderer row says some cards differ, in orange, and the Scenes page names the
  waveform

#### Scenario: A helper that cannot start

- **WHEN** the app was built without its interpreter
- **THEN** the Renderer row says the renderer could not start, and why, in orange
