# card-minimum Specification

## Purpose

The sizes the render helper answers for a card, as its settings and the scene's settings lay it
out: how the console asks for them, holds them, and picks from them where a card is shown, dropped
and resized.

## Requirements

### Requirement: The console asks the helper for a card's minimum

The console SHALL ask the helper for a card's minimum with the card alone in the open scene's
settings, as a library tile is drawn, and SHALL hold each answer for that card's settings and the
scene's settings. It SHALL ask again when either changes, and SHALL NOT ask again while both are
the same.

Source: audio-vue `scene-render`, "The helper answers where a card is drawn whole" and "... where a
card shows its reading". Decision (maintainer, 2026-11-24): the minimum moves with the settings.

#### Scenario: Turning ticks on

- **WHEN** the selected meter's minimum is held and the user turns its ticks on
- **THEN** the console asks for the meter's minimum again with ticks on

#### Scenario: Moving a card

- **WHEN** the user moves a card whose minimum is held
- **THEN** nothing is asked of the helper

#### Scenario: Two cards alike

- **WHEN** two meters on the scene have the same settings
- **THEN** one answer serves both

### Requirement: A card's whole size is the smallest whole one

Of the sizes the helper answers a card drawn whole at, the console SHALL take the one with the
fewest cells, the narrower on a tie. Where it answers none, the console SHALL take the smallest
readable size by the same rule, and where it answers neither, the card's declared minimum.

Source: Decision (maintainer, 2026-11-24): a card is shown and dropped at its whole minimum, the
smallest area.

#### Scenario: The fewest cells

- **WHEN** the helper answers a meter whole at 8 × 9, 10 × 7 and 12 × 6
- **THEN** its whole size is 10 × 7, of 70 cells

#### Scenario: A tie

- **WHEN** the helper answers a card whole at 8 × 9 and 9 × 8
- **THEN** its whole size is 8 × 9

#### Scenario: Never whole

- **WHEN** the helper answers no whole size for a card, and readable sizes of 10 × 6 and 12 × 5
- **THEN** its whole size is 10 × 6

### Requirement: The readable floor depends on the width

At each width, a card's smallest height SHALL be the readable height the helper answers for that
width, and a resize SHALL narrow a card only to widths whose floor its height meets, never to one
the answer leaves out. A card MAY be widened to any width.

Source: Decision (maintainer, 2026-11-24): a resize may let a card shed detail but stops before
Too Small. audio-vue `scene-render`: the readable height is a floor at every width.

#### Scenario: A narrower card needs more rows

- **WHEN** a waveform's readable heights are 10 rows at 17 columns and 8 rows at 20 columns
- **THEN** at 20 columns it may be 8 rows high, and at 17 columns no lower than 10

#### Scenario: A width left out

- **WHEN** a card 16 columns wide whose answer starts at 12 columns is narrowed by 6
- **THEN** it stops at 12 columns wide

#### Scenario: Widening a card below its floor

- **WHEN** a card 10 columns wide whose answer starts at 17 has its right edge dragged 3 right
- **THEN** it is 13 columns wide

### Requirement: The declared minimum stands in until an answer is held

Until the helper's answer for a card's settings is held, the card's declared minimum SHALL stand in
for its whole size and its floor. A drop, a tile or a resize SHALL never wait for an answer.

Source: Decision (maintainer, 2026-11-24): an answer can take over a second, so a drag reads a held
answer. audio-vue `card-layout`: a declared minimum is the same span on every scene.

#### Scenario: Before the answer

- **WHEN** the user drags a handle of a card whose minimum is still being asked for
- **THEN** the resize stops at the card's declared minimum, without waiting

#### Scenario: A drop before the answer

- **WHEN** the user drags a card in from the library before its tile's minimum is held
- **THEN** it is added at its declared minimum
