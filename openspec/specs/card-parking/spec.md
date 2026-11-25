# card-parking Specification

## Purpose
Holding cards off the panel while a scene is edited, so the user can make room on a full scene by
setting cards aside on the canvas pane rather than deleting and recreating them.

## Requirements

### Requirement: A drag across the panel's edge parks the cards

A drag SHALL move the selection as one block. When any of its cells would lie off the grid, the
drag SHALL show the block wholly outside, pushed across the edge it crosses by the least that
clears the grid. Releasing SHALL park the cards there, keeping their shapes, relative places,
settings and groups.

Source: Decision (maintainer, 2026-11-22): as soon as a card starts to go off, it is parked and its
outline shifts fully outside the scene; a group parks as a group.

#### Scenario: Starting to cross the bottom edge

- **WHEN** a 10 × 4 card ending at the grid's last row is dragged one row down
- **THEN** its outline is shown on the 4 rows below the grid, and releasing parks it there

#### Scenario: Crossing a corner

- **WHEN** a 10 × 4 card at the grid's bottom-right corner is dragged 2 columns right and 1 row down
- **THEN** its outline is pushed 3 more rows down, wholly below the grid, rather than 8 more
  columns right

#### Scenario: Parking a group

- **WHEN** a card of a two-card group is dragged across the grid's right edge
- **THEN** both cards are parked side by side as before, still one group

### Requirement: A parked card returns only wholly onto free cells

A parked card SHALL be moved by dragging, as one block with the rest of the selection. The block
SHALL return to the scene's layout only where every one of its cells lies on the grid. Where any
returning card would cover a card on the grid, the move SHALL be refused, saying the space is
taken, and every card SHALL stay where it was.

Source: Decision (maintainer, 2026-11-22): a card is wholly on the panel or wholly off it.

#### Scenario: Returning to free cells

- **WHEN** a parked 10 × 4 card is dragged to 10 × 4 free cells on the grid and released
- **THEN** it is on the grid in those cells, with its settings

#### Scenario: Returning half on

- **WHEN** a parked card is dragged so that half of it lies on the grid
- **THEN** its outline stays wholly outside the grid, and releasing leaves it parked

#### Scenario: Returning onto a card

- **WHEN** a parked card is released where it would cover a card on the grid
- **THEN** the move is refused, saying the space is taken, and the card stays parked where it was

### Requirement: Parked cards keep to the pane and never overlap

A parked card SHALL lie wholly within the canvas pane as shown when it was placed, and SHALL NOT
cover a cell of another parked card. A drag beyond the pane SHALL stop at the pane's edge. Where
the block cannot be pushed wholly outside the grid within the pane, or would cover a parked card,
the move SHALL be refused, saying why, and every card SHALL stay where it was.

Source: Decision (maintainer, 2026-11-22): parked cards stay within the visible canvas pane.

#### Scenario: Onto another parked card

- **WHEN** a card is dragged off the grid onto a parked card
- **THEN** the move is refused, saying the space is taken

#### Scenario: No room off the panel

- **WHEN** the panel fills the pane's width and a card is dragged across its right edge
- **THEN** the move is refused, saying there is no room for the card off the panel, and the card
  stays where it was

#### Scenario: Too little room off the panel

- **WHEN** the pane has 3 columns right of the panel and a 10-column card is dragged across the
  panel's right edge
- **THEN** the move is refused, saying there is no room for the card off the panel

### Requirement: Every parked card stays in view

The canvas SHALL keep the panel centred in the pane at its usual size, and SHALL draw it smaller,
still centred, only as far as it must to keep every parked card within the pane as the pane
shrinks.

Source: Decision (maintainer, 2026-11-22): parked cards stay within the visible pane.

#### Scenario: Narrowing the window

- **WHEN** a card is parked below the panel and the window is made shorter
- **THEN** the panel and the parked card are drawn smaller together, and both are in view

#### Scenario: Nothing parked

- **WHEN** no card is parked
- **THEN** the panel is drawn at the same size as it would be without parking

### Requirement: A parked card is selected and edited like any card

A parked card SHALL be selected by click, shift-click and a marquee drawn anywhere on the pane,
SHALL be removed by Delete, SHALL show and change its settings in the inspector, and SHALL show
resize handles where a card on the grid would.

Source: Decision (maintainer, 2026-11-22): a parked card is still a card of the scene. Decision
(maintainer, 2026-11-24): a parked card is as editable as one on the panel.

#### Scenario: Changing a parked card's setting

- **WHEN** the user selects a parked meter and changes its style in the inspector
- **THEN** the parked meter is drawn with the new style, and keeps it when returned to the panel

