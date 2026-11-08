# Spec Delta

## ADDED Requirements

### Requirement: A library tile is the card's plate as the helper draws it

Each library tile SHALL show the plate the helper draws for its card alone, in the open scene's
settings, at the card's minimum on that scene's grid and the panel's pixel size, scaled to fit, over
the scene's backdrop where it lies under the plate. With no backdrop drawn, the plate SHALL sit on the
library's plain ground.

Source: Decision (maintainer, 2026-11-07). audio-vue `scene-render`: a request may name its plates.

#### Scenario: Opening a scene

- **WHEN** the user opens a 36-row scene of the connected panel and the helper is running
- **THEN** each library tile shows its card's plate as the helper draws it at the card's minimum on a
  36-row grid, in that scene's settings, over the scene's backdrop as it lies at the region's
  top-left corner

#### Scenario: The backdrop arrives after the tiles

- **WHEN** tiles are drawn before the canvas's backdrop
- **THEN** each tile is shown over the backdrop once it arrives, and no tile is drawn again

#### Scenario: A refused scene

- **WHEN** the helper refuses the open scene, so the canvas has no backdrop, and draws the tiles
- **THEN** each tile shows its plate on the library's plain ground

#### Scenario: A read-only scene

- **WHEN** the user opens a built-in scene
- **THEN** the library tiles show the cards drawn in that scene's settings, and a drop is still
  refused

### Requirement: Library tiles follow the scene's settings, not its cards

The library's tiles SHALL be drawn again only when the open scene's settings or grid differ from
those they were drawn for. An edit to the scene's cards SHALL draw no tile again. Tiles SHALL appear
one by one as they are drawn, each a plain box until then.

Source: Decision (maintainer, 2026-11-07): tiles are drawn in the open scene's settings; a tile
holds one card at its minimum, which no layout edit changes.

#### Scenario: Moving a card

- **WHEN** the user moves a card on the canvas
- **THEN** no library tile is drawn again

#### Scenario: Two scenes with the same settings

- **WHEN** the user opens a scene, then another whose settings and grid are the same
- **THEN** the second scene's library shows the tiles already drawn, and none is drawn again

#### Scenario: A scene with other settings

- **WHEN** the user opens a scene whose settings differ from the last scene's
- **THEN** the library shows plain boxes, each replaced by its drawn plate as it arrives

### Requirement: A library tile the helper cannot draw is a box

A library tile SHALL be a plain box with its name while the renderer is starting or failed, where its
card's own code or shared code differs from the panel's, where the card code cannot be compared,
where the card at its minimum does not fit the grid, and where the helper refuses or fails to draw it.

Source: `card-code`. Decision (maintainer, 2026-11-07): code that cannot be compared draws no tile.
`scene-layout`: a layout holds only cards on its grid. audio-vue `scene-render`.

#### Scenario: A changed card

- **WHEN** the waveform card's own code differs from the panel's
- **THEN** the waveform's tile is a plain box, and every other tile is drawn

#### Scenario: A damaged bundle

- **WHEN** the app's render bundle does not match its own manifest
- **THEN** every tile is a plain box, and no tile is asked for

#### Scenario: A card too wide for the grid

- **WHEN** a card's minimum is wider than the open scene's grid
- **THEN** its tile is a plain box, no request is sent for it, and the other tiles are drawn

### Requirement: A card that cannot show its reading at its minimum is named on its tile

When the helper reports a card as unable to show its reading at its minimum, its library tile SHALL
say so.

Source: audio-vue `scene-render`, "The answer says what does not fit". audio-vue `card-layout`: the
too-small check.

#### Scenario: A card too small at its minimum

- **WHEN** the helper reports the loudness table as too small to show its reading at its minimum on
  the open scene's grid
- **THEN** the loudness table's tile says it is too small to show its reading
