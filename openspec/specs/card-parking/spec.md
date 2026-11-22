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
SHALL be removed by Delete, and SHALL show and change its settings in the inspector. It SHALL show
no resize handles. Group SHALL be disabled for a selection that holds a parked card, saying the
cards must be on the panel to group. Ungroup SHALL work on a parked group.

Source: Decision (maintainer, 2026-11-22): a parked card is still a card of the scene.

#### Scenario: Changing a parked card's setting

- **WHEN** the user selects a parked meter and changes its style in the inspector
- **THEN** the parked meter is drawn with the new style, and keeps it when returned to the panel

#### Scenario: Grouping with a parked card

- **WHEN** a card on the grid and a parked card are selected
- **THEN** Group is disabled, and the inspector says the cards must be on the panel to group

#### Scenario: A marquee off the panel

- **WHEN** the user drags a rectangle on the pane that touches two parked cards
- **THEN** both are selected

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
