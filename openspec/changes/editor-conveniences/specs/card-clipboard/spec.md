# Spec Delta

## Purpose

Copying or cutting cards from a scene and pasting them into any scene of the connected panel, set
up as they were, so a card arranged and set just so is never rebuilt by hand.

## ADDED Requirements

### Requirement: Copy takes the selected cards as they are

Copy (⌘C), with the canvas focused and a card selected, SHALL copy every selected card, whole groups
included, on the grid or parked, with its kind, size, place relative to the others, group and every
part of its entry the scene holds, settings included. It SHALL change no scene. With nothing selected
it SHALL copy nothing and leave what was copied before.

Source: Decision (maintainer, 2026-11-24): a card pastes with its current config; groups too.

#### Scenario: Copying a meter

- **WHEN** the user selects a 10 × 6 meter with its style set to bar and presses ⌘C
- **THEN** the scene is unchanged and not marked unsaved, and Paste is enabled

#### Scenario: Copying a group member

- **WHEN** the user clicks one card of a two-card group and presses ⌘C
- **THEN** both cards of the group are copied

### Requirement: Cut copies the selected cards and removes them

Cut (⌘X), with the canvas focused and a card selected, SHALL copy the selection as Copy does, then
remove every copied card from the scene, as one step named Cut. With nothing selected it SHALL do
nothing. On a scene the canvas may not edit it SHALL be refused, saying built-in scenes are
duplicated to edit, removing nothing and leaving what was copied before.

Source: Decision (maintainer, 2026-11-24): ⌘X as well as ⌘C and ⌘V.

#### Scenario: Cutting a group member

- **WHEN** the user clicks one card of a two-card group and presses ⌘X
- **THEN** both cards are removed and copied, and Edit offers Undo Cut

#### Scenario: Cut, then paste in the same scene

- **WHEN** the user cuts a meter and presses ⌘V in the same scene
- **THEN** the meter is back in the cells it was cut from, with its settings

#### Scenario: Cutting from a built-in scene

- **WHEN** a meter is copied and the user selects a card of the built-in RTA and presses ⌘X
- **THEN** nothing is removed, the canvas says built-in scenes are duplicated to edit, and pasting
  still pastes the meter

### Requirement: A copy lasts and reaches every scene of the panel

What was copied SHALL stay copied until something else is copied, and SHALL be pasted into the scene
it came from or any other scene of the panel opened afterwards. Pasting SHALL leave it copied, so it
can be pasted again.

Source: Decision (maintainer, 2026-11-24): copy and paste carry between scenes.

#### Scenario: Into another scene

- **WHEN** the user copies a meter in "Studio", goes back to the gallery, opens "Live" and presses ⌘V
- **THEN** the meter is added to "Live" with the settings it had in "Studio"

#### Scenario: Pasting twice

- **WHEN** the user presses ⌘V twice with a meter copied and room for both
- **THEN** two meters are added, each in the free cells nearest the copied cells

#### Scenario: Text copied since

- **WHEN** the user copies a meter, then copies text in the library's search, then presses ⌘V on the
  canvas
- **THEN** Paste is disabled on the canvas, as no card is copied

### Requirement: A paste lands on the panel in the nearest free cells

Paste (⌘V) SHALL add the copied cards as one block, keeping their sizes, arrangement and settings.
Where the block's copied cells on the panel are free it SHALL land there, else in the free cells
nearest them. It SHALL be one step named Paste, and the pasted cards SHALL be selected.

Source: Decision (maintainer, 2026-11-24): a copied card pastes into available space on the panel,
nearest to where it was copied from.

#### Scenario: Pasting into another scene with the cells free

- **WHEN** a meter copied from columns 0–9, rows 0–5 is pasted into a scene with those cells free
- **THEN** it is added in columns 0–9, rows 0–5 and selected, and Edit offers Undo Paste

#### Scenario: Pasting where it was copied

- **WHEN** the user copies a meter and pastes it in the same scene, with free cells to its right
- **THEN** the copy is added in the free cells nearest the meter, and the meter is unchanged

#### Scenario: A group keeps its arrangement

- **WHEN** a group of two cards side by side is pasted
- **THEN** the two copies are side by side as before, forming one new group of their own

### Requirement: A paste with no room on the panel parks the cards

Where no free cells on the panel hold the block, Paste SHALL park it off the panel (`card-parking`),
within the canvas pane and on no parked card: above the panel where there is room, else below, else
left, else right, at the nearest place to its copied cells on that side.

Source: Decision (maintainer, 2026-11-24): with no space on the panel, the cards paste into the
space above it.

#### Scenario: A full panel

- **WHEN** every cell of the panel is covered and the user pastes a meter
- **THEN** the meter is parked above the panel, and the canvas says one card is off the panel

#### Scenario: No room above

- **WHEN** the panel is full and the pane has too few rows above the panel for the meter but enough
  below
- **THEN** the meter is parked below the panel

### Requirement: A paste with no room anywhere says so

Where the block fits neither on the panel nor off it in the pane, Paste SHALL add nothing and the
canvas SHALL say there is no room to paste the copied cards, as a refusal (`scene-canvas`, "A refused
edit says why").

Source: Decision (maintainer, 2026-11-24): if there is no space anywhere, say there is no room to
paste the copied cards.

#### Scenario: Nowhere to go

- **WHEN** the panel is full and the pane around it has no free place the copied block fits
- **THEN** nothing is added, and the canvas says there is no room to paste the copied cards

### Requirement: Paste is refused where the scene cannot take the cards

Paste SHALL be disabled where nothing is copied. On a built-in scene it SHALL be refused, saying
built-in scenes are duplicated to edit. A copied card the panel's schema does not mark placeable
SHALL refuse the whole paste, naming it.

Source: `scene-canvas`, "A read-only scene can be looked at, not edited", and "The library offers the
host's placeable cards".

#### Scenario: Into a built-in scene

- **WHEN** the user opens the built-in RTA and presses ⌘V with a meter copied
- **THEN** nothing is added, and the canvas says built-in scenes are duplicated to edit

#### Scenario: A card the panel no longer places

- **WHEN** the copied cards include one the panel's schema does not mark placeable
- **THEN** nothing is pasted, and the canvas names the card it cannot place

### Requirement: Copy, Cut and Paste leave text alone

Copy, Cut and Paste SHALL act on cards only while the canvas has focus. In a text field, such as the
library's search or an inspector field, they SHALL copy, cut and paste text as usual.

Source: macOS: the Edit menu's Copy and Paste act on what has focus.

#### Scenario: Copying a typed value

- **WHEN** the user selects the text of a number field in the inspector and presses ⌘C
- **THEN** the text is copied, and no card is

#### Scenario: Cutting typed text

- **WHEN** the user selects the library's search text and presses ⌘X
- **THEN** the text is cut, and no card is removed
