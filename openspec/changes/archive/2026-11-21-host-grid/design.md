# Design

## Context

See `proposal.md` for why. Planned on 2026-11-21 from audio-vue's `host-grid` as designed, before it
is built, at the maintainer's ruling. The app as it stands (`dev` after `e47c193`, with
`scene-settings` built and not archived) gives every scene a grid of its own:

- `LaidOutScene.init(_:defaultGrid:)` reads `grid.cols` and `grid.rows`, else the schema's defaults
  (`SchemaFacts.defaultGrid`, without which `SchemaFacts.init?(schema:)` gives nil), and fills an
  unset span from that grid. `doc(for:)` writes every card's `col`, `row`, `colspan` and `rowspan`,
  and the grid's `cols` and `rows` where they changed.
- `GallerySections` sorts by `DisplayShape`, the panel's against each scene's grid. A scene of
  another shape is read-only (`SceneEditorView`), cannot be duplicated, and is not saved.
- `SceneEditor.minimums`, `LibraryTiles` and the library scale each card's minimum by the grid's
  rows (`SchemaFacts.scaled`, `minimums(forRows:)`, `referenceRows`).
- `GridDensity` gives the density choices, re-lays a scene, and makes New Scene's grid from the
  display's size.
- `LayerStack` and `SceneCanvas` fit the scene at `cols ÷ rows` inside the panel's aspect.
- `PanelState` holds the display's width and height in pixels, and no grid.
- Fixed scenes are left out of the gallery (`PanelScenes`), so the app lays none out.

## Goals / Non-Goals

**Goals**

- One source for the grid: the panel's state.
- A scene too wide for the panel stays reachable and fixable from that panel.
- A document the app writes is one the host takes: no `cols`, no `rows`, unset spans kept.
- Less code: `GridDensity`, `DisplayShape` and the scaling of minimums go.

**Non-Goals**

- Minimums that follow the host's text size (audio-vue's next change).
- Portrait displays.
- Working out the host's grid in the app from the display's size. The state gives it.

## Decisions

### D1. The panel's grid comes from the state

`PanelState` gains `grid: CellSize?` from the display section's `grid`. The window passes it to
`SceneStore.follow(grid:)`, and the Scenes page, the gallery, the editor and drawing ahead read
`SceneStore.grid` where they read `facts.defaultGrid` before. `SchemaFacts.defaultGrid` goes, and
`SchemaFacts.init?(schema:)` no longer needs the grid block's `cols` and `rows`, which the schema
stops declaring; it fails only where `$defs` is missing.

Alternative: the rule in the render bundle (`layout.host_grid`). Rejected: it needs the helper
running before a scene can be laid out, and the state is already live in the app.

With no grid in the state, `ScenesPage` shows an unavailable view in place of the gallery
(ruling 3). Where the grid changes, as when the panel's display does, `SceneDrafts.relay(on:)` lays
every draft out again: an edited draft keeps its blocks and the cards it moved, a card left as read
takes its cells on the new grid, and what was drawn on the old grid is dropped. An open editor
holds a layout on the old grid, so the page closes it.

### D2. A layout's grid is the panel's, widened to the scene's reach

`LaidOutScene.init(_:panel:ids:)` takes the panel's grid. It resolves each card's cells first (an
unset `colspan` is the panel's columns, an unset `rowspan` its rows), then lays out on
`CellSize(cols: max(panel.cols, reach), rows: panel.rows)`, where `reach` is the furthest column any
card ends at. `LaidOutScene` keeps `panel`.

`SceneLayout` gains nothing: its grid is whatever it was built on, and its bounds checks hold on the
widened grid as they do now. Whether a scene is too wide is a question asked of content against the
panel: `SceneContent.isTooWide(for panel:)`, true while any card ends past `panel.cols`. It follows
edits, so Apply enables as soon as the cards are in. The canvas keeps the width it opened with until
the scene is opened again, which the spec says; a scene read again after a save keeps the open
layout's columns (`LaidOutScene.init`'s `keeping:`), so the editor still pairs with it.

Alternative: narrow the grid as cards move in. Rejected: `SceneLayout.grid` is fixed per layout and
every edit, undo step and geometry value hangs off it; a grid that changes under a drag is a new
class of bug for a case that ends at the next open.

A card past the 36th row is refused at load by the host, so the app meets none; `SceneLayout`'s
`.offGrid` still covers a document that has one.

### D3. Unset spans are written back unset

`entry(for:)` writes `colspan` only where the card's entry held one, or the card no longer starts at
column 0 spanning `panel.cols`; `rowspan` likewise by rows. `col` and `row` are written as now: an
unset one is 0, and writing 0 changes nothing the host reads. A new card's entry holds no spans, so
a card dropped at exactly the whole grid is written unset too, which means the same thing.

`doc(for:)` loses the grid write. `SceneDrafts.new(on:among:)` writes no `grid` block and takes the
panel's grid only to lay the empty scene out.

### D4. What goes

- `GridDensity` (`choices`, `relaid`, `grid(width:height:standard:)`) and its tests;
  `LayoutRefusal.tooSmall` if nothing else throws it; the Grid section's density stepper, leaving
  the block's generated rows (the gap).
- `DisplayShape` and its tests; `GallerySections.otherShapes` and the `GalleryEntry.grid` it sorts
  by; "Duplicate for This Panel" and `ReadOnlyReason.shape`.
- `SchemaFacts.scaled`, `minimums(forRows:)` and `referenceRows`: callers read `card.minimum`.
  `LibraryTiles.Key.grid` goes, since every scene of a panel shares the grid; `forget()` already
  clears the tiles when the panel changes.

### D5. The canvas is the display's shape

`LayerStack` and `SceneCanvas` take the display's pixel size with the grid. The region's aspect is
`(width ÷ height) × (layout.grid.cols ÷ panel.cols)`: the display's own for a scene that fits, wider
by the same cells for one that does not. `GridGeometry` already divides a size by the grid, so
stretched cells need no change there. The helper's layers are in display pixels and fill the region
as now.

The columns past `panel.cols` are shaded by the canvas's own grid drawing, with one line of text over
the canvas, as the read-only reason is shown today.

### D6. A scene too wide asks the helper for nothing

`SceneRendering.draw` and `SceneThumbnails.draw` return as they do for a scene with no cards when
`isTooWide`, so the canvas and the thumbnail show `LayoutPlates`' boxes. The helper would refuse it
anyway (`{"ok": false, "refused": …}`), and the app's existing path for a failed drawing covers a
refusal it did not foresee, such as groups that do not tile on this panel. Library tiles are still
drawn: they hold one card at its minimum, which fits.

### D7. Apply and the gallery

`SceneSession.canApply` is new: the scene holds a card and is not too wide. The Apply button's help says why, beside the existing
"add a card" reason. A switch the panel still refuses goes through `scene-apply`'s "A refused Apply
says why" unchanged.

`GallerySections` keeps `mine` and `builtIn`. A gallery row shows "Too wide for this panel" under
the scene's name from `isTooWide`. Duplicate is offered on every row.

## Risks / Trade-offs

- [audio-vue builds something other than its design] → nothing is built here until its closing note
  is read; task 1.1 re-reads this design against it.
- [A panel changes display, so its grid changes under open drafts] → drafts are laid out again from
  their documents on the new grid; a draft that no longer fits is too wide and says so.
- [An unset span on a card the user then moves] → it stops spanning from column 0, so the span is
  written, which is what the card now is.
- [Near-square cells make fixed-shape cards look slightly off in boxes] → boxes are a stand-in; the
  helper's drawing fits such a card inside its slot.
