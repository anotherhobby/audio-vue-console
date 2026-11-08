# Proposal

## Why

The canvas now draws each scene as the panel would, from audio-vue's own card code (`scene-render`,
archived 2026-11-07), but the card library beside it still shows every card as a tinted box. A user
choosing what to drop sees a colour and a name, not the meter. The helper can already draw one plate
of a scene without its backdrop, so the library can show each card as the drop would place it, with
nothing new from the host.

## What Changes

- **Each library tile is the card as the helper draws it.** The tile shows the card's plate,
  drawn in the open scene's settings, at the card's minimum on that scene's grid, at the panel's
  pixel size, scaled into the tile. It sits over the open scene's own backdrop, the patch the canvas
  drew where the plate lies, so the tile looks as the card does at the scene's top-left corner
  (maintainer, 2026-11-07). Where the canvas has no backdrop, as for a refused scene, the plate sits
  on the library's plain ground. The name and the size label stay.
- **Tiles wait behind the canvas.** Tile requests are sent after the canvas's, so a move or a resize
  never waits behind the library. They come before the gallery's thumbnails, since the library is
  on screen and the gallery is not. Tiles appear as they are drawn.
- **Tiles follow the scene's settings, not its cards.** Scenes whose settings are the same share
  their tiles, and editing the layout draws none again. Opening a scene with other settings draws the
  library for those settings.
- **Tiles fall back as the canvas does.** While the renderer is starting or after it failed, tiles
  are the plain boxes they are today, and so they are when the card code cannot be compared. A card
  whose own code differs from the panel's is a plain box
  with its name. Where shared code differs, every tile is a box. A card that cannot show its reading
  at its minimum is named on its tile. A card too wide for the scene's grid at its minimum, or one the
  helper refuses, stays a box.
- **Read-only scenes show drawn tiles too.** A built-in scene, or one shaped for another panel,
  still shows the cards drawn. Dropping on it is refused as before.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `scene-rendering`: Adds what the library's tiles draw: one card's plate at its minimum in the open
  scene's settings, over that scene's backdrop, when they are drawn again, and how they fall back.
- `render-helper`: Requests are still answered one at a time, but the order now names three kinds:
  the canvas's, then the library's, then the thumbnails'.

## Impact

- **Code:** `ConsoleCore` gains the library's tiles: a one-card request built from the open scene by
  `LaidOutScene`, kept by the scene's settings and dropped with the thumbnails, each stacked over the
  patch of the canvas's backdrop layer under it, so no tile asks the helper for a backdrop.
  `RenderQueue` gains a lane between the canvas and the thumbnails. In the app target, `CardTile` draws the plate in place
  of its tinted box, and `SceneStore` holds the tiles beside the thumbnails.
- **Host and audio-vue:** none. The `plates` and `backdrop` fields are already in the helper's
  protocol, and the bundle is unchanged.
- **Referenced specs:** `audio-vue:scene-render` (a request naming its plates, answered with those
  layers alone and the backdrop only where asked; a refused scene; a plate's unfit cards; plate
  layers over a transparent field), `audio-vue:card-layout` (each card's declared minimum and whether
  it is placeable, exported with the schema, and the too-small check), `audio-vue:scene-grid` (where a
  card at the grid's corner is placed, with a whole gap at the edge), `audio-vue:settings-schema`
  (the declarations exported as one JSON Schema; scene blocks hold no reference to a card).
