# Spec Delta

## Purpose

How the editor's inspector reads and changes the open scene's own settings, its backdrop, palette,
elements, glass, type, analysis, display and grid, generated from the host's settings schema.

## ADDED Requirements

### Requirement: The inspector shows the scene's settings when no card is selected

With no card selected, the inspector SHALL show the scene's name and kind, then tabs: Look
(Backdrop, Glass, Type), Colours (Palette, Elements), Analysis (Analysis, Display), Grid, and Other
for any other block, by its name. Settings SHALL behave as `card-settings` says.

Source: `product.md`: every scene setting through the app. Decisions (maintainer, 2026-11-08,
2026-11-09): in the inspector, in tabs. audio-vue `settings-schema`: a block has no label.

#### Scenario: Opening a scene

- **WHEN** the user opens a scene and selects nothing
- **THEN** the inspector shows its name and kind, then the tabs Look, Colours, Analysis and Grid,
  with no Other tab

#### Scenario: A palette colour

- **WHEN** the scene sets no palette and the user sets Signal to `#00FF88` in the colour panel
- **THEN** the scene's palette sets `signal` alone, every card drawing the signal colour is drawn
  again in it, and Signal offers Use Default

#### Scenario: A type role

- **WHEN** the user sets Title size to S
- **THEN** every card's title on the canvas is drawn at S

#### Scenario: A block the app does not know

- **WHEN** the schema declares a scene block no build of the app has seen
- **THEN** an Other tab shows it under its name, with its settings

### Requirement: A scene's elements point at its swatches

The Elements section SHALL offer, for each element, every palette swatch, each shown in the colour
the scene gives it as edited. Choosing a swatch SHALL draw that element in it on every card that
sets no colour of its own for the element.

Source: audio-vue `card-colours`, "A colour resolves by lookup" and "Status colours are
scene-wide": a scene's `elements:` block points any element at a swatch.

#### Scenario: Titles in the text colour

- **WHEN** the user points Title at Text
- **THEN** every card's title is drawn in the scene's Text colour, and Title offers Use Default

#### Scenario: A swatch changed under an element

- **WHEN** Title points at Text and the user changes the palette's Text
- **THEN** Title's choice shows the new colour, and every card's title is drawn in it

#### Scenario: A card's own colour

- **WHEN** the scene points Grid minor at Accent and an `rta_bars` card sets its own minor line
  colour
- **THEN** that card's minor lines keep its own colour

### Requirement: The palette and the elements are shown by family

The Palette section SHALL show its swatches as colour wells, and the Elements section its elements
as one row each, both under their declared families in declared order, each element family
collapsible.

Source: audio-vue `card-colours`, "The palette has three families"; the export declares each
swatch's and each element's family.

#### Scenario: The palette

- **WHEN** the user opens the Palette section
- **THEN** Signal, Signal alt and Signal 3 are together under their family, before the sequence
  swatches

### Requirement: The backdrop is one source

The Backdrop section SHALL offer None, Colour, Gradient and Image. None SHALL remove the backdrop,
so the palette's background shows. Another source SHALL replace the one held as one step; Blur
SHALL stay, and the angle SHALL be held only with a gradient.

Source: audio-vue `scene-backdrop`: one of a colour, a gradient or an image; none shows the
palette's background. audio-vue refuses an angle without a gradient (`src/schema/scene.py`).

#### Scenario: From gradient to colour

- **WHEN** a scene's backdrop is a gradient and the user chooses Colour
- **THEN** the backdrop holds a colour and no gradient and no angle, starting from the gradient's
  first stop

#### Scenario: None

- **WHEN** the user chooses None
- **THEN** the scene holds no backdrop source, and the canvas shows the palette's background

### Requirement: A source chosen again comes back as it was

Choosing again a source the backdrop held while the scene was open SHALL bring back what it held:
the gradient's stops and angle, the colour, or the image.

Source: Decision (maintainer, 2026-11-09): switching back to a source must not lose what it held.

#### Scenario: Back to the gradient

- **WHEN** a scene's backdrop is a three-stop gradient at 90°, and the user chooses Colour, then
  Gradient
- **THEN** the backdrop is the same three stops at 90°

### Requirement: A gradient's stops and angle are edited

A gradient SHALL show its stops in order, each a colour through the system colour panel, which the
user can add, remove and reorder, and its angle in degrees. A gradient SHALL keep at least two
stops: removing a stop SHALL be refused while two remain.

Source: audio-vue `scene-backdrop`: a gradient runs through two or more stops at a CSS angle.

#### Scenario: Adding a stop

- **WHEN** a gradient has two stops and the user adds one
- **THEN** it has three, the new one after the last, and the backdrop is drawn again through all three

