# Proposal

## Why

audio-vue's `host-grid` (hand-off of 2026-11-21) takes the layout grid
away from the scene. The panel's display decides it: 36 rows, and as many columns as fit the
display's shape, filling the display. A scene's `grid:` holds only `gap`, and a scene that sets
`cols` or `rows` is refused. The app still treats a grid as the scene's: it writes one, offers its
density, sorts scenes by shape, and scales each card's minimum to it.

## What Changes

- **The grid the app lays a scene out on is the panel's**, read from the state's display section.
  Every scene opened, drawn or made for a panel is on that grid. The app writes no `cols` or `rows`.
- **The grid's density is gone.** The Grid section offers the gap alone. `GridDensity` and the
  density requirements of `scene-settings` go. **BREAKING** (to that change, which is not archived)
- **A scene has a reach, not a shape.** The gallery's "Other Shapes" goes: every scene is listed
  under My Scenes or Built-in Scenes. A scene that places a card past the panel's last column says
  it is too wide for this panel.
- **A scene too wide for the panel** opens on a canvas as wide as its reach, the columns the panel
  lacks marked, so its cards can be moved in. It is drawn as boxes, the helper asked for nothing.
  Save is allowed, since the host takes a scene however wide. Apply is disabled, saying why.
- **Apply shows the panel's refusal.** A switch the panel refuses says why, as the panel words it,
  and says the scene on the panel stayed. The scenario of a scene fitted with backdrop either side
  goes.
- **A card's minimum is its declared span on every scene.** Nothing is scaled by a grid's rows:
  the canvas, the library tiles and the resize limits read `x-min-cells` as it stands.
- **An unset span covers the whole grid** (the built-in `default` is one such card). The app reads
  an unset `colspan` as the panel's columns and an unset `rowspan` as 36, and keeps it unset until
  the card is resized.
- **New Scene is an empty scene on the panel's grid.** It no longer builds a grid from the
  display's size and a standard density.
- **With no display yet**, the state's grid is null; the Scenes page says the panel has no display
  to lay scenes out for, and offers no editing.

Not doing: card minimums that follow the host's text size, which is audio-vue's next change and the
rest of `card-minimums-handoff.md`; portrait displays, which audio-vue does not design for.

## Ruled

The maintainer agreed to all four on 2026-11-21:

1. **A scene too wide for this panel** can be opened and edited on its own reach, and saved, but
   not applied.
2. **An unset span** is kept unset until its card is resized, so a copy of `default` still fills
   any panel.
3. **With no display yet** there is no editing.
4. **`scene-settings`** drops its two density requirements and its density tasks; the code built
   for them stays until this change removes it. Its run on the proving host waits for this change,
   and one run proves both.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `scene-layout`: a scene is laid out on the panel's grid, or on its own reach where it is too wide;
  an unset span covers the grid.
- `scene-canvas`: the canvas is the panel's grid filling the display's shape; a scene too wide
  shows the columns the panel lacks; minimums are unscaled.
- `scene-gallery`: scenes are listed without regard to shape; a scene too wide says so; New Scene
  is on the panel's grid.
- `scene-apply`: Apply is disabled for a scene too wide, and a refused switch says why.
- `scene-rendering`: library tiles are drawn at the card's declared minimum on the panel's grid;
  a scene too wide is drawn as boxes.
- `scene-saving`: a saved scene carries no `cols` or `rows`, and keeps an unset span; a scene too
  wide is saved, renamed and deleted like any other.

The open change `scene-settings` is edited, not a standing spec: its density requirements go and
its New Scene requirement loses the grid's shape (ruling 4, done 2026-11-21).

## Impact

- **Code:** `PanelState` gains the display's grid. `GridDensity` and `DisplayShape` go, with
  `GallerySections`' shape sorting, `SchemaFacts.scaled` and `minimums(forRows:)`, the schema's
  default grid, and the grid write in `LaidOutScene.doc(for:)`. `LaidOutScene` takes the panel's
  grid and resolves unset spans on it. `SceneDrafts.new` takes the panel's grid. `LibraryTiles.Key`
  drops the grid. `SceneRendering` and `SceneThumbnails` ask nothing for a scene too wide. In the app
  target: the Grid section's density stepper, the gallery's sections, the canvas's marked columns,
  and Apply's refusal.
- **Sequencing:** built once audio-vue's `host-grid` had landed and its closing note was read, the
  contract, the schema fixtures and the render bundle refreshed first.
- **Host:** nothing to ask. `host-grid-handoff.md` (2026-11-21) states the surface as designed.
  Referenced specs relied on, as that change words them: `audio-vue:scene-grid` (the grid is the
  host's, it fills the display, `grid:` holds only `gap`, a scene too wide is refused, a switch to
  one is refused), `audio-vue:control-state` (the state says the display's grid),
  `audio-vue:card-layout` (a minimum is the same span on every scene), `audio-vue:settings-store`
  (the default scene is one RTA across the grid) and `audio-vue:scene-render` (a refused drawing).
- **KB:** the agent notes on shapes, densities and scaled minimums, and `product.md`'s "scenes are
  tied to a display shape".
