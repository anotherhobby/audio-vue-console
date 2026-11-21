# Spec Delta

## ADDED Requirements

### Requirement: The canvas has the display's shape

The canvas SHALL show the panel's grid at the display's own width to height, its cells stretched as
the panel stretches them. A scene laid out wider than the panel's grid SHALL be wider by the same
cells.

Source: audio-vue `scene-grid`, "The grid fills the display": cells are near-square, not square.

#### Scenario: A shape with no whole count

- **WHEN** the panel's display is 1024 by 600 and its grid 61 by 36
- **THEN** the canvas is 1024 to 600 wide to tall, each cell 1024 ÷ 61 wide to 600 ÷ 36 tall

### Requirement: A scene too wide shows the columns the panel lacks

On a scene laid out wider than the panel's grid, the canvas SHALL mark the columns past the panel's
last, and SHALL say the scene is too wide for this panel and that moving its cards in makes it fit.
Edits SHALL work on every column shown.

Source: Decision (maintainer, 2026-11-21): a scene too wide is opened on its own reach, the columns
the panel lacks marked.

#### Scenario: Opening a wide scene

- **WHEN** the user opens a stored scene reaching column 96 for a 64-column panel
- **THEN** the canvas shows 96 columns, the last 32 marked, and says the scene is too wide

#### Scenario: Made to fit

- **WHEN** the user moves every card within the first 64 columns
- **THEN** the canvas no longer says the scene is too wide, and still shows the marked columns
  until the scene is opened again

## MODIFIED Requirements

### Requirement: A read-only scene can be looked at, not edited

The canvas SHALL refuse every edit to a built-in scene, and SHALL say that the scene must be
duplicated to edit. Selecting cards SHALL still work.

Source: `product.md`: built-in scenes are read-only. Decision (maintainer, 2026-11-21): a scene is
no longer tied to a display's shape.

#### Scenario: A built-in scene

- **WHEN** the user drags a card from the library onto a built-in scene
- **THEN** nothing is added, and the canvas says built-in scenes are duplicated to edit

#### Scenario: Selecting on a read-only scene

- **WHEN** the user clicks a card on a built-in scene
- **THEN** it is selected and shown in the inspector, without resize handles

### Requirement: The library offers the host's placeable cards

The library SHALL list the cards the host's schema marks placeable under the host's categories,
each headed by its label, both in the schema's order, leaving out a category with no placeable card
or, in a search, no match. A dragged card SHALL take its declared minimum cells.

Source: audio-vue `card-layout` (a minimum is the same span on every scene; placeable) and
`card-categories`. Decision (maintainer, 2026-11-08): categories and card order come from the panel.

#### Scenario: The library

- **WHEN** the host's schema marks the calibration card not placeable and the waveform placeable with
  a minimum of 17 by 10 cells
- **THEN** the library lists the waveform and not the calibration card, and a dropped waveform takes
  17 by 10 cells

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
