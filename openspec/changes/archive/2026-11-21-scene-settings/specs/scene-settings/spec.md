# Spec Delta

## Purpose

How the editor's inspector reads and changes the open scene's own settings, its backdrop, glass,
grid, display, typeface, colours, text sizes and analysis, generated from the host's settings
schema.

## ADDED Requirements

### Requirement: The inspector shows the scene's settings when no card is selected

With no card selected, the inspector SHALL show tabs: Scene (Backdrop, Cards, Grid, Display), Style
(Colours, then Text: the typeface, then the sizes), Analysis, and Other for any other block or
setting, by its name. Cards is the `glass` block. Settings SHALL behave as `card-settings` says.

Source: `product.md`: every scene setting through the app. Maintainer, 2026-11-08 to 2026-11-20:
the tabs; Cards, not Glass; the typeface with the sizes.

#### Scenario: Opening a scene

- **WHEN** the user opens a scene and selects nothing
- **THEN** the inspector shows the tabs Scene, Style and Analysis, with no Other tab, and Scene
  lists Backdrop, Cards, Grid and Display

#### Scenario: The typeface is with the sizes

- **WHEN** the user opens the Style tab
- **THEN** Text lists Typeface first, then a size for each kind of text

#### Scenario: A colour

- **WHEN** the scene sets no colours and the user sets Title to `#00FF88` in the colour panel
- **THEN** the scene's colours set `title` alone, every card's title is drawn again in it, and Title
  offers Use Default

#### Scenario: A text size

- **WHEN** the user sets Title size to 60
- **THEN** every card's title on the canvas is drawn at 60 reference pixels

#### Scenario: The typeface

- **WHEN** the user chooses Oxanium as the typeface
- **THEN** the scene sets `typeface` to `oxanium`, and every card's text is drawn in it

#### Scenario: A block the app does not know

- **WHEN** the schema declares a scene block no build of the app has seen
- **THEN** an Other tab shows it under its name, with its settings

### Requirement: An unset setting shows the value of the block it inherits from

A setting that declares the block its unset value comes from SHALL show that block's setting of the
same key, stored or else its default, and say whose it uses: the panel's for an install block, the
scene's for a scene block. Use Default SHALL return a set one to it.

Source: audio-vue `settings-schema`: `x-inherits` names `<document>.<block>`, and such a setting
declares no default. Maintainer, 2026-11-20: 0 shown where the panel waits 10 minutes is confusing.

#### Scenario: A panel that waits ten minutes

- **WHEN** the install's display block stores `saver_after_min: 10` and the scene sets none
- **THEN** Screensaver after shows 10 and says it uses the panel's, with no Use Default

#### Scenario: The scene's own

- **WHEN** the user then sets Screensaver after to 2
- **THEN** the scene's display block sets `saver_after_min: 2`, and Use Default shows 10 again

### Requirement: An amount is set by a slider

A number the schema bounds from 0 to 1 SHALL be set by a slider and shown as a percentage, for a
scene's and a card's settings alike. A drag SHALL be one edit, made as it ends, kept to the
setting's step where it declares one.

Source: maintainer, 2026-11-20: opacity as a slider. audio-vue `settings-schema`: bounds and
`x-step`.

#### Scenario: Opacity

- **WHEN** the user drags the Cards section's Opacity to 60%
- **THEN** the scene's glass sets `opacity: 0.6` as one undoable step, and the plates are drawn again

### Requirement: The scene's colours are shown by group

The Colours section SHALL show a colour well for each role under its declared group, in declared
order, then one for each step of each meaning scale under the scale's label, then any other setting
of the block, such as the shadow's amount, as a row.

Source: audio-vue `card-colours`: one colour per role, in groups; Warnings and Stereo phase are
scales; shadow is an amount. The export lists them as `x-roles` and `x-scales`.

#### Scenario: The groups

- **WHEN** the user opens the Style tab
- **THEN** Colours shows Background, Text, Lines and Signal, then Warnings with OK, Caution and
  Alert, then Stereo phase, then Shadow as a number from 0 to 1

#### Scenario: A warning colour

- **WHEN** the user sets Alert to `#FF0000`
- **THEN** every card drawing a reading past its limit is drawn again in it

### Requirement: The backdrop is one source

The Backdrop section SHALL offer Default, Colour, Gradient and Image. Default SHALL remove the
backdrop, so the default backdrop shows. Another source SHALL replace the one held as one step;
Blur SHALL stay, and the angle SHALL be held only with a gradient.

Source: audio-vue `scene-backdrop`: one of a colour, a gradient or an image; a scene with none draws
the `default` style's. audio-vue refuses an angle without a gradient (`src/schema/scene.py`).

#### Scenario: From gradient to colour

- **WHEN** a scene's backdrop is a gradient and the user chooses Colour
- **THEN** the backdrop holds a colour and no gradient and no angle, starting from the gradient's
  first stop

#### Scenario: Default

- **WHEN** the user chooses Default
- **THEN** the scene holds no backdrop, and the canvas shows the default backdrop

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

### Requirement: A gradient returns to the default backdrop's

While the default look's backdrop is a gradient, a gradient SHALL offer Use Default Gradient beside
Add Stop: it SHALL set the stops and the angle to the default backdrop's as one undoable step,
keeping the blur, and SHALL be disabled where the scene already holds them.

Source: maintainer, 2026-11-20. audio-vue `styles`: the built-in `default` style holds the default
backdrop (`GET /v1/styles/default`).

#### Scenario: Back to the default's

- **WHEN** the user has changed two stops and chooses Use Default Gradient
- **THEN** the stops and angle are the default backdrop's, the blur is as it was, and one undo
  brings the changed stops back

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

- **WHEN** the user saves after changing a colour
- **THEN** the stored scene's colours hold the change, and its cards are as they were

### Requirement: A read-only scene's settings are shown, not changed

On a scene the canvas may not edit, the inspector SHALL show the scene's settings and values and
SHALL offer no change.

Source: `scene-canvas`, "A read-only scene can be looked at, not edited".

#### Scenario: A built-in scene

- **WHEN** the user opens a built-in scene and selects nothing
- **THEN** its settings are shown, and none of them can be changed