#### Scenario: Resize handles on a parked card

- **WHEN** the user selects a lone parked card that belongs to no group
- **THEN** it shows resize handles at its corners and edges

#### Scenario: A marquee off the panel

- **WHEN** the user drags a rectangle on the pane that touches two parked cards
- **THEN** both are selected

### Requirement: Parked cards group as cards on the grid do

Group SHALL work on a selection of parked cards alone as it does on the grid, and SHALL be disabled
for a selection holding both parked cards and cards on the grid, saying a group is wholly on the
panel or wholly off it. Ungroup SHALL work on a parked group.

Source: Decision (maintainer, 2026-11-24): a parked card is as editable as one on the panel; a card
is wholly on the panel or wholly off it (2026-11-22).

#### Scenario: Grouping parked cards

- **WHEN** two parked cards that tile a rectangle are selected and the user presses ⌘G
- **THEN** they form a group, still parked, and move as one

#### Scenario: Grouping with a parked card

- **WHEN** a card on the grid and a parked card are selected
- **THEN** Group is disabled, and the inspector says a group is wholly on the panel or wholly off it

### Requirement: Arrow keys never move a card across the panel's edge

An arrow key SHALL move parked cards by its step like any card. A step that would bring a parked
card onto the grid or past the pane's edge SHALL be refused, saying a card is dragged to move it
onto or off the panel, and one onto another parked card SHALL be refused, saying the space is
taken. Cards on the grid SHALL stop at the grid's edge (`scene-layout`).

Source: Decision (maintainer, 2026-11-22): only a drag parks or returns a card.

#### Scenario: A nudge towards the panel

- **WHEN** a parked card one row below the grid is selected and the user presses the up arrow
- **THEN** the card stays where it is, and the canvas says to drag it onto the panel

### Requirement: Parked cards are part of the scene's edits

Parking and returning a card SHALL be one step that can be undone, named Move. Parked cards SHALL be
kept with the scene's other unsaved edits while the app runs. Revert to Saved, loading a version,
and Discard SHALL leave no card parked.

Source: `scene-canvas`, "Edits are kept until saved or discarded"; `scene-layout`, "Every edit can
be undone".

#### Scenario: Undoing a park

- **WHEN** the user parks a card and presses ⌘Z
- **THEN** the card is back on the grid where it was, and Edit offers Redo Move

#### Scenario: Reopening a scene

- **WHEN** the user parks a card, goes back to the gallery and opens the scene again
- **THEN** the card is parked where it was left

#### Scenario: Reverting

- **WHEN** a stored scene has a parked card and the user chooses Revert to Saved
- **THEN** no card is parked and the scene is as the host holds it

### Requirement: The canvas says how many cards are parked

While any card is parked, the canvas SHALL say how many are off the panel, and that they must be
moved onto it to save, apply or duplicate the scene. A refusal SHALL be shown in its place until
the next edit or selection change.

Source: Decision (maintainer, 2026-11-22): save, apply and duplicate are blocked until no card is
outside the panel.

#### Scenario: Two parked cards

- **WHEN** two cards are parked
- **THEN** the canvas says two cards are off the panel and must be moved onto it to save, apply or
  duplicate the scene

### Requirement: Parked cards never reach the panel

A parked card SHALL be left out of everything the app sends or shows as the scene: the document a
write would carry, the scene the helper draws, the gallery's thumbnail, and whether the scene is
too wide for the panel.

Source: `product.md`: all truth is on the host. Decision (maintainer, 2026-11-22): parking is
temporary, while editing.

#### Scenario: The thumbnail

- **WHEN** a card is parked and the user goes back to the gallery
- **THEN** the scene's thumbnail shows the cards on the grid and not the parked card

### Requirement: A parked card resizes within the pane

Dragging a parked card's handle SHALL resize it in whole cells, as one step named Resize, stopping
at the panel's edge, at any parked card in its path, at the pane's edge, and at its readable floor
as a card on the grid does (`scene-layout`, `card-minimum`). A resize SHALL never take a parked card
onto the panel.

Source: Decision (maintainer, 2026-11-24): a parked card resizes as a card on the panel does,
stopping before Too Small; a card is wholly on the panel or wholly off it (2026-11-22).

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

- **WHEN** a parked meter's minimum is still being asked for, its declared minimum 8 × 6, and it is
  shrunk by dragging a corner 5 cells in
- **THEN** it stops at 8 × 6

#### Scenario: The readable floor

- **WHEN** a parked meter 12 × 10 whose readable floor is 7 rows at 12 columns has its bottom handle
  dragged 5 rows up
- **THEN** it stops at 12 × 7

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
