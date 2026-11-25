# Proposal

## Why

The console sizes a card by guesswork. A library tile climbs a ladder of sizes, one render per
rung, until the helper stops calling the card too small, and a resize stops at the card's declared
minimum. Neither knows what a card sheds to fit: a meter set to show ticks was drawn and dropped
without them (`editor-conveniences`, design D7, finding F6). audio-vue answered with a `minimum`
request (its change `card-minimum`, deployed 2026-11-24): for each width, the smallest height at
which a card is drawn whole, and the smallest at which it still shows its reading.

## What Changes

- **A card is shown and dropped whole** (maintainer, 2026-11-24). Every library tile, plain or set
  up, is drawn at the card's whole minimum, and a card dragged in lands there: of the whole sizes the
  helper gives, the one with the fewest cells, the narrower on a tie (maintainer, 2026-11-24). This
  replaces the 2026-11-21 ruling that a plain tile shows the smallest size that keeps the reading.
- **A resize stops before Too Small** (maintainer, 2026-11-24). Dragging a handle, on the grid or
  parked, may let a card shed detail but stops at the smallest size that still shows its reading at
  the width reached. A card already below that, because its type changed elsewhere, may grow but not
  shrink further.
- **The minimum follows the settings.** It is asked again when the card's settings or the scene's
  settings change, and held per card and settings, so a drag never waits on the helper. Until an
  answer is held, the declared minimum stands in.
- **The ladder retires.** The helper's answer replaces the console's search for a tile's size, and
  the aspect-locked ladder with it: audio-vue lays an aspect-locked card out in its own shape.

Not doing:
- Showing the edges on the canvas while a card is resized.

## Capabilities

### New Capabilities

- `card-minimum`: the sizes the helper answers for a card, how the console asks, holds and picks
  from them, and where they replace the declared minimum.

### Modified Capabilities

- `scene-rendering`: a library tile is drawn at its card's whole minimum; the ladder requirements
  are removed.
- `scene-layout`: a resize stops at the readable edge for the width reached, not the declared
  minimum.
- `scene-canvas`: a card dragged from the library lands at its whole minimum.
- `library-setup`: a set-up tile and its drop take the whole minimum with the setup.
- `card-parking`: a parked card's resize stops at the readable edge too.

## Impact

- **Code:**
  - `ConsoleCore`: `RenderHelper`/`RenderQueue` gain the `minimum` request; a new `CardMinimum`
    holds answers by card and settings and picks the whole size and the readable floor;
    `LibraryTiles` and `LibraryTiles+Setup` draw each tile once at its whole size, and `Ladder` is
    removed; `SceneContent.resizing` and `CellRect.resizedAcross` take a floor that depends on the
    width; `SceneEditor` asks for the selected card's minimum.
  - App: `SceneEditorView`, `EditorTiles` and the canvas pass the held answers through; the drop
    size comes from them.
- **Bundle:** the console mirrors audio-vue's render bundle, which now carries the `minimum`
  request; nothing else is asked of audio-vue.
- **Referenced specs relied on:** `audio-vue:scene-render` ("The helper answers where a card is
  drawn whole", "The helper answers where a card shows its reading", "A request carries a scene and
  its display"), `audio-vue:card-layout` (a card is drawn whole when it drops nothing; a minimum is
  the same span on every scene).
