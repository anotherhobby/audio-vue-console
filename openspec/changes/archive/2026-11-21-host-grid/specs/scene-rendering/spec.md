# Spec Delta

## ADDED Requirements

### Requirement: A scene too wide is drawn as boxes

The app SHALL ask the helper for no drawing of a scene too wide for the panel, and SHALL show it as
its plain boxes on the canvas and in its thumbnail.

Source: audio-vue `scene-render` (`host-grid` design D5): the helper refuses a scene too wide for the
display size requested. `scene-rendering`, "A scene the helper cannot draw is drawn as boxes".

#### Scenario: Opening a wide scene

- **WHEN** the user opens a scene too wide for the panel
- **THEN** the canvas shows each card as a box, and the helper is asked for nothing

#### Scenario: Made to fit

- **WHEN** the user moves its cards within the panel's columns
- **THEN** the scene is drawn as the helper draws it

## MODIFIED Requirements

### Requirement: A library tile is the card's plate as the helper draws it

Each library tile SHALL show the plate the helper draws for its card alone, in the open scene's
settings, at the card's declared minimum on the panel's grid and pixel size, scaled to fit, over
the scene's backdrop where it lies under the plate. With no backdrop drawn, the plate SHALL sit on the
library's plain ground.

Source: Decision (maintainer, 2026-11-07). audio-vue `scene-render`: a request may name its plates;
`card-layout`: a minimum is the same span on every scene.

#### Scenario: Opening a scene

- **WHEN** the user opens a scene of the connected panel and the helper is running
- **THEN** each library tile shows its card's plate as the helper draws it at the card's declared
  minimum, in that scene's settings, over the scene's backdrop as it lies at the display's top-left
  corner

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
