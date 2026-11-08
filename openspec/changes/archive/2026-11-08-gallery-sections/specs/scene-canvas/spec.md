# Spec Delta

## MODIFIED Requirements

### Requirement: The library offers the host's placeable cards

The library SHALL list the cards the host's schema marks placeable under the host's categories,
each headed by its label, both in the schema's order, leaving out a category with no placeable card
or, in a search, no match. A dragged card SHALL take its declared minimum cells, scaled to the
scene's rows.

Source: audio-vue `card-layout` (minimums, placeable) and `card-categories` (categories and card
order). Decision (maintainer, 2026-11-08): categories and card order come from the panel.

#### Scenario: The library

- **WHEN** the host's schema marks the calibration card not placeable and the waveform placeable with
  a minimum of 17 by 10 cells
- **THEN** the library lists the waveform and not the calibration card, and a dropped waveform on a
  36-row scene takes 17 by 10 cells

#### Scenario: Grouped as the panel declares

- **WHEN** the schema gives Readouts (`meter`, `readout`) then Level (`vu_meter`, `peak_rms`), all
  placeable
- **THEN** the library shows "Readouts" with `meter` then `readout`, then "Level" with `vu_meter`
  then `peak_rms`

#### Scenario: A category with nothing to place

- **WHEN** the Calibration category holds only cards not placeable
- **THEN** the library shows no "Calibration" heading

#### Scenario: Searching

- **WHEN** the user searches "meter" and only `meter` and `vu_meter` match
- **THEN** the library shows "Readouts" with `meter` and "Level" with `vu_meter`, and no other
  heading
