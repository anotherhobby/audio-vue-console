# Spec Delta

## ADDED Requirements

### Requirement: A parked card keeps its plate

Parking a card SHALL keep its plate's layer, slid to where the card is parked, with no request.
The layer SHALL be drawn with no backdrop behind it. Returning the card to the grid SHALL draw its
plate again in its new cells, as a move does.

Source: `scene-rendering`, "A move slides the plates and draws them again on release". Decision
(maintainer, 2026-11-22): a parked card is drawn beside the panel as it is on it.

#### Scenario: Parking a card

- **WHEN** the user drags a card off the grid and releases it
- **THEN** its plate is shown where it is parked, and no request is sent

#### Scenario: Returning it

- **WHEN** the user drags the parked card back onto free cells
- **THEN** its plate is drawn again in its new cells

### Requirement: A parked plate is drawn again on its own

When a parked card has no layer, its settings change, or a scene setting other than the backdrop
changes, its plate SHALL be drawn as the helper draws its cards alone in the scene's settings, as a
library tile is. Where the helper cannot draw it, the card SHALL be a plain box with its name.

Source: audio-vue `scene-render`, "A request carries a scene and its display" and "A request may
name its plates"; `scene-rendering`, "A library tile is the card's plate as the helper draws it".

#### Scenario: A parked card's setting

- **WHEN** the user changes a setting of a parked card
- **THEN** its plate is drawn again on its own, and no plate on the grid is drawn again

#### Scenario: The scene's typeface

- **WHEN** a card is parked and the user changes the scene's typeface
- **THEN** the backdrop, every plate on the grid and the parked plate are drawn again

#### Scenario: No renderer

- **WHEN** the helper could not start and a card is parked
- **THEN** the parked card is shown as a plain box with its name
