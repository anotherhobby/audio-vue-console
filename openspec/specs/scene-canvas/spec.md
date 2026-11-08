# scene-canvas Specification

## Purpose

How the user edits a scene's layout on the canvas: adding cards from the library, moving, resizing,
selecting and grouping them, by pointer and by keyboard, with every refusal saying why.

## Requirements

### Requirement: A card is added by dragging it from the library

Dragging a card from the library onto the canvas SHALL show the cells it would take, snapped to the
grid and kept within it, and mark them refused where the card cannot go. Dropping it SHALL add the
card there, or add nothing where it is refused.

Source: `product.md`: cards are arranged by drag and drop; Decision (maintainer, 2026-11-02): a drop
is refused unless there is space.

#### Scenario: Dropping in free space

- **WHEN** the user drags a card from the library over free cells and drops it
- **THEN** the card is added on those cells and selected

#### Scenario: Dropping on a card

- **WHEN** the user drops a card where it would cover another card
- **THEN** no card is added, and the canvas says the space is taken

### Requirement: Cards move by dragging

Dragging a selected card SHALL move the selection, snapped to whole cells, showing where it would
land and marking it refused where it cannot. Releasing SHALL move the selection there, or leave it
where it was if refused.

Source: `product.md`: the app draws the grid, the handles and the drag.

#### Scenario: A move into free cells

- **WHEN** the user drags a card to free cells and releases
- **THEN** the card is in its new cells

#### Scenario: A move onto another card

- **WHEN** the user releases a card over another card
- **THEN** the card returns to where it was, and the canvas says the space is taken

### Requirement: A card resizes by its handles

A single selected card that belongs to no group SHALL show handles at its corners and edges.
Dragging a handle SHALL resize the card in whole cells, stopping at the grid's edge and at any card
in its path.

Source: Decision (maintainer, 2026-11-02): a resize stops at the neighbour's edge.

#### Scenario: Dragging a corner

- **WHEN** the user drags a card's lower-right handle 3 columns right and 2 rows down into free cells
- **THEN** the card is 3 columns wider and 2 rows taller

#### Scenario: A grouped card

- **WHEN** the user selects a card in a group
- **THEN** no resize handles are shown

### Requirement: Cards are selected by click, shift-click and marquee

Clicking a card SHALL select it alone, and clicking a card in a group SHALL select its whole group.
Shift-clicking SHALL add or remove a card or group. Dragging across empty canvas SHALL draw a
rectangle that selects every card it touches, adding to the selection with shift held.

Source: Decision (maintainer, 2026-11-02): select by click, shift-click or marquee.

#### Scenario: Clicking a group member

- **WHEN** the user clicks one card of a group
- **THEN** every card of the group is selected

#### Scenario: A marquee

- **WHEN** the user drags a rectangle across empty canvas that touches three cards
- **THEN** those three cards are selected

### Requirement: Clicking open space clears the selection

Clicking anywhere in the canvas pane that is not a card, inside the panel outline or around it,
SHALL clear the selection, and the inspector SHALL show the scene's settings.

Source: Decision (maintainer, 2026-11-03): open space returns to the scene's settings.

#### Scenario: Clicking beside the panel

- **WHEN** a card is selected and the user clicks the pane outside the panel outline
- **THEN** nothing is selected, and the inspector shows the scene's settings

### Requirement: Group and Ungroup are commands that say why not

Group (⌘G) SHALL be enabled only when the selection can be grouped. When two or more cards are
selected and cannot be, the inspector SHALL say why. Ungroup (⇧⌘G) SHALL be enabled when the
selection holds a group, and SHALL ungroup every group in it.

Source: Decision (maintainer, 2026-11-02): ⌘G enabled only when the selection tiles a rectangle,
saying why when not; ungroup with ⇧⌘G.

#### Scenario: A selection that tiles a rectangle

- **WHEN** two cards that tile a rectangle are selected and the user presses ⌘G
- **THEN** they form a group, and Ungroup is enabled

#### Scenario: A selection with a hole

- **WHEN** three cards whose bounding rectangle has an empty cell are selected
- **THEN** Group is disabled, and the inspector says the cards do not fill a rectangle

### Requirement: Delete removes the selection

Pressing Delete SHALL remove every selected card, whole groups included.

Source: Decision (maintainer, 2026-11-03).

#### Scenario: Deleting a group member

- **WHEN** a card of a group is selected and the user presses Delete
- **THEN** the whole group is removed

### Requirement: Arrow keys nudge the selection

An arrow key SHALL move the selection one cell in its direction, and four cells with shift held,
stopping at the grid's edge. A nudge onto another card SHALL be refused, saying why.

Source: Decision (maintainer, 2026-11-03): arrow keys nudge, with shift for a larger step.

#### Scenario: A nudge

- **WHEN** a card with free cells to its right is selected and the user presses the right arrow
- **THEN** the card moves one column right

#### Scenario: A shifted nudge

- **WHEN** the user presses shift and the down arrow with free rows below
- **THEN** the selection moves four rows down

### Requirement: Undo and Redo name the edit

⌘Z SHALL undo the last edit and ⇧⌘Z SHALL redo it, with the Edit menu naming the edit, such as
Undo Move or Undo Group.

Source: Decision (maintainer, 2026-11-03): undo and redo for every edit.

#### Scenario: Undoing an addition

- **WHEN** the user adds a card and opens the Edit menu
- **THEN** it offers Undo Add Card, and choosing it removes the card

### Requirement: A refused edit says why

When an edit is refused, the canvas SHALL say why until the next edit or selection change, and SHALL
leave the layout as it was.

Source: Decision (maintainer, 2026-11-02): grouping says why when it cannot; extended to every
refusal (this change).

#### Scenario: A refused drop

- **WHEN** a drop is refused because the space is taken
- **THEN** the canvas says the space is taken, and the message clears at the next selection

### Requirement: A read-only scene can be looked at, not edited

The canvas SHALL refuse every edit to a built-in scene, or to a scene whose shape is not the panel's,
and SHALL say which of these it is and that the scene must be duplicated to edit. Selecting cards
SHALL still work.

Source: `product.md`: built-in scenes are read-only, and scenes are tied to a display shape.

#### Scenario: A built-in scene

- **WHEN** the user drags a card from the library onto a built-in scene
- **THEN** nothing is added, and the canvas says built-in scenes are duplicated to edit

#### Scenario: Selecting on a read-only scene

- **WHEN** the user clicks a card on a built-in scene
- **THEN** it is selected and shown in the inspector, without resize handles

### Requirement: Edits are kept until saved or discarded

A scene's edits SHALL be kept while the app runs until they are saved or discarded, as
`scene-saving` says: leaving the editor and opening the scene again SHALL show them, and so SHALL
the scene's thumbnail. A kept edit SHALL keep each card's entry from the document it was made from,
so every card setting but its cells and group stays as the host gave it.

Source: `product.md`: saves are explicit. Decision (maintainer, 2026-11-07): unsaved edits are asked
about before a quit or a switch of panel.

#### Scenario: Reopening a scene

- **WHEN** the user moves a card, goes back to the gallery and opens the scene again
- **THEN** the card is where it was moved to, and the gallery thumbnail shows it there

#### Scenario: Reopening keeps card settings

- **WHEN** a card carries settings of its own, and the user moves another card, goes back to the
  gallery and opens the scene again
- **THEN** the first card is drawn with its settings, as before the move

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
