# Design

## Context

See proposal.md, "Why". The relevant code today:

- `SceneLayout` holds only a layout the panel would load: every card on the grid, none overlapping,
  groups tiling. `Draft.doc`, `SceneRendering`, `SceneThumbnails` and `LaidOutScene.isTooWide` all
  rely on that.
- `SceneContent` (layout plus the scene's blocks) is the editor's one undoable value, and it is what
  `Draft`, `SceneDrafts` and `SceneRendering` hold. `Draft.isUnsaved` compares it with the content
  read.
- `SceneEditor.move(by:)` serves both drags and arrow keys through `SceneLayout.moving`, which clamps
  the shift to the grid (`clampedOffset`).
- `SceneCanvas` puts its hit targets, outlines, handles and marquee inside the display region, at
  the region's `GridGeometry`. A click on the pane outside clears the selection. `GridGeometry.cell(at:)`
  and `cells(touching:)` clamp to the grid.
- `SceneRendering` keeps each plate's layer by its card ids with the cells it was drawn at, and
  `LayerStack` slides a layer to where its plate is now. `LibraryTiles` draws a card alone at the
  scene's top-left in the scene's settings.
- `SceneSession.canSave`, `canApply` and the editor's toolbar decide what is enabled.
  `SceneWrites.saveAll` saves each unsaved draft in order and throws `Failed` at the first that
  fails.

## Goals / Non-Goals

**Goals:**
- `SceneLayout` keeps its meaning: a layout the panel would load. Parked cards sit beside it.
- Every parking rule (crossing, the jump outside, the reach, returning, nudges) is a pure function
  in `ConsoleCore`, tested by `swift test`.
- No host call, document or stored format changes.

**Non-Goals:**
- Dropping a card from the library onto the pane. Library drops still go onto the grid.
- Resizing a parked card, or grouping parked cards.
- Keeping parked cards across a quit. They are unsaved edits, and a quit asks about them.
- Keeping a card's place in the document's card order across a park and return (see Risks).

## Decisions

**1. Parked cards live in `SceneContent`, beside the layout.** `SceneContent` gains
`parked: [LayoutCard]`, each card's `cells` in the grid's coordinates, wholly off the grid
(negative, or past `grid.cols` or `grid.rows`). The edits that touch it keep three invariants:
parked cards are off the grid, they don't overlap, and a group is wholly parked or wholly on the
grid. Since the editor, drafts, rendering and dirty check already carry `SceneContent`, parked cards
are undone, kept in drafts, discarded by Revert and versions, and mark the scene unsaved with no
new plumbing. `Draft.doc` and everything sent to the host read only `content.layout`.
*Alternative:* off-grid cards inside `SceneLayout` with a flag. Rejected because every reader of a
layout (the document, rendering, thumbnails, too-wide) would have to filter them, and the type's
guarantee would be gone.

**2. A drag is a content edit with a reach.** A new `SceneContent+Parking.swift` holds
`dragging(_ ids:, by:, within reach: CellRect) throws(LayoutRefusal) -> SceneContent`. `reach` is
the pane in cells, relative to the grid's top-left, as the canvas sees it at that moment. The steps:

1. Widen `ids` to whole groups across all cards, layout and parked.
2. Shift the moving cards' enclosing block by `offset`. If it lies wholly on the grid, every
   moving card joins the layout. The new layout is built with the checking
   `SceneLayout(grid:cards:)`, so a taken cell is refused as `.spaceTaken`.
3. Otherwise, clamp the block to stay within `reach`. If that brings it back wholly onto the grid,
   there is no room beyond the edge it crossed, and the move is refused as `.noRoomOffPanel`
   (maintainer, 2026-11-22: refused, not stopped at the edge). `reach` always holds the grid.
4. If the block still touches the grid, it is pushed off it. For each grid edge it crosses, the
   push is the least shift that clears the grid across that edge. The pushes are tried from the
   least to the greatest, rows before columns on a tie, and the first that keeps the block within
   `reach` is taken. If none does, the move is refused as `.noRoomOffPanel`.
5. The pushed block, or a block already wholly off the grid, is parked. A cell shared with a parked
   card that is not moving is refused as `.spaceTaken`.

The canvas's preview calls the same function, so the outline shows exactly where the release lands
(the spec's "outline jumps outside").

**3. Arrow keys never cross the edge.** `SceneEditor.move(by:)` becomes `nudge(by:within:)`,
used only by arrow keys. On-grid cards
still take the offset clamped by `SceneLayout.clampedOffset`. Parked cards in the selection move
by that same offset, and the step is refused as `.dragToCross` where a parked card would touch the
grid or leave the reach, and as `.spaceTaken` where it would land on a parked card that is not
moving, as a nudge on the grid is. The drag gets its own
`SceneEditor.drag(by:within:)` and `previewDrag(by:within:)`, both named Move for undo.

**4. The editor works on all cards.** `SceneContent` gets `cards` (layout then parked) and
`widened(_:)` over both. `SceneEditor`'s `select`, `toggle`, `select(touching:)`, `selectedCards`
and the selection kept after a commit use them, so the inspector shows a parked card like any other.
The settings edits (`set`, `editSetting`, `useDefault`) and `deleteSelection` become content edits
that change cards in both lists. `resizableCard` is nil for a parked card. `groupRefusal` returns
`.parkedCannotGroup` when the selection holds one. Ungroup clears the group in both lists.

**5. Parked cards live in the region's own cells.** Nothing clips the display region, so a plate
or hit target placed at cells off its grid is drawn, and takes clicks, around the outline. The
region's `GridGeometry` already maps such cells linearly. So `LayerStack` draws parked plates from
`rendering.parked`, slid as any plate is, and `SceneCanvas` gives every card, on the grid or parked,
a target in the region. A drag across the edge keeps its plate in view throughout, since the layer
is found by its cards wherever they are shown. One named pane coordinate space serves the rest:
the region's frame read in it (`onGeometryChange`) gives `PaneFrame.reach`, and the marquee is read
in it over the region and over the open pane behind the column, then kept in region points and
selected through an unclamped `cellsOnAndOff(touching:)`. The title and footer draw above a parked
card (`zIndex`). *Alternative:* a pane-wide `ParkingLayer` overlay with a second geometry, as first
planned. Rejected while building: it doubled the geometry, and a plate dragged across the edge
would have had to hand over between two layers.

**6. The panel shrinks only to keep parked cards in view.** A pure
`GridGeometry.fittingScale(of:in:)` returns 1 or more when the parked cards' enclosing block,
at the panel's usual pitch and centred, lies within the pane. Otherwise it returns the largest
scale below 1 that brings it in. A small `Layout`, `CanvasStack`, stacks the title, the panel and
the footer as the `VStack` did, but offers the panel that scale of the room left to it, so the
panel stays centred and is no smaller than it must be. The scale is computed from the committed content,
never during a gesture, so the panel does not move under the pointer.

**7. Parked plates keep their layer, and are drawn alone only when they must be.**
`SceneRendering` gains `parked: [Set<UUID>: PlacedLayer]`.

- On each `show(content)`, a plate whose cards are now all parked moves from `plates` to `parked`,
  keeping its layer and the cells it was drawn at, and `ParkingLayer` slides it as `LayerStack`
  does.
- A parked plate whose cards return moves back to `plates`, and the existing "draw again what
  changed" rule redraws it in its new cells.
- A parked plate that has no layer, or whose settings or the scene's non-backdrop blocks changed,
  gets one request: the scene's doc with those cards alone, shifted to the grid's top-left as
  `LibraryTiles` draws a tile, asking for that plate and no backdrop, on the canvas lane. Its
  answer is stored at the parked cells. This request has its own path, because the scene's `take`
  keeps only layers whose cards are in the current layout, and `draw` clears everything for an
  empty or too-wide layout.
- Where the renderer cannot draw, `ParkingLayer` draws a `PlainBox`, as `LayerStack` does.

The scene request itself never carries parked cards, because it reads `content.layout`.

**8. Gating reads one fact, in `ConsoleCore`.** `Draft.parkedCount` (and `hasParked`) feeds:

- `SceneSession.canSave` and `canApply`, and `save()` refuses while parked, so ⌘S cannot get past
  it.
- A new `SceneSession.canDuplicate`.
- The gallery's note and its disabled Duplicate.

`SceneWrites.saveAll` checks every unsaved draft first and, where any has parked cards, throws
before writing anything. Its error becomes an enum, `failed(id:name:failure:)` and
`parked(names:)`, and `UnsavedScenes` shows `parked` in the same alert, naming the scenes.

**9. One line on the canvas.** The footer's message order becomes: a refusal, read-only, parked
("2 cards are off the panel. Move them onto it to save, apply or duplicate this scene."), then too
wide. The toolbar's help for Save, Apply and Duplicate gives the same reason. The new
`LayoutRefusal` cases carry their sentences: `.noRoomOffPanel` ("There's no room for that off the
panel."), `.dragToCross` ("Drag a card to move it onto or off the panel.") and `.parkedCannotGroup`
("Move these cards onto the panel to group them.").

## Risks / Trade-offs

- [A returned card goes to the end of the document's card list, so a park and a return to the same
  cells still leave the scene marked unsaved] → Undo restores the order exactly. The card order has
  no effect on drawing, since plates never overlap.
- [A plate drawn alone at the top-left has a whole gap on its top and left edges where it had half a
  gap beside a neighbour, so a parked plate redrawn alone can differ by half a gap from how it looks
  on the grid] → It is redrawn in place once it returns. Only plates that must be redrawn while
  parked are affected.
- [The pane may have no room off the panel when the window is small or the panel fills it] → The
  move is refused with a reason. Hiding the sidebar or the inspector, or enlarging the window, makes
  room.
- [Parked cards can sit under the title or footer text] → The text stays drawn above them. It is
  short, and the parked card can be moved.
- [SwiftUI hit testing across two layers (region and pane overlay)] → A parked card's targets are
  only in the overlay, and an on-grid card's are only in the region, so no card has two targets.
