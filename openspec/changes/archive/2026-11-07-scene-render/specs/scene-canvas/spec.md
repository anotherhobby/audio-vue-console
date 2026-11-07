# Spec Delta

## ADDED Requirements

### Requirement: The library offers the host's placeable cards

The library SHALL list the cards the host's settings schema marks placeable, and a card dragged from
it SHALL take its declared minimum cells, scaled to the scene's rows.

Source: audio-vue `card-layout`: each card declares its minimum cells on a 36-row grid, exported
with whether it is placeable.

#### Scenario: The library

- **WHEN** the host's schema marks the calibration card not placeable and the waveform placeable with
  a minimum of 17 by 10 cells
- **THEN** the library lists the waveform and not the calibration card, and a dropped waveform on a
  36-row scene takes 17 by 10 cells
