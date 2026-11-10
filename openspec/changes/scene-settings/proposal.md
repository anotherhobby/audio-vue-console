# Proposal

## Why

`card-settings` lets the editor set a card's own settings, but a scene's look and behaviour live in
its own blocks: the backdrop behind the plates, the palette every card draws with and the elements
pointed at it, the plates' glass,
the size of each kind of text, the analysis the cards read, when the display sleeps, and the grid.
The product promises every scene setting through the app (`product.md`, "The decision"). All of
them are declared in the host's schema (`$defs/block.*`), and the routes to store a scene, upload an
image and read the calibrated rates already exist. audio-vue's `card-colours` makes every card colour
resolvable by lookup, so the inspector can show the colour an unset card colour is drawn in, rather
than a black swatch.

## What Changes

- **The inspector shows the scene's settings when no card is selected** (maintainer, 2026-11-08),
  below the scene's name and kind, in tabs (maintainer, 2026-11-09): Look (Backdrop, Glass, Type),
  Colours (Palette, Elements), Analysis (Analysis, Display) and Grid, then Other for any block the
  schema declares that the app does not know, by its name, since a block declares no label. Rows
  are compact, card settings' too: help on hover, Use Default as a small button.
  Within a block, settings come in the order audio-vue declares them (`x-settings`, asked for by
  `card-settings`'s handoff, which this change extends to blocks). Each setting is generated from the
  schema with the controls, defaults, Use Default, undo, standard flags and read-only rules
  `card-settings` defines.
- **The backdrop is one source**: a colour, a gradient or an image, chosen by a segmented control,
  since the host refuses a backdrop with none or more than one (audio-vue `scene-backdrop`). A
  gradient edits its stops (add, remove, reorder, each through the system colour panel) and its
  angle. An image is picked from the host's images or uploaded from a file (PNG or JPEG). Blur
  applies to any source. Use Default removes the backdrop, so the scene uses the palette's
  background.
- **The palette's swatches**, every one the schema declares, grouped by family, are edited through
  the system colour panel, each with Use Default.
- **The scene's elements**, the things cards draw (titles, grid lines, bars, status colours), each
  point at a swatch, chosen from the palette with each swatch shown in this scene's colour, grouped
  by family.
- **A card's unset colour shows what it is drawn in** (maintainer, 2026-11-09): the element it
  overrides, the swatch the scene points that element at, and its colour, following the palette and
  elements as edited. Cards selected together share a colour setting only where it overrides the
  same element.
- **A card setting with no effect is greyed out, saying why** (maintainer, 2026-11-09): the meter's
  bar colours on a field coloured by its thresholds. audio-vue declares when, so the console
  copies no list.
- **Analysis settings carry their class.** A measurement setting off its standard is flagged.
- **The scene says when no calibration holds at its rate** (maintainer, 2026-11-08). A scene may
  capture at any rate the host is calibrated at, as audio-vue applies the newest valid record for
  the device and rate in use. The Analysis section warns only where none holds at the scene's rate,
  its capture rate or the installed one, from the host's calibrated rates (`GET /v1/calibration`).
- **The grid's gap and density** (maintainer, 2026-11-08). Gap is a setting like any other. Density
  changes columns and rows together at the scene's own aspect, chosen from a list of whole-number
  grids, and moves every card to the matching cells, as one undoable step. It is refused, saying
  which card, where a card would fall below its minimum.
- **Every redraw follows.** A backdrop change draws the backdrop again; any other scene setting draws
  every plate, the library's tiles and the scene's thumbnail again.
- **Scene settings are scene edits**: kept in the open scene, marked unsaved, undone and redone in
  the same history as layout edits, and stored by Save or Apply, as `card-settings` does for cards.

Out of scope: styles (the `styles` change, which will let a scene take its palette, typeface, type
roles, backdrop and glass from a style it names), the install's font sizes, and a grid of another
aspect.

## Capabilities

### New Capabilities

- `scene-settings`: the inspector's view of the open scene's own settings: its blocks generated
  from the host's schema, the backdrop's one source with its gradient and image, and the grid's
  density.

### Modified Capabilities

- `scene-canvas`: "Edits are kept until saved or discarded" keeps the scene settings the user
  changed, as well as the cards' settings.
- `card-settings`: "A setting shows the scene's value or the card's default" shows an unset colour
  as the scene resolves it; "Use Default removes a setting from the scene" says so for a colour;
  "Selected cards are edited together where they share a setting" also matches the element; and
  "A setting with no effect says why" is added.
- `scene-rendering`: "An edit draws again only what it changed" draws the backdrop again on a
  backdrop change and every plate on any other scene setting change; "Library tiles follow the
  scene's settings, not its cards" follows the open scene's settings as edited, not as read.

## Impact

- **Code:** The editor's undoable state grows from a `SceneLayout` to the layout plus the scene's
  blocks, so one history holds both; `Draft`, `SceneDrafts`, `SceneEditor` and the renderer build
  the document from it. `ConsoleCore` reads each `block.*` declaration with `card-settings`'s
  reader, reads the swatches and elements and resolves an element's colour in a scene, works out
  grid densities and the cells each card moves to, and lists and uploads images
  (`HostClient`, `/v1/images`). In the app target, `SceneSettingsPanel` grows the block sections, a
  backdrop editor and a gradient stop list; library tiles and thumbnails draw from the edited
  document.
- **Sequencing:** builds on `card-settings`, built and archived: the declaration reader, the
  controls, Use Default and the colour panel are its.
- **Host:** one ask, `meter-colours-handoff.md`, answered by `x-unused-when` (audio-vue
  `unused-settings`): when a card setting has no effect, so the inspector greys it out with the
  reason. The calibrated rates (`GET /v1/calibration`) answered
  `scene-settings-handoff.md`, and audio-vue's `card-colours` answered how an unset colour
  resolves. Referenced specs relied on: `audio-vue:card-colours` (concrete swatches in families,
  elements, resolution by lookup, status elements scene-wide), `audio-vue:settings-schema` (every block declared,
  classes, standards, one validation, a colour setting naming the element it overrides, a
  setting saying when it has no effect), `audio-vue:settings-store` (a scene written whole on its
  revision; images uploaded, named by id, and not deleted while a stored scene names them; a write
  leaves the screen), `audio-vue:scene-backdrop` (one source; a gradient of two or more stops at a
  CSS angle; no backdrop is the palette's background), `audio-vue:scene-grid` (a scene declares its
  grid; placements stay on it; the gap), `audio-vue:type-scale` (the scene chooses each kind's size
  within its range), `audio-vue:card-layout` (each card's minimum on a 36-row grid) and
  `audio-vue:scene-render` (a request carries the scene as the store holds it).
