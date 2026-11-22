# Design

## Context

A library tile is drawn by `LibraryTiles` (`ConsoleCore/Sources/ConsoleCore/LibraryTiles.swift`): one render
request per card, built by `request(for:as:card:minimum:context:)` with the card placed at its declared
minimum, and sent through `RenderQueue` in the library lane (shown scene) or the thumbnails lane (ahead of
opening). Tiles are kept per settings `Key` (the scene doc without cards and name), so a scene with the same
settings reuses them. The helper's answer for each card carries `unfit`, which the tile already reads.

The helper takes one card at one size per request, so the console has to ask about sizes itself. See
proposal.md, "Why" and "What Changes", and the amended requirements in specs/scene-rendering/spec.md.

## Goals / Non-Goals

**Goals:**
- Each tile is drawn once per settings change, at the smallest size on a ladder that shows the reading.
- The search costs a few renders per card, not one per grid cell.
- The search result is reused by every later draw of the same settings.

**Non-Goals:**
- No change to the canvas's sizes, resize floor, or drop rule.
- No change to the helper or to audio-vue. The request shape is unchanged.
- No search for the library's thumbnails. Thumbnails keep their current size.

## Decisions

**1. The ladder grows both dimensions by the same whole-cell step.** Sizes tried are the declared minimum
plus `k` cells in width and `k` in height, for `k = 0, 1, ...` up to the grid's smaller dimension. This is
the smallest fitting size on that ladder, which the spec names. A full search over every width and height
pair costs one render per grid cell, cols × rows, per card, every time the font changes; at the panel's
36-row grid that is hundreds or thousands of renders per card. Alternative: the ladder grows width first, then height. Rejected, because it
finds a wide, short card and not the smallest one. Cards with a fixed shape (`x-sizing`, `x-aspect` in the
schema) must keep their aspect on the ladder; see Risks.

**2. Binary search on `k`.** Fit is assumed to be monotone in size: a card that shows its reading at `k`
shows it at every larger `k`. That is the same assumption the helper's notice relies on, since a larger
card has more room. The search takes the smallest `k` that fits in about log2(grid) renders. Alternative:
linear search from `k = 0`. Rejected: it costs up to the grid size in renders when the scene's type is
large, which is the case this change is for.

**3. The search's last fitting render is the tile.** The render that the binary search keeps for the
fitting `k` is the tile itself, so no card is rendered a second time. If no `k` fits, the tile is the
render at the declared minimum, which carries the too-small notice. This keeps the tile, the caption and
the unfit report in agreement, since they all come from the same answer.

**4. The found size is kept in `TileSet`, per card, beside the tile.** A redraw for the same `Key` reads the
size and does not search. A change to cards, layout or colours keeps the `Key`, so nothing is searched
again. A change to a text role changes the `Key`, so the search runs for the new settings.

**5. The search runs in the same lane as the tile.** The shown scene's search runs in the library lane,
ahead of the scene; a search made ahead runs in the thumbnails lane with its `tag`, as the tiles do now.
The search for one card is sent as its own queue key, so a later request for the same card replaces it, as
tile requests already do.

**6. The caption names the size.** The library tile view (`AudioVueConsole/Scenes/CardLibrary.swift`) reads
the tile's size from the `Tile` and writes it in cells beside the card name. The size is stored with the
tile, not recomputed.

## Risks / Trade-offs

- **Fit is not monotone for some cards.** A card might fit at `k = 2` but not `k = 3` if its layout drops
  text in a way that changes with size. → Mitigation: the tile is the render at the found `k`, so its own
  `unfit` report is the check. If the tile reports unfit, the search falls back to the declared minimum
  and the notice, which is the same outcome as no fit.
- **Fixed-shape cards.** A card whose `x-sizing` fixes its aspect cannot take an equal-step ladder without
  changing shape. → Mitigation: for those cards the ladder steps keep the declared aspect (width and height
  in the aspect's ratio), read from the exported schema, not hard-coded. This needs a check in the
  implementation before the ladder is written.
- **Latency.** A font change now costs a few renders per card before the tiles appear, where before they
  appeared at once. → Mitigation: tiles already appear one by one, each a box until drawn; the search runs
  per card in the same lane, so the first tiles can still appear first.
- **Card drawn at minimum, not at the library's grid.** A card wider than the grid is still a box, as now.

## Migration Plan

None. The change is in the console's own tile code and its caption. Nothing is stored, and the settings
store and the helper's requests are unchanged. A rollback is reverting the tile code.

## Open Questions

None that change the specs. The ladder's shape (equal steps) is a decision the spec states; if the
maintainer wants width-first or a full search, the spec's ladder requirement changes.
