# Spec Delta

## MODIFIED Requirements

### Requirement: An edit draws again only what it changed

After any edit, undo or redo, the canvas SHALL draw again every plate whose cards, cells, group or
card settings changed, SHALL drop the layers of removed cards, and SHALL leave every other layer as
it is. A change to the scene's backdrop SHALL draw the backdrop alone again; a change to any other
scene setting SHALL draw the backdrop and every plate again.

Source: audio-vue's handoff (2026-11-07): a resize asks for that plate alone, and a backdrop change
for the backdrop. Decision (maintainer, 2026-11-08): card settings are edited in the inspector
(`card-settings`), and so are scene settings (`scene-settings`).

#### Scenario: Grouping

- **WHEN** the user groups two cards
- **THEN** the two plates are replaced by one layer drawn for the group, and no other plate is drawn
  again

#### Scenario: Deleting

- **WHEN** the user deletes a card
- **THEN** its layer is gone, and no request is sent

#### Scenario: Changing a setting

- **WHEN** the user changes a setting of one card in a group
- **THEN** that group's plate is drawn again, and no other plate is drawn again

#### Scenario: Changing the backdrop

- **WHEN** the user changes the backdrop's gradient
- **THEN** the backdrop is drawn again, and no plate is

#### Scenario: Changing a colour

- **WHEN** the user changes one of the scene's colours
- **THEN** the backdrop and every plate are drawn again

#### Scenario: Changing the typeface

- **WHEN** the user changes the scene's typeface
- **THEN** the backdrop and every plate are drawn again

### Requirement: Library tiles follow the scene's settings, not its cards

The library's tiles SHALL be drawn again only when the open scene's settings or grid, as edited,
differ from those they were drawn for. An edit to the scene's cards SHALL draw no tile again. Tiles
SHALL appear one by one as they are drawn, each a plain box until then.

Source: Decision (maintainer, 2026-11-07): tiles are drawn in the open scene's settings; a tile
holds one card at its minimum, which no layout edit changes. Decision (maintainer, 2026-11-08):
scene settings are edited in the inspector (`scene-settings`).

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

### Requirement: Backdrop images are fetched before they are drawn

Before drawing a scene whose backdrop names an image, the app SHALL fetch that image from the host
into a directory in its container, named by its id, unless it holds it already. A missing or
unreadable image SHALL be said as the helper says it.

Source: audio-vue `scene-render`, "Backdrop images come from the client": a missing image draws the
default backdrop. audio-vue `control-api`: images are named by id, and shipped images are served
with uploads.

#### Scenario: An image not yet held

- **WHEN** a scene's backdrop names an image the app has not fetched
- **THEN** the app fetches it, then draws the scene with it

#### Scenario: An image the host does not have

- **WHEN** a scene's backdrop names an image the host does not hold
- **THEN** the scene is drawn with the default backdrop, and the canvas says the backdrop image is
  missing

## ADDED Requirements

### Requirement: A request carries the host's scene, viewing and styles

Each render request SHALL carry the scene as the host's store holds it, whether it is built in, the
panel's display size, the install's viewing block, the preview rate, the directory of fetched
images, and the stored styles the scene names, by id.

Source: audio-vue `scene-render`, "A request carries a scene and its display": the viewing in place
of the fonts, the styles a scene names, and no fallback. Decision (maintainer, 2026-11-07): the rate
does not matter to a preview, so one is picked.

#### Scenario: A host with its viewing set

- **WHEN** the host's viewing block holds a distance and a display size
- **THEN** the render request carries that block, and text is drawn at the sizes the host draws it

#### Scenario: A panel whose size is not known

- **WHEN** the host gives no display size
- **THEN** the scene is drawn at 1920 by 1080 pixels, and the canvas says the panel's size is not
  known

#### Scenario: A scene that names no style

- **WHEN** a scene names no style
- **THEN** the request carries no styles, and the scene's unset look is the default style's

### Requirement: Library tiles sit on the scene's backdrop

Each library tile SHALL be shown on the open scene's backdrop as the helper drew it, in place of a
stand-in gradient, once that backdrop is held. For a scene with no cards the library SHALL ask the
helper for the backdrop once per settings, in a request holding one library card and naming no
plate.

Source: maintainer, 2026-11-20: cards and a new scene on the default background, not a brighter
one.

#### Scenario: A new scene

- **WHEN** the user opens a new scene that sets no backdrop
- **THEN** the tiles and the empty canvas show the default backdrop, and dropping a card changes
  neither

### Requirement: Scenes and tiles are drawn ahead

Once paired, with the scenes read and the card code compared, the app SHALL draw every scene's
thumbnail, then each scene's library tiles and backdrop, behind an open scene's own drawing,
whatever page is shown. Tiles SHALL be kept for the scenes drawn last, and thumbnails drawn by
the panel's code between launches, shown as soon as the scenes are read.

Source: maintainer, 2026-11-20: scenes and cards drawn right after launch, so neither lags.

#### Scenario: Opening the Scenes page after launch

- **WHEN** the app has been paired and open on the Panel page long enough to draw
- **THEN** the Scenes page shows every thumbnail at once, and a scene opened shows its library's
  tiles at once

#### Scenario: The next launch

- **WHEN** the app is launched again with the panel's scenes and card code unchanged
- **THEN** the gallery shows each thumbnail as soon as the scenes are read, before the renderer
  is ready, and a scene changed since is drawn again

#### Scenario: Back to a scene

- **WHEN** the user opens one scene, then another, then the first again
- **THEN** the first scene's tiles show at once and none is drawn again

## REMOVED Requirements

### Requirement: A request carries the host's scene and settings

**Reason**: audio-vue's render request no longer takes the install's fonts block or a fallback
backdrop; it takes the viewing block and the styles a scene names.

**Migration**: "A request carries the host's scene, viewing and styles" replaces it.
