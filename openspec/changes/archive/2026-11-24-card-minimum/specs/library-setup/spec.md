# Spec Delta

## MODIFIED Requirements

### Requirement: Changing a tile's setting redraws the tile

A change in a selected tile's settings SHALL be kept as that card's library setup, and its tile SHALL
be drawn again by the helper with it, at the card's whole size with that setup (`card-minimum`). Use
Default SHALL remove the setting from the setup. The open scene SHALL NOT change, nor be marked
unsaved.

Source: Decision (maintainer, 2026-11-24): the options can be adjusted, and the preview in the card
column updates to show the change; a card is shown at its whole minimum.

#### Scenario: Setting the meter's style

- **WHEN** the meter's tile is selected and the user sets its style to bar
- **THEN** the meter's tile is drawn again as a bar meter, and the scene is not marked unsaved

#### Scenario: A setup that needs more room

- **WHEN** the meter's tile is selected and the user turns its ticks on, which it sheds at the plain
  tile's size
- **THEN** the meter's tile is drawn again larger, at its whole size with ticks, showing its ticks
  and saying that size

#### Scenario: Back to the default

- **WHEN** the user chooses Use Default for the meter's style in the tile's settings
- **THEN** the tile is drawn again with the declared style

### Requirement: A set-up card is dropped at its tile's size

A card dragged from the library, set up or not, SHALL be added at the size its tile is drawn at, its
whole size (`card-minimum`), or at its declared minimum until that is held.

Source: Decision (maintainer, 2026-11-24): a set-up card lands at the size its tile found, so it is
not born too small for its setup; every card is dropped at its whole minimum.

#### Scenario: Dropped at the size that fits

- **WHEN** the meter's set-up tile is drawn at 12 × 8 cells and the user drags a meter onto the canvas
- **THEN** the meter is added at 12 × 8 cells

#### Scenario: No setup

- **WHEN** the waveform has no setup and its tile is drawn at 17 × 10, and the user drags one onto the
  canvas
- **THEN** it is added at 17 × 10
