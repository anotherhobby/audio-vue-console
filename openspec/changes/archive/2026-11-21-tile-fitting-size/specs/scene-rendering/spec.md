# Spec Delta

## MODIFIED Requirements

### Requirement: A library tile is the card's plate as the helper draws it

Each library tile SHALL show the plate the helper draws for its card alone, in the open scene's
settings, at the smallest size on the panel's grid at which the card shows its reading in those
settings, scaled to fit, over the scene's backdrop where it lies under the plate. With no backdrop drawn,
the plate SHALL sit on the library's plain ground. Where the card's declared minimum is larger than that
size, the tile SHALL be drawn at the declared minimum.

Source: Decision (maintainer, 2026-11-07), amended (maintainer, 2026-11-21): a tile holds one card at its
minimum for the chosen font size, so a user can see the smallest the card can be at the scene's type.
audio-vue `scene-render`: a request may name its plates; `card-layout`: a card's declared minimum is the
same span on every scene.

#### Scenario: Opening a scene

- **WHEN** the user opens a scene of the connected panel and the helper is running
- **THEN** each library tile shows its card's plate as the helper draws it at the smallest size that shows
  its reading in that scene's settings, over the scene's backdrop as it lies at the display's top-left
  corner

#### Scenario: Larger type than the declared minimum

- **WHEN** a scene's text is set above its default, so a readout at its declared minimum shows the
  too-small notice
- **THEN** the readout's tile is drawn at the smallest larger size at which its reading fits, not at the
  declared minimum

#### Scenario: A card whose minimum is the smallest size

- **WHEN** the smallest size at which a card's reading fits is its declared minimum
- **THEN** the tile is drawn at the declared minimum

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

### Requirement: A card that cannot show its reading at its minimum is named on its tile

When the helper reports a card as unable to show its reading at the size its tile is drawn at, its library
tile SHALL say so. Where no size on the grid shows the reading, the tile SHALL be drawn at the card's
declared minimum and say so.

Source: audio-vue `scene-render`, "The answer says what does not fit". audio-vue `card-layout`: the
too-small check. Amended (maintainer, 2026-11-21) with the tile's size under the scene's settings.

#### Scenario: A card too small at its minimum

- **WHEN** the helper reports the loudness table as too small to show its reading at its declared minimum
  on the open scene's grid, and no larger size shows it
- **THEN** the loudness table's tile is drawn at its declared minimum and says it is too small to show its
  reading

### Requirement: Library tiles follow the scene's settings, not its cards

The library's tiles SHALL be drawn again only when the open scene's settings, as edited, differ
from those they were drawn for. An edit to the scene's cards SHALL draw no tile again. Tiles
SHALL appear one by one as they are drawn, each a plain box until then.

Source: Decisions (maintainer, 2026-11-07, 2026-11-08), amended (maintainer, 2026-11-21): tiles are drawn in the
open scene's settings, as edited; a tile holds one card at its minimum for the chosen font size, which no layout
edit changes.

#### Scenario: Moving a card

- **WHEN** the user moves a card on the canvas
- **THEN** no library tile is drawn again

#### Scenario: Two scenes with the same settings

- **WHEN** the user opens a scene, then another whose settings and grid are the same
- **THEN** the second scene's library shows the tiles already drawn, and none is drawn again

#### Scenario: A scene with other settings

- **WHEN** the user opens a scene whose settings differ from the last scene's and whose tiles
  were not drawn ahead or before
- **THEN** the library shows plain boxes, each replaced by its drawn plate as it arrives

#### Scenario: Editing a colour

- **WHEN** the user changes one of the open scene's colours
- **THEN** the library's tiles are drawn again in the new colour

## ADDED Requirements

### Requirement: A library tile names the size it is drawn at

Each library tile SHALL name, in its caption, the size its card is drawn at in grid cells, and SHALL name
the card's declared minimum only when it is drawn at that minimum.

Source: Decision (maintainer, 2026-11-21): a tile's size can differ from the declared minimum, so the
caption says which size the preview is, and the user sees the smallest the card can be at the scene's type.
The caption is the tile's drawn size, not the card's size on the open scene.

#### Scenario: A tile above its minimum

- **WHEN** a readout's tile is drawn at 12 by 5 cells, above its declared minimum of 8 by 4
- **THEN** its caption names 12 by 5 cells

#### Scenario: A tile at its minimum

- **WHEN** a card's tile is drawn at its declared minimum
- **THEN** its caption names the declared minimum

### Requirement: A tile's size is the first size on a ladder that shows its reading

The console SHALL find each library tile's size by asking the helper about sizes on a ladder that grows from
the card's declared minimum by equal whole-cell steps in width and height, and SHALL take the first size on
that ladder whose reading fits.

Source: Decision (maintainer, 2026-11-21): the smallest fitting size, found with few renders. The ladder is
the console's choice, since the helper reports one size at a time.

#### Scenario: The first size that fits

- **WHEN** a readout's declared minimum shows the too-small notice and a larger size on the ladder shows its
  reading
- **THEN** the tile takes the first size on the ladder that shows the reading, and no size before it

### Requirement: An aspect-locked card keeps its shape on the ladder

A card whose sizing is aspect-locked SHALL step in its declared aspect on the ladder, so its tile keeps the
card's shape at every size tried.

Source: Decision (maintainer, 2026-11-21): an aspect-locked card's smallest real shape is the one its tile shows.

#### Scenario: A round card

- **WHEN** a card with a declared aspect of 1 is searched for a tile
- **THEN** every size tried on the ladder is square

### Requirement: A tile's size is found once for a set of settings

The console SHALL find a tile's size once for a set of scene settings. The size SHALL NOT be found again for
a tile or a redraw while the settings are the same.

Source: Decision (maintainer, 2026-11-21): the size is found when the settings change, and nothing else draws
other sizes.

#### Scenario: Moving a card

- **WHEN** the user moves a card on the open scene
- **THEN** no tile's size is found again, and no tile is drawn again

#### Scenario: Changing the font size

- **WHEN** the user changes a text role's size in the open scene's settings
- **THEN** each tile's size is found once for the new settings, and each tile is drawn once at that size

#### Scenario: A card that fits at no size on the grid

- **WHEN** the helper reports no size on the grid at which a card shows its reading
- **THEN** the card's tile is drawn at its declared minimum and says it is too small to show its reading
