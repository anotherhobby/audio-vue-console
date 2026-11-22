# Code alignment

## Read

- 2026-11-21: `ConsoleCore/Sources/ConsoleCore/LibraryTiles.swift`, whole file: `Tile` (`unfit` from `layer.unfit`),
  `Key` (settings without cards and name), `Source`, `TileSet.claim` (the `asked` and `ahead` sets), `draw`,
  `prepare`, `fill`, `send` (queue keys `tile:<card>` and the lane per pace), `any`, `request(for:as:card:minimum:context:)`
  at line 246. Checked: the tile is requested at `minimum` as the design's Context says.
- 2026-11-21: `RenderQueue.swift` line 8-11 (`Lane`: canvas, library, thumbnails) and line 37 (`submit(_:lane:key:)`).
  Checked: the design's lanes and keys exist.
- 2026-11-21: `AudioVueConsole/Scenes/CardLibrary.swift`, lines 10-40 (`sizeOf`, the tile's `size`), 75-100 (the
  caption at line 93 and "Too small to show its reading" at line 98), 127 (`minimum = size ?? card.minimum`).
- 2026-11-21: `ConsoleCore/Sources/ConsoleCore/SchemaFacts.swift` line 118-130: reads `x-min-cells` and `x-placeable`
  only. Checked by grep: no reading of `x-sizing` or `x-aspect` anywhere in `ConsoleCore/Sources` (F4).
- 2026-11-21: `ConsoleCore/Sources/ConsoleCore/LaidOutScene.swift` lines 9-39: the grid is the panel's, or wider when
  a card reaches past it. The panel's rows are 36 in the schema fixture (`schema-trimmed.json`, `"rows": {"default": 36}`).
