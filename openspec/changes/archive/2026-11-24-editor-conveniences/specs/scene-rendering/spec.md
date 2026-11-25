# Spec Delta

## MODIFIED Requirements

### Requirement: A parked plate is drawn again on its own

When a parked card has no layer, its settings change, its size changes, or a scene setting other
than the backdrop changes, its plate SHALL be drawn as the helper draws its cards alone in the
scene's settings, as a library tile is. Where the helper cannot draw it, the card SHALL be a plain
box with its name.

Source: audio-vue `scene-render`, "A request carries a scene and its display" and "A request may
name its plates"; `scene-rendering`, "A library tile is the card's plate as the helper draws it".
Decision (maintainer, 2026-11-24): a parked card resizes, and is drawn at its new size.

#### Scenario: A parked card's setting

- **WHEN** the user changes a setting of a parked card
- **THEN** its plate is drawn again on its own, and no plate on the grid is drawn again

#### Scenario: A parked card resized

- **WHEN** the user resizes a parked card
- **THEN** its plate is drawn again on its own at its new size, and no plate on the grid is drawn
  again

#### Scenario: The scene's typeface

- **WHEN** a card is parked and the user changes the scene's typeface
- **THEN** the backdrop, every plate on the grid and the parked plate are drawn again

#### Scenario: No renderer

- **WHEN** the helper could not start and a card is parked
- **THEN** the parked card is shown as a plain box with its name

### Requirement: A card that cannot show its reading is named

When the helper reports cards that cannot show their reading at the size drawn, on the grid or
parked, the canvas SHALL name them while they are reported.

Source: audio-vue `scene-render`, "The answer says what does not fit". audio-vue `card-layout`: the
too-small check. Decision (maintainer, 2026-11-24): a parked card is as editable as one on the panel.

#### Scenario: A card made too small

- **WHEN** the user shrinks a waveform card below the size it can show its reading at
- **THEN** the canvas names the waveform as too small to show its reading

#### Scenario: A parked card made too small

- **WHEN** the user shrinks a parked waveform below the size it can show its reading at
- **THEN** the canvas names the waveform as too small to show its reading