#### Scenario: Two stops left

- **WHEN** a gradient has two stops
- **THEN** neither can be removed

#### Scenario: The angle

- **WHEN** the user sets the angle to 90
- **THEN** the backdrop runs from its first stop at the left to its last at the right

### Requirement: A backdrop image is chosen from the host or uploaded

Choosing Image SHALL list the host's images, uploaded and shipped, and SHALL offer to upload a PNG or
JPEG from a file. An upload the host refuses SHALL say why and leave the backdrop as it was. An
uploaded image SHALL be listed and chosen at once.

Source: audio-vue `settings-store`: images are uploaded to the host, named by their id, and a scene
names an image by its id.

#### Scenario: Uploading

- **WHEN** the user uploads a 3,000 px JPEG
- **THEN** it is stored on the host, chosen as the backdrop, and drawn on the canvas

#### Scenario: Too large

- **WHEN** the user uploads an image larger than the host takes
- **THEN** the inspector says the host refused it and why, and the backdrop is unchanged

### Requirement: The scene says when no calibration holds at its rate

The Analysis section SHALL say so where no calibration holds for the host's chain at the scene's
rate, its capture rate or else the installed rate, and SHALL say nothing where one holds, whatever
the rate.

Source: Decision (maintainer, 2026-11-08): a scene may capture at any rate the host is calibrated
at; the user is told only when calibration does not hold. audio-vue applies the newest record valid
for the device and rate in use.

#### Scenario: A calibrated rate

- **WHEN** the host holds a valid calibration at 96,000 Hz and the user sets the scene's capture
  rate to 96,000 Hz
- **THEN** no warning is shown

#### Scenario: An uncalibrated rate

- **WHEN** the host holds no valid calibration at 44,100 Hz and the user sets the scene's capture
  rate to 44,100 Hz
- **THEN** the Analysis section says no calibration holds at 44,100 Hz, so this scene's readings
  are uncalibrated

#### Scenario: The installed rate uncalibrated

- **WHEN** the scene sets no capture rate and the host holds no valid calibration at the installed
  rate
- **THEN** the Analysis section says so for the installed rate

### Requirement: The grid's density changes columns and rows together

The Grid section SHALL offer the grids at the scene's own aspect whose rows run from 18 to 108 and
whose columns are whole. Choosing one SHALL move every card to the cells that cover the same part of
the scene, edges rounded to the nearest cell, as one step.

Source: Decision (maintainer, 2026-11-08): scene settings change the grid's gap and its density.
audio-vue `scene-grid`: placements stay on the declared grid.

#### Scenario: Finer

- **WHEN** a 64 by 36 scene with a card at column 16, 32 columns wide, is changed to 96 by 54
- **THEN** the card is at column 24, 48 columns wide, and the scene keeps its shape

#### Scenario: The choices keep the aspect

- **WHEN** the user opens the density choices on a 96 by 36 scene
- **THEN** every choice is 8:3, such as 48 by 18 and 144 by 54

#### Scenario: Groups stay whole

- **WHEN** a scene with a group of two cards is made finer
- **THEN** the two cards still tile one rectangle

### Requirement: A density that would shrink a card below its minimum is refused

A density SHALL be refused, naming the card and leaving the grid as it was, where a card would fall
below its minimum on the new grid.

Source: audio-vue `card-layout`: each card's minimum, on a 36-row grid, scaled to the scene's rows.

#### Scenario: Too coarse

- **WHEN** a choice would leave a card smaller than its minimum
- **THEN** the grid is unchanged, and the inspector names the card

### Requirement: A scene setting change is an edit to the open scene

A change to a scene setting SHALL be drawn on the canvas, mark the scene unsaved, be one step that
Undo and Redo reverse and repeat in the same history as layout edits, and be stored by Save or
Apply.

Source: `product.md`: saves are explicit; no live preview on the panel. Decision (maintainer,
2026-11-03): undo and redo for every edit.

#### Scenario: Undoing across kinds of edit

- **WHEN** the user moves a card, then changes the backdrop, then undoes twice
- **THEN** the backdrop is restored, then the card is where it was

#### Scenario: Saving

- **WHEN** the user saves after changing the palette
- **THEN** the stored scene's palette holds the change, and its cards are as they were

### Requirement: A read-only scene's settings are shown, not changed

On a scene the canvas may not edit, the inspector SHALL show the scene's settings and values and
SHALL offer no change.

Source: `scene-canvas`, "A read-only scene can be looked at, not edited".

#### Scenario: A built-in scene

- **WHEN** the user opens a built-in scene and selects nothing
- **THEN** its settings are shown, and none of them can be changed
