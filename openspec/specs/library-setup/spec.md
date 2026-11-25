# library-setup Specification

## Purpose
Seeing and changing a library card's settings before it is placed, so the user learns what a card
can do and sets it up once for every copy dropped from the library.

## Requirements

### Requirement: Clicking a library tile selects it

Clicking a library tile, without dragging it, SHALL select that card of the library alone, marking
its tile, and SHALL clear the canvas's selection. Selecting a card on the canvas, clicking open
space or leaving the editor SHALL clear it. Dragging a tile SHALL still add its card as before.

Source: Decision (maintainer, 2026-11-24): clicking a card in the library, instead of dragging it,
selects it and shows its options.

#### Scenario: Clicking the meter's tile

- **WHEN** a card is selected on the canvas and the user clicks the meter's tile in the library
- **THEN** the meter's tile is marked selected, and no card on the canvas is selected

#### Scenario: Back to the canvas

- **WHEN** the meter's tile is selected and the user clicks a card on the canvas
- **THEN** the tile is no longer selected, and the inspector shows the canvas card

### Requirement: The inspector shows a selected tile's settings

With a library tile selected, the inspector SHALL show its card's settings as it shows a lone card's
(`card-settings`), headed by the card's name and saying they apply to the cards dropped from the
library. It SHALL show no position, size or group.

Source: Decision (maintainer, 2026-11-24): the selected card's options show in the panel, so the user
knows what a card can do before dragging it in.

#### Scenario: A meter's settings

- **WHEN** the user clicks the meter's tile
- **THEN** the inspector shows every setting the panel's schema declares for the meter, each at its
  declared default, as for a meter on the canvas with no settings of its own

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

### Requirement: A dropped card takes its library setup

A card dragged from the library SHALL be added with its kind's library setup as its settings, as one
step named Add Card. Each card dropped SHALL take the setup as it stands at its drop, and a later
change to the setup SHALL NOT change a card already placed.

Source: Decision (maintainer, 2026-11-24): set a card up a certain way before dragging several copies.

#### Scenario: Dropping two set-up meters

- **WHEN** the meter's library setup has its style set to bar and the user drags two meters onto the
  canvas
- **THEN** both meters are added with their style set to bar

#### Scenario: Changing the setup afterwards

- **WHEN** a set-up meter has been dropped and the user then changes the meter's tile to another style
- **THEN** the meter on the canvas keeps the style it was dropped with

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

### Requirement: A tile with a setup says so

A library tile whose card has a setup SHALL be marked as set up. The inspector SHALL offer, for a
selected tile with a setup, a way to return every setting to its default at once.

Source: Decision (maintainer, 2026-11-24): the setup is temporary, so the user must see which tiles
carry one.

#### Scenario: Marked and cleared

- **WHEN** the meter's tile has its style set, and the user chooses to return its settings to their
  defaults
- **THEN** the meter's tile is drawn as declared and no longer marked as set up

### Requirement: A library setup lasts until the editor is left

Each card's library setup SHALL last while its scene's editor is open, across edits, undo and
changes of the scene's settings, and SHALL be gone when the editor is left. A setup is not a scene
edit: Undo and Redo SHALL not reach it.

Source: Decision (maintainer, 2026-11-24): the change remains until that scene is exited.

#### Scenario: Leaving the scene

- **WHEN** the meter's tile is set up in "Studio" and the user goes back to the gallery and opens
  "Studio" again
- **THEN** the meter's tile is drawn as declared and no longer marked as set up

#### Scenario: Changing the scene's colours

- **WHEN** the meter's tile is set up and the user changes the scene's colours
- **THEN** the tile is drawn again in the new colours, keeping its setup

### Requirement: A built-in scene's library can be set up

On a scene the canvas may not edit, a library tile SHALL still be selected, set up and drawn with its
setup, though its card cannot be dropped.

Source: Decision (maintainer, 2026-11-24): the setup shows what a card can do; it changes no scene.

#### Scenario: Looking at RTA

- **WHEN** the user opens the built-in RTA, clicks the meter's tile and sets its style
- **THEN** the tile is drawn with that style, and the scene is unchanged
