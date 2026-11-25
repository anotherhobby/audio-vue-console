# Proposal

## Why

The scene editor makes the user repeat work they should not have to. A card set up just so is built
again by hand for each copy, in this scene or the next. A scene is put on the panel only from inside
its editor. A card's settings are seen only after it is dropped on the scene. The pane around the
panel, where cards are parked, has no cells to line them up by. The maintainer asked for four
conveniences together (2026-11-24).

## What Changes

- **Copy, cut and paste cards** (maintainer, 2026-11-24). ⌘C on the canvas copies the selected
  cards, whole groups included, with every setting they hold. ⌘X copies the selection and removes it
  from the scene, as one step named Cut. ⌘V pastes them into the open scene, or into another scene of
  the same panel:
  - as one block keeping its arrangement and groups, each pasted group a new group;
  - on the panel, in the same cells where they are free, else the free cells nearest them;
  - where the panel has no room, parked off the panel, above it first, then below, left and right;
  - where there is no room anywhere, nothing is pasted and the canvas says there is no room to paste
    the copied cards.
  A paste is one step, named Paste, and selects what it pasted.
- **Apply from the gallery** (maintainer, 2026-11-24). Each scene in the gallery has an Apply button
  beside its name. It does what the editor's Apply does: saves a scene with unsaved edits, then puts
  it on the panel, and says what that cost. It is disabled, saying why, where the editor's would be.
- **Set up a library card before placing it** (maintainer, 2026-11-24). Clicking a library tile,
  rather than dragging it, selects it, and the inspector shows that card's settings. A change redraws
  the tile with it, and every copy of that card dropped afterwards takes those settings. They last
  until the scene's editor is left, and touch no scene until a card is dropped.
- **A grid around the panel** (maintainer, 2026-11-24). While a scene is edited, the pane outside the
  panel is drawn as a light grid, its cells the panel's cells and lined up with them, so parked cards
  sit on it. A Grid button in the editor's toolbar, just before the Inspector button, picks the grid's
  colour, kept for every scene and across launches.

- **Drop library cards off the panel** (maintainer, 2026-11-24, added during the build). A card
  dragged from the library and dropped on the grid around the panel is parked there, as a card
  dragged off the panel is. A drop over the panel lands on it as before.

- **A parked card is as editable as one on the panel** (maintainer, 2026-11-24, added during the
  build). A parked card resizes by its handles within the pane, never onto the panel; parked cards
  alone can be grouped; a parked card too small to show its reading is named; and a resized parked
  card is drawn again at its size.

Not doing:
- Duplicate (⌘D) on the canvas.
- Grouping cards across the panel's edge: a group is wholly on the panel or wholly off it.
- Copying cards between panels: a card the open panel's schema does not place is refused on paste.
- Keeping a library card's setup after its scene's editor is left, or sharing it between scenes.
- Lines on the panel itself; the grid is drawn only around it.

## Capabilities

### New Capabilities

- `card-clipboard`: copying or cutting cards from a scene and pasting them into any scene of the
  panel: what a copy holds, what a cut removes, where a paste lands, on or off the panel, and when there is no room.
- `library-setup`: selecting a library card to see and change its settings before it is placed, the
  tile drawn with them, the cards dropped with them, and how long they last.

### Modified Capabilities

- `card-parking`: a library card dropped on the pane outside the panel is parked there; a parked
  card resizes within the pane, and parked cards alone can be grouped.
- `scene-rendering`: a resized parked card is drawn again at its size, and a parked card too small
  to show its reading is named.

- `scene-apply`: Apply is offered in the gallery as well as the editor, with the same save, report
  and refusals.
- `scene-gallery`: each scene's row carries an Apply button beside its name, and the gallery shows
  the last Apply's outcome.
- `scene-canvas`: the pane around the panel is a grid of the panel's cells, in a colour the user
  picks with a Grid button in the editor's toolbar.

## Impact

- **Code:**
  - `ConsoleCore`: a card clipboard (what is copied, serialised, and where a paste lands on or off the
    panel) beside `SceneContent+Parking`; `SceneEditor` gains `paste` and a drop that carries settings;
    a library setup model holding settings by card kind; `LibraryTiles` draws a tile in a card's
    setup; `LayoutCard` carries the parts of a pasted card's entry the layout does not model.
  - App: `SceneCanvas` takes ⌘C and ⌘V and draws the grid around the panel; `CardLibrary` selects a
    tile on click; `SceneInspector` shows a selected tile's settings through `CardSettingsList`, which
    writes to the scene or to the setup; `SceneGallery` gains the Apply button and its outcome
    banner; the editor's toolbar gains the Grid button.
- **Host:** nothing new. A gallery Apply uses the same scene write and switch the editor's does.
- **Referenced specs relied on:** `audio-vue:control-commands` (the switch and what it reports),
  `audio-vue:settings-schema` (card settings, placeable cards), `audio-vue:scene-grid` (a scene too
  wide is refused), `audio-vue:scene-render` (a request may name its plates, as a tile's does).
