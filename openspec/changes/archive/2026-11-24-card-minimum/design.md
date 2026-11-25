# Design

## Context

See proposal.md for why. The code as it stands:

- **Requests.** `RenderRequest.message` builds a `render` from `RenderContext.fields(for:builtIn:)`
  (scene, built-in, display, viewing, images, the styles the scene names). `RenderQueue.submit(_:lane:key:)`
  sends one message at a time and answers a `HelperAnswer` (`header`, `payload`); in the canvas and
  library lanes a newer request replaces a waiting one with the same key.
- **Tiles.** `LibraryTiles.drawTile` searches `Ladder` (declared minimum grown by whole cells,
  aspect-locked cards in their aspect) with a binary search of renders until `unfit` is empty, and
  keeps the size found per scene-settings `Key`. `LibraryTiles+Setup.fitted` runs the same search
  with a setup. `TileLadderTests` tests the ladder; `LibraryTilesTests` counts its renders
  (`rendersPerDraw`).
- **The request a tile draws.** `LibraryTiles.request(for:card:context:)` lays the card alone at the
  grid's top-left in the draft's scene as edited: the scene's blocks with one card, its entry kept
  where it has one.
- **Resizing.** `SceneLayout.resizing` and `SceneContent.resizingParked` call
  `CellRect.resizedAcross` twice, columns then rows, each with a scalar `atLeast` from the card's
  declared minimum (`SceneEditor.minimum(of:)`, from `SchemaFacts.minimums`).
- **Dropping.** The canvas's drop size is `EditorTiles.dropSize`: a set-up tile's size, else the
  declared minimum.
- **audio-vue's answer.** `minimum` takes the `render` fields and `placement`, and answers `whole`
  and `readable`, each `[[cols, rows]]` rising in columns, a width with no height left out. It is
  laid out from a stand-in placement, so the card's cells and neighbours do not affect it; the
  scene's type, case, face and styles do. Up to 1.4 s for the VU meter on 1,920 × 720 (measured in
  audio-vue). `readable` is a floor at every width; the console does not rely on `whole`
  being monotone.

## Goals / Non-Goals

**Goals:**
- A drag, a drop or a tile never waits on the helper.
- One `minimum` and one `render` per tile per settings, in place of a ladder of renders.
- The resize rule stays in ConsoleCore, tested without a helper.

**Non-Goals:**
- Asking for the minimum of every card on the scene up front. Only the card a resize can reach, and
  the library's cards, are asked about.

## Decisions

### D1. `CardMinimum`: an answer and the two things read from it

A value type in ConsoleCore, decoded from a `minimum` answer: `whole` and `readable` as
`[Int: Int]` (columns to rows). It answers:
- `wholeSize`: the whole entry with the fewest cells, the narrower on a tie; else the readable entry
  by the same rule; else nil, the caller using the declared minimum.
- `floor`: a `MinimumFloor`, the readable map, which the resize reads (D4).

A refusal, a failure, or an answer that does not decode is no answer: the declared minimum stands
in, as before an answer is held.

### D2. `CardMinimums` asks and holds, by card settings and scene settings

An `@Observable` `@MainActor` class in ConsoleCore, held by `LibraryTiles` as `minimums` and
reached by the canvas through it, holding answers by a key of the scene-settings `Key` (as tiles
use) and the card's entry without its cells and group (`LaidOutScene` entry form). `answer(for:)`
reads a held answer and never asks; `ask(for:in:from:lane:key:)` asks when none is held, in a lane
and under a key given by the caller: the library lane keyed `minimum:<kind>` for tiles, the canvas
lane keyed `minimum:selected` for the selected card, so a newer selection replaces a waiting one.
An ask for a card already being asked about waits for that answer, and asks itself only where it
comes back empty, so a tile and a selected card alike asked about at once both get it. The request
is the tile's scene (`LibraryTiles.request`'s doc), `op: "minimum"`, `placement: 0`. Held answers
follow `LibraryTiles.kept`'s eviction, by scene settings, in `CardMinimums`' own list, and
`LibraryTiles.forget` forgets them with the tiles.

Alternative: owned by `SceneStore` beside `LibraryTiles`. The tiles ask for every minimum they draw
at, and both forget together when another panel is shown; the eviction policies stay apart because
`CardMinimums` keeps its own list.

### D3. A tile is one `minimum` and one `render`

`LibraryTiles.drawTile` asks for the card's minimum (through `CardMinimums`, so the canvas and the
library share an answer), then draws the plate once at `wholeSize`, or the declared minimum where
there is none. `drawSetup` does the same with the setup on the card. `Ladder`, `smallestFitting`
and `TileLadderTests` are removed; the tile's `size` is what it was drawn at, as now. The set-up
tile's wanted-settings guard (`editor-conveniences` D7) stays, so a late answer for an older setup
is dropped.

### D4. The resize floor is a function of the width

`CellRect.resizedAcross` keeps its scalar `atLeast` for the axis it moves; the two-axis resize gains
a `MinimumFloor` (a closure from columns to the least rows, or nil for "this width is not
reached"):
1. Columns: the requested width is clamped by the walls as now, then, where it is narrower than
   the card was and the floor at that width is nil or above the height the card will have, widened
   back one column at a time, stopping at the old width. Widening is never held back: a card below
   its floor may grow towards it.
2. Rows: clamped by the walls, then to at least the floor at the width reached, or the old height
   where that is already below it.

The height step 1 measures against is the larger of the height step 2 is asked for, before the
floor, and the card's own: a corner dragged in may stop at the floor, but a width needing more rows
than the card had and was not dragged to is not taken. No
edge grows that the user did not pull. `SceneEditor` builds the floor from `CardMinimums` where an
answer is held for the card, else from the declared minimum as a constant floor that admits every
width from its columns.

### D5. The selected card's minimum is asked for when its handles show

When `resizableCard` changes, or its settings or the scene's settings change while it is
selected, `SceneEditorView` asks `CardMinimums` for it in the canvas lane. Cards not selected are
not asked about: no handle can reach them.

### D6. A drop takes the tile's size

`EditorTiles.dropSize` returns the tile's drawn size, plain or set up, where its minimum answer is
held, else the declared minimum. The tile's size and the drop's are the same `wholeSize`, so the
caption names what the drop takes.

## Risks / Trade-offs

- [A VU-meter answer takes 1.4 s] → the tile shows its box, and a resize uses the declared minimum,
  until it arrives; nothing waits.
- [Changing the typeface asks again for every tile and the selected card] → one `minimum` per tile,
  replacing about six renders per tile today; held answers come back with the settings.
- [Thinned labels count differently per card] (audio-vue's open question) → the console takes
  `whole` as audio-vue answers it.
