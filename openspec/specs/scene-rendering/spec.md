# scene-rendering Specification

## Purpose

What the canvas and the gallery draw from the render helper's layers: what each request carries from
the host, how the layers are stacked and placed, and which edits draw what again.

## Requirements

### Requirement: A scene is drawn as the helper's layers

The canvas SHALL draw a scene as the helper's layers, stacked in the order given, each at its rect,
at the panel's pixel size scaled by one factor to fit the view. The app SHALL draw only the grid,
outlines, handles and messages over them.

Source: `product.md`, "The decision" (maintainer, 2026-11-06). audio-vue `scene-render`: the backdrop
and each plate are layers, in order.

#### Scenario: Opening a scene

- **WHEN** the user opens a scene of the connected panel and the helper is running
- **THEN** the canvas shows its backdrop and every plate as the helper drew them, under the scene's
  grid

### Requirement: A request carries the host's scene and settings

Each render request SHALL carry the scene as the host's store holds it, whether it is built in, the
panel's display size, the install's fonts block, the preview rate, the directory of fetched images,
and the default scene's backdrop as the fallback.

Source: audio-vue `scene-render`, "A request carries a scene and its display". Decision
(maintainer, 2026-11-07): the rate does not matter to a preview, so one is picked.

#### Scenario: A host with its own fonts

- **WHEN** the host's fonts block sets a larger value size than the default
- **THEN** the render request carries that block, and the cards are drawn at the host's sizes

#### Scenario: A panel whose size is not known

- **WHEN** the host gives no display size
- **THEN** the scene is drawn at 1920 by 1080 pixels, and the canvas says the panel's size is not
  known

### Requirement: Backdrop images are fetched before they are drawn

Before drawing a scene whose backdrop, or whose fallback, names an image, the app SHALL fetch that
image from the host into a directory in its container, named by its id, unless it holds it already.
A missing or unreadable image SHALL be said as the helper says it.

Source: audio-vue `scene-render`, "Backdrop images come from the client". audio-vue `control-api`:
images are named by id, and shipped images are served with uploads.

#### Scenario: An image not yet held

- **WHEN** a scene's backdrop names an image the app has not fetched
- **THEN** the app fetches it, then draws the scene with it

#### Scenario: An image the host does not have

- **WHEN** a scene's backdrop names an image the host does not hold
- **THEN** the scene is drawn with the fallback backdrop, and the canvas says the backdrop image is
  missing

### Requirement: A move slides the plates and draws them again on release

While the selection is dragged, its plates' layers SHALL move with it, whole cells at a time, with no
request. When the move is made, the moved plates SHALL be drawn again.

Source: audio-vue's handoff (2026-11-07): moving a plate needs no request. audio-vue `scene-grid`: a
slot keeps a whole gap at the region's edge and half a gap between cards, so a moved plate's size can
change by half a gap.

#### Scenario: A drag

- **WHEN** the user drags a card three columns right
- **THEN** its plate moves with the pointer, and once released it is drawn again in its new cells

### Requirement: A resize draws the plate again at each cell step

While a card is resized, its plate SHALL be drawn again each time its size changes by a cell, the
latest size replacing any request not yet sent. Until the new layer arrives the old one SHALL be
stretched to the new size.

Source: audio-vue's handoff (2026-11-07): a resize asks for that plate alone. Measured (2026-11-07):
one plate drawn again in 25 ms, sandboxed.

#### Scenario: A resize across several cells

- **WHEN** the user drags a card's handle five columns wider without pausing
- **THEN** the plate is drawn again at sizes as the helper keeps up, and at the final size once
  released

### Requirement: An edit draws again only what it changed

After any edit, undo or redo, the canvas SHALL draw again every plate whose cards, cells or group
changed, SHALL drop the layers of removed cards, and SHALL leave every other layer as it is.

Source: audio-vue's handoff (2026-11-07): a resize asks for that plate alone, and a backdrop change
for the backdrop.

#### Scenario: Grouping

- **WHEN** the user groups two cards
- **THEN** the two plates are replaced by one layer drawn for the group, and no other plate is drawn
  again

#### Scenario: Deleting

- **WHEN** the user deletes a card
- **THEN** its layer is gone, and no request is sent

### Requirement: A card that cannot show its reading is named

When the helper reports cards that cannot show their reading at the size drawn, the canvas SHALL name
them while they are reported.

Source: audio-vue `scene-render`, "The answer says what does not fit". audio-vue `card-layout`: the
too-small check.

#### Scenario: A card made too small

- **WHEN** the user shrinks a waveform card below the size it can show its reading at
- **THEN** the canvas names the waveform as too small to show its reading

### Requirement: A scene the helper cannot draw is drawn as boxes

When the helper has not started, refuses the scene, or failed, the canvas SHALL draw the scene's
cards as plain boxes with their names and SHALL say why. Editing SHALL work as it does with layers.

Source: audio-vue `scene-render`: a scene the panel would refuse is refused with the panel's own
sentence.

#### Scenario: A refused scene

- **WHEN** the helper refuses a scene with the panel's reason
- **THEN** the canvas shows the cards as plain boxes, and the reason

#### Scenario: A scene opened while the helper starts

- **WHEN** the user opens a scene before the helper has made its first run
- **THEN** the canvas shows the cards as plain boxes and says the renderer is starting, then shows the
  layers once they are drawn

#### Scenario: A helper that could not start

- **WHEN** a scene is opened after the helper failed to start
- **THEN** the canvas shows the cards as plain boxes, and says the renderer could not start and why

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
