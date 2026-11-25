# Spec Delta

## MODIFIED Requirements

### Requirement: A parked card is selected and edited like any card

A parked card SHALL be selected by click, shift-click and a marquee drawn anywhere on the pane,
SHALL be removed by Delete, SHALL show and change its settings in the inspector, and SHALL show
resize handles where a card on the grid would. Group SHALL work on a selection of parked cards
alone as it does on the grid, and SHALL be disabled for a selection holding both parked cards and
cards on the grid, saying a group is wholly on the panel or wholly off it. Ungroup SHALL work on a
parked group.

Source: Decision (maintainer, 2026-11-22): a parked card is still a card of the scene. Decision
(maintainer, 2026-11-24): a parked card is as editable as one on the panel.

#### Scenario: Changing a parked card's setting

- **WHEN** the user selects a parked meter and changes its style in the inspector
- **THEN** the parked meter is drawn with the new style, and keeps it when returned to the panel

#### Scenario: Grouping parked cards

- **WHEN** two parked cards that tile a rectangle are selected and the user presses ⌘G
- **THEN** they form a group, still parked, and move as one

#### Scenario: Grouping with a parked card

- **WHEN** a card on the grid and a parked card are selected
- **THEN** Group is disabled, and the inspector says a group is wholly on the panel or wholly off it

#### Scenario: Resize handles on a parked card

- **WHEN** the user selects a lone parked card that belongs to no group
- **THEN** it shows resize handles at its corners and edges

#### Scenario: A marquee off the panel

- **WHEN** the user drags a rectangle on the pane that touches two parked cards
- **THEN** both are selected

## ADDED Requirements

### Requirement: A parked card resizes within the pane

Dragging a parked card's handle SHALL resize it in whole cells, as one step named Resize, stopping
at the panel's edge, at any parked card in its path, at the pane's edge, and at its declared
minimum. A resize SHALL never take a parked card onto the panel.

Source: Decision (maintainer, 2026-11-24): a parked card resizes as a card on the panel does; a card
is wholly on the panel or wholly off it (2026-11-22).

#### Scenario: Growing a parked card

- **WHEN** a parked 10 × 4 card has free pane cells to its right and the user drags its right handle
  3 columns right
- **THEN** it is 13 columns wide, and Edit offers Undo Resize

#### Scenario: Stopping at the panel's edge

- **WHEN** a card parked on the row below the grid is dragged by its top handle 2 rows up
- **THEN** it does not grow, as its top edge already meets the panel

#### Scenario: Stopping at another parked card

- **WHEN** a parked card's right handle is dragged into another parked card
- **THEN** its right edge stops at that card's left edge

#### Scenario: Stopping at the pane's edge

- **WHEN** a parked card's bottom handle is dragged past the pane's last row
- **THEN** its bottom edge stops at the pane's last row

#### Scenario: The declared minimum

- **WHEN** a parked meter with a declared minimum of 8 × 6 is shrunk by dragging a corner 5 cells in
- **THEN** it stops at 8 × 6


### Requirement: A library card dropped off the panel is parked

A card dragged from the library and dropped over the canvas pane outside the panel SHALL be parked,
centred on the cell under the pointer and pushed wholly off the grid across the edge it crosses by
the least that clears it, as a dragged card is. Its outline SHALL show while it hovers.

Source: Decision (maintainer, 2026-11-24): a card from the library can be dropped onto the grid
outside the scene, as well as onto the panel.

#### Scenario: Dropped below the panel

- **WHEN** the user drags a meter from the library over free pane cells below the panel and drops it
- **THEN** the meter is parked there and selected, and the canvas says one card is off the panel

#### Scenario: Dropped across the edge

- **WHEN** the user drops a 10 × 4 card with the pointer one row below the panel's last row
- **THEN** the card is parked wholly below the panel, its top row on the row below the grid

#### Scenario: A set-up card

- **WHEN** the meter has a library setup and its set-up tile is drawn at 12 × 8, and the user drops a
  meter below the panel
- **THEN** a 12 × 8 meter with that setup is parked there

### Requirement: A library drop off the panel is refused where it cannot be parked

A library card dropped off the panel SHALL be refused, saying why, adding nothing, where it would
cover a parked card, or where the pane has no room for it beyond the edge it crosses.

Source: `card-parking`, "Parked cards keep to the pane and never overlap".

#### Scenario: Dropped onto a parked card

- **WHEN** the user drops a card over the pane where it would cover a parked card
- **THEN** nothing is added, and the canvas says the space is taken

#### Scenario: No room beyond the edge

- **WHEN** the pane has 3 rows below the panel and the user drops a 10 × 4 card below it
- **THEN** nothing is added, and the canvas says there is no room for it off the panel

### Requirement: A drop over the panel lands on it

A card dropped with the pointer over the panel SHALL be added on the grid as `scene-canvas` says,
kept within it, and SHALL NOT be parked.

Source: `scene-canvas`, "A card is added by dragging it from the library".

#### Scenario: Near the edge

- **WHEN** the user drops a 10 × 4 card with the pointer on the panel's last row
- **THEN** the card is added on the grid, its last row on the panel's last row
