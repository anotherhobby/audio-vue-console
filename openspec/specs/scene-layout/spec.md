# scene-layout Specification

## Purpose

The rules of a scene's layout as the app edits it: where a card may go, how cards move, resize and
group, and how an edit is undone, so every layout the app makes is one the panel will load.

## Requirements

### Requirement: Every card lies on the scene's grid

Every card in a layout SHALL lie wholly within the scene's grid, and no edit SHALL leave a card
running off it.

Source: audio-vue `scene-grid`, "Placements stay on the declared grid".

#### Scenario: A card at the grid's edge

- **WHEN** a 64 × 36 layout holds a card at column 56, 8 columns wide
- **THEN** the card lies on the grid, ending at its last column

#### Scenario: An edit that would run off

- **WHEN** an edit would place any cell of a card past the grid's last column or row
- **THEN** the card stays on the grid, as the requirement for that edit says

### Requirement: Cards never overlap

No two cards in a layout SHALL cover the same cell, after any edit.

Source: Decision (maintainer, 2026-11-02).

#### Scenario: Two cards side by side

- **WHEN** one card covers columns 0 to 7 and another starts at column 8 on the same rows
- **THEN** the layout holds both

### Requirement: A card is added only where its cells are free

A card added to a layout SHALL take the size its kind has in the library, and SHALL be refused if
any of its cells is taken or it is larger than the grid. A card is never pushed or swapped to make
room.

Source: Decision (maintainer, 2026-11-02): a drop is refused unless there is space, with no push and
no swap.

#### Scenario: Free cells

- **WHEN** a 19 × 18 card is added where 19 × 18 cells are free
- **THEN** the layout holds the new card there

#### Scenario: A taken cell

- **WHEN** a card is added where one of its cells is taken
- **THEN** the addition is refused, saying the space is taken, and the layout is unchanged

#### Scenario: Too large for the grid

- **WHEN** a 96-column card is added to a 64 × 36 layout
- **THEN** the addition is refused, saying the card is larger than the grid

### Requirement: A move keeps to the grid and refuses taken cells

Moving cards SHALL shift them together by whole cells, keeping their sizes. A move past the grid's
edge SHALL stop at the edge. A move that lands any moved card on a card not being moved SHALL be
refused, leaving every card where it was.

Source: Decision (maintainer, 2026-11-02): cards never overlap, and no push and no swap.

#### Scenario: A move into free cells

- **WHEN** a card is moved 4 columns right into free cells
- **THEN** it is 4 columns right, at the same size

#### Scenario: A move past the edge

- **WHEN** a card 2 columns from the grid's right edge is moved 5 columns right
- **THEN** it ends at the right edge, 2 columns right

#### Scenario: A move onto another card

- **WHEN** a move would land a card on any cell of a card not being moved
- **THEN** the move is refused, saying the space is taken, and no card moves

#### Scenario: Two cards moved together

- **WHEN** two cards side by side are moved one column right as one move, the left card into cells
  the right card leaves
- **THEN** both move, since neither lands on a card that stays put

### Requirement: A resize stops at a neighbour's edge

Resizing a card SHALL move only the edges being dragged, by whole cells. Each edge SHALL stop at the
grid's edge and at the edge of any card in its path. A card SHALL be at least one cell in each
direction.

Source: Decision (maintainer, 2026-11-02): a resize stops at the neighbour's edge, by the same rule
as a drop.

#### Scenario: Growing into free cells

- **WHEN** a card's right edge is dragged 3 columns right into free cells
- **THEN** the card is 3 columns wider

#### Scenario: Growing into a neighbour

- **WHEN** a card's right edge is dragged 6 columns right and a card starts 2 columns away on rows it
  shares
- **THEN** the card is 2 columns wider and meets the neighbour

#### Scenario: Shrinking to the minimum

- **WHEN** a card 4 columns wide has its left edge dragged 6 columns right
- **THEN** the card is 1 column wide, ending where it ended

### Requirement: A grouped card is not resized on its own

A card that belongs to a group SHALL NOT be resized, since that would break the rectangle its group
tiles. It is ungrouped first.

Source: Decision (maintainer, 2026-11-03): ungroup first, since a group tiles a rectangle and one
member changing size breaks it.

#### Scenario: Resizing a member

- **WHEN** a resize is asked of a card in a group
- **THEN** it is refused, saying the card is grouped, and the layout is unchanged

### Requirement: Cards group only when they tile a rectangle

Grouping SHALL be asked for, never inferred. It SHALL be refused unless at least two cards are
chosen, they are not already exactly one group, they cover a rectangle of cells exactly, and no
other card lies in that rectangle. A refusal SHALL say which failed.

Source: audio-vue `scene-plate`, "Groups are declared, never inferred" and "A group tiles a
rectangle"; Decision (maintainer, 2026-11-02): grouping says why when it cannot; an existing group
is refused (maintainer, 2026-11-03).

#### Scenario: Two cards that tile a rectangle

- **WHEN** two cards of the same height, side by side, are grouped
- **THEN** they form one group

#### Scenario: Cards that leave a hole

- **WHEN** three cards are grouped whose bounding rectangle has an empty cell
- **THEN** the grouping is refused, saying the cards do not fill a rectangle

#### Scenario: Another card inside

- **WHEN** cards are grouped whose bounding rectangle would hold a card not chosen
- **THEN** the grouping is refused, saying another card is in the way

#### Scenario: One card

- **WHEN** a single card is grouped
- **THEN** the grouping is refused, saying a group needs two cards

#### Scenario: A group already

- **WHEN** the cards of one existing group, and no others, are grouped
- **THEN** the grouping is refused, saying they are already a group

#### Scenario: Cards that happen to tile a rectangle

- **WHEN** cards that tile a rectangle are placed without being grouped
- **THEN** they stay ungrouped

### Requirement: A new group replaces the groups it takes in

When chosen cards that belong to groups are grouped, the new group SHALL replace those groups, so
each card is in one group at most.

Source: audio-vue `scene-plate`: a card's entry names one `group:`.

#### Scenario: A group and a loose card

- **WHEN** a two-card group and a card beside it, together tiling a rectangle, are grouped
- **THEN** the three form one new group, and the old group is gone

### Requirement: A group moves and is removed as one

Moving or removing any card of a group SHALL move or remove the whole group.

Source: Decision (maintainer, 2026-11-02): a group moves and is removed as one.

#### Scenario: Moving a member

- **WHEN** one card of a three-card group is moved
- **THEN** all three move by the same offset

#### Scenario: Removing a member

- **WHEN** one card of a group is removed
- **THEN** every card of the group is removed

### Requirement: Ungrouping leaves the cards in place

Ungrouping SHALL dissolve the group and leave each of its cards where it was, at its size.

Source: Decision (maintainer, 2026-11-02): ungroup with ⇧⌘G.

#### Scenario: Ungrouping

- **WHEN** a two-card group is ungrouped
- **THEN** both cards are ungrouped, at the same cells as before

### Requirement: Every edit can be undone

Each edit that changes a layout SHALL be one step that can be undone and then redone, a whole drag
included. A refused edit SHALL add no step.

Source: Decision (maintainer, 2026-11-03): undo and redo for every edit.

#### Scenario: Undoing a move

- **WHEN** a card is moved and the move is undone
- **THEN** the card is where it was, and redo moves it again

#### Scenario: A refused edit

- **WHEN** a move is refused and then undo is asked for
- **THEN** undo reverses the edit before the refused move