- 2026-11-21: `ConsoleCore/Tests/ConsoleCoreTests/LibraryTilesTests.swift` exists; tests go there (tasks 2.x, 3.x).
- 2026-11-21: `ConsoleCore/Sources/ConsoleCore/RenderedLayer.swift` line 6-16: `rect`, `cardIDs`, `kind`.
- 2026-11-21: `../audio-vue/src/cards/base.py` lines 52-64 (`Sizing`: `FREE`, `ASPECT`; ASPECT is "fitted and
  centred inside whatever it is given") and line 311 (`aspect`, required with ASPECT).
- 2026-11-21: `../audio-vue/src/schema/export.py` lines 120-130 (`_placing`: `x-min-cells`, `x-sizing`, `x-placeable`,
  `x-aspect`).
- 2026-11-21: audio-vue `openspec/specs/scene-render/spec.md`, "A request may name its plates" (line 133) and "The
  answer says what does not fit" (line 242): read in full. The answer holds the named plates alone, and names each
  card that cannot show its reading at its size by the panel's own fit check.
- 2026-11-21: audio-vue `openspec/specs/card-layout/spec.md`, "A card's reading fits at its minimum" and "No text
  overlaps or leaves the card": read. The standing wording says a card at its minimum shows its reading; the open change
  `card-minimum-at-type-floor` (not archived) replaces it with the floor at the declared minimum sizes, and its delta
  says a larger type than that shows the notice and the scene reports the card unfit. Read in full:
  `../audio-vue/openspec/changes/card-minimum-at-type-floor/specs/card-layout/spec.md`.
- 2026-11-21: audio-vue `openspec/specs/type-scale/spec.md`: the requirement headings only (`openspec show ... | grep
  Requirement`), and "A role's size stays within its bounds" (line 50) not read in full. Open: a full read before apply,
  since the search's text sizes must stay within the bounds it states.
- 2026-11-21: `.claude/kb/agent/open-questions.md` and `pitfalls.md`, searched for tile, library, minimum, and search.
  The pitfall "A refused drop leaves its library tile undraggable" (pitfalls.md, 2026-11-07) concerns tile identity
  (`SceneStore.drops`); this change does not alter a tile's id, so no conflict.
- 2026-11-21: each task in tasks.md read against the code above. Task 1.1: `SchemaFacts.Card` has no sizing field
  yet, so the task adds it. Task 2.2: the queue key form matches `send`. Task 3.1: `TileSet` is the existing per-key store.
  Task 4.1: see F2. No task removes or renames a symbol, so no removal search was needed.

## Findings

- **F1. The ladder's equal steps do not keep an ASPECT card's shape** (resolved)
  - Plan: `specs/scene-rendering/spec.md`, "A tile's size is the first size on a ladder": steps grow width and height by
    equal whole cells; design decision 1 says an ASPECT card keeps its declared aspect on the ladder.
  - Code: `Sizing.ASPECT` (`../audio-vue/src/cards/base.py` line 63) is "fitted and centred inside whatever it is given",
    with `aspect` required (line 311). Equal steps would give a shape the card does not keep.
  - Goes to: requirement (the maintainer rules first). Design decision 1 and tasks 2.1 already state the aspect case.
  - Resolution: maintainer ruled (2026-11-21): aspect-locked cards step in their declared aspect. Added to the ladder requirement.

- **F2. The library caption shows the placed card's size, not the tile's** (resolved)
  - Plan: the caption names the size the tile is drawn at (spec, "A library tile names the size it is drawn at").
  - Code: `CardLibrary.swift` line 14-15 and 37: `sizeOf` is "a card's size on this scene's grid, by name", so the caption
    shows where the card sits on the open scene. Line 127 uses it as `size ?? card.minimum` for the drop preview. A library
    tile for a card not on the scene gets nil, so for most tiles the caption is the declared minimum or empty.
  - Goes to: requirement (the maintainer rules first).
  - Resolution: maintainer ruled (2026-11-21): the caption shows the tile's drawn size. Stated in the caption requirement; task 4.1 follows it.

- **F3. The unchanged requirement "Library tiles follow the scene's settings" still states the old decision in its Source line** (resolved)
  - Plan: the requirement is not in the delta. Its Source line reads "a tile holds one card at its minimum, which no
    layout edit changes".
  - Code: not code. The decision is amended (maintainer, 2026-11-21), so the Source line is stale.
  - Goes to: requirement. A Source-line change still needs a MODIFIED entry with the full block.
  - Resolution: maintainer ruled (2026-11-21): MODIFIED with the amended Source line; behaviour unchanged. Added to the spec delta.

- **F4. The design assumes the console reads `x-sizing` and `x-aspect`; it does not today** (resolved)
  - Plan: design Context and Risks say a fixed-shape card's aspect is read from the exported schema.
  - Code: `SchemaFacts.swift` reads `x-min-cells` and `x-placeable` only (line 118-130).
  - Resolution: task 1.1 adds both to `SchemaFacts.Card`. The design text already says "read from the exported schema, not
    hard-coded", so no design change.

- **F5. The render count in design decision 1 understated the cost** (resolved)
  - Plan: "hundreds of renders" for a full search.
  - Code: one render per cell, cols × rows, per card. The grid's cols are not fixed in the fixture; rows are 36.
  - Resolution: design decision 1 now says cols × rows, "hundreds or thousands" per card.

- **F6. Binary search assumes fit is monotone in k** (resolved, with a risk)
  - Plan: design decision 2 assumes a card that shows its reading at k shows it at every larger k.
  - Code: the helper's fit is the panel's own check (scene-render "The answer says what does not fit"), not a monotone
    function it documents. Non-monotone fit is possible if a layout drops text differently at some sizes.
  - Resolution: design Risks names it, with the tile-is-the-render check as the mitigation (decision 3). Not a
    requirement change: the spec states the ladder's result, not the search's internals.

## Questions for the maintainer

All three answered 2026-11-21 with the recommendations above.

1. **F1, ASPECT cards on the ladder.** Recommendation: an ASPECT card's ladder keeps its declared aspect, stepping
   width and height in the aspect's ratio, so the tile shows the card's real shape at the smallest size. Add one clause
   to "A tile's size is the first size on a ladder that shows its reading". Alternative: the ladder stays equal-step for
   every card, and an ASPECT card's tile shows the helper's fitted shape. That keeps one rule, but the tile is then not
   the card's smallest real shape.
2. **F2, the caption.** Recommendation: the library tile's caption shows the tile's drawn size in cells, as the spec
   says, and the caption stops showing the card's size on the open scene. The card's size on the scene is still shown
   where the scene's cards are. Alternative: keep both, as "drawn at N × M" and "on scene N × M".
3. **F3, the stale Source line.** Recommendation: MODIFIED for "Library tiles follow the scene's settings, not its cards",
   with the Source line changed to the amended decision and no other change. Alternative: leave the Source line, since
   the behaviour is unchanged.

## Confirmed

- `LibraryTiles.request(for:as:card:minimum:context:)` (line 246) takes a `minimum` argument, so the search can pass a
  ladder size with no new request field.
- `RenderQueue.submit(_:lane:key:)` (line 37) and lanes `library` and `thumbnails` (line 8-11) exist, as the design uses.
- `LibraryTiles.Tile.unfit` returns `layer.unfit`, so the tile's own render answers whether it fits (design decision 3).
- `scene-render` "A request may name its plates": the answer holds the named plates alone (audio-vue, read in full).
- `scene-render` "The answer says what does not fit": names each card that cannot show its reading at its size, by the
  panel's fit check (audio-vue, read in full).
- audio-vue `card-layout` delta (open change `card-minimum-at-type-floor`): a larger type than the floor shows the notice
  and the scene reports the card unfit, which is the case this change draws.
- The panel's rows are 36 in the schema fixture; the search's cost is stated from that.
- `Sizing.ASPECT` and `aspect` exist in audio-vue, and `x-sizing` and `x-aspect` are exported (`export.py` line 120-130).
- No open change in audio-vue names a console spec under its Impact for this change: the open change
  `card-minimum-at-type-floor` names `audio-vue-console` `scene-layout`, not `scene-rendering`, and this change does not
  modify `scene-layout`. The maintainer should still tell audio-vue's session when this change lands, as the open change's
  alignment already plans for `scene-layout`.
