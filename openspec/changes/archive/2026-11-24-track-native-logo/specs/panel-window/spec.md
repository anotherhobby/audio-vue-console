## MODIFIED Requirements

### Requirement: The sidebar has no Access page

The sidebar SHALL list Panel, Scenes, Capture, Display and History, and no Access page and no panel
picker. The pages other than Panel, Scenes, Capture and Display are held to no requirement here,
and keep their sample values until their own changes build them.

Source: Decisions (maintainer): Access goes, and the other pages may show sample data until built
(2026-11-05); Overview is renamed Panel, with the picker (2026-11-06); Capture holds Calibration
and the input (2026-11-08).

#### Scenario: The sidebar

- **WHEN** the panel window is open
- **THEN** its sidebar lists Panel, Scenes, Capture, Display and History, in that order, with
  nothing above them

#### Scenario: The Calibration page

- **WHEN** the user looks for the host's calibration and runs on a paired host
- **THEN** they are on the Capture page, with no sample values, and no Calibration page is listed

#### Scenario: The Capture page

- **WHEN** the user opens Capture on a paired host
- **THEN** it shows the panel's capture device and rate, the host's calibration and its runs, and
  no sample values

#### Scenario: The Display page

- **WHEN** the user opens Display on a paired host
- **THEN** it shows the panel's display size and its idle settings from the host, and no sample
  values
