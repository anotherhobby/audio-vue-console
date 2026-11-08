# Spec Delta

## MODIFIED Requirements

### Requirement: The sidebar has no Access page

The sidebar SHALL list Panel, Scenes, Input, Calibration, Display and History, and no Access page and
no panel picker. The pages other than Panel, Scenes and Calibration are held to no requirement here,
and keep their sample values until their own changes build them.

Source: Decision (maintainer, 2026-11-05): Access goes; the other pages can wait, and sample data is
fine before the project's release. Decision (maintainer, 2026-11-06): Overview is renamed Panel, and
the picker moves to the Panel page. Decision (maintainer, 2026-11-08): Calibration is built.

#### Scenario: The sidebar

- **WHEN** the panel window is open
- **THEN** its sidebar lists Panel, Scenes, Input, Calibration, Display and History, in that order,
  with nothing above them

#### Scenario: The Calibration page

- **WHEN** the user opens Calibration on a paired host
- **THEN** it shows the host's calibration and runs, and no sample values
