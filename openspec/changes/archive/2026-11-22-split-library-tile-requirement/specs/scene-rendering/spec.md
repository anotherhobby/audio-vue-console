# Spec Delta

## MODIFIED Requirements

### Requirement: A library tile is the card's plate as the helper draws it

Each library tile SHALL show the plate the helper draws for its card alone, in the open scene's
settings, scaled to fit.

Source: Decision (maintainer, 2026-11-07): a tile holds one card. audio-vue `scene-render`: a
request may name its plates.

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

## ADDED Requirements

### Requirement: A library tile is drawn at the smallest size that shows its reading

Each library tile SHALL be drawn at the smallest size on the panel's grid at which its card shows
its reading in the open scene's settings. Where the card's declared minimum is larger than that
size, the tile SHALL be drawn at the declared minimum.

Source: Decision (maintainer, 2026-11-07), amended (maintainer, 2026-11-21): a tile shows the
smallest the card can be at the scene's type. audio-vue `card-layout`: a declared minimum is the
same span on every scene.

#### Scenario: A readout that first fits above its minimum

- **WHEN** a readout's declared minimum is 8 by 4 cells and its reading first fits at 10 by 5 in
  the scene's type
- **THEN** its tile is drawn at 10 by 5

### Requirement: A library tile's plate lies over the backdrop under it

Each library tile SHALL show its plate over the scene's backdrop where it lies under the plate.
With no backdrop drawn, the plate SHALL sit on the library's plain ground.

Source: Decision (maintainer, 2026-11-07): a tile is the plate as the panel would show it.

#### Scenario: A gradient backdrop

- **WHEN** the scene's backdrop runs from navy at its left edge to black at its right
- **THEN** each tile shows its plate over the backdrop as it lies at the display's top-left corner,
  near navy

#### Scenario: No backdrop yet

- **WHEN** the library's tiles are drawn and no backdrop has been drawn
- **THEN** each tile's plate sits on the library's plain ground
