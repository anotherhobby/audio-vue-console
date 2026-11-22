# Proposal

## Why

A library tile draws its card at the card's declared minimum, in the open scene's settings. When the
scene's text is larger than the minimum needs, the tile shows the too-small notice, so the library
cannot show what a card looks like at its smallest size. The user needs to see that size, because a
card can be resized down to it, and it is the honest preview of what smaller fonts would allow.

## What Changes

- A library tile holds one card at its smallest size on the panel's grid that shows its reading in the
  open scene's current font settings, not at its declared minimum. The size is found once when the
  scene's settings change, not for each tile or each redraw. Moving or resizing cards, and editing
  colours, do not find it again.
- The tile's caption names that size.
- A card whose declared minimum is larger than that size is drawn at its declared minimum.
- Where no size on the grid shows the reading, the tile is drawn at the card's declared minimum with its
  too-small notice, and is named as such. This is the existing rule for a tile the helper cannot
  show at its minimum.
- The declared minimum is unchanged. It remains the resize floor on the canvas, and the same on every
  scene. Resize does not use the tile's size. A card dropped at its declared minimum may show the
  too-small notice, and it can be resized no smaller.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `scene-rendering`: the library tile requirement changes from "at the card's declared minimum" to
  "at the smallest size that shows the reading in the scene's font settings", and the tile's caption
  and the no-fit case are stated. The decision of 2026-11-08, "a tile holds one card at its minimum",
  is amended to "at its minimum for the chosen font size". The Source line of "Library tiles follow the
  scene's settings, not its cards" carries the same amendment; its behaviour is unchanged.

## Impact

- Code: `ConsoleCore/Sources/ConsoleCore/LibraryTiles.swift` (the tile set and what size each tile is
  asked for), `ConsoleCore/Sources/ConsoleCore/RenderQueue.swift` (the one-time search for the size is
  queued behind the existing request paces), and the library tile view in `AudioVueConsole/Scenes/`
  (the caption).
- Helper: no new request fields. The search uses the existing render request: the scene document, with
  `plates` naming the one card, and the card's size on the grid. The reply's `unfit` says whether the
  card shows its reading at that size. Each search is one render per grid size tried, and it runs only
  when the scene's settings change.
- Specs in audio-vue this change relies on:
  - `audio-vue:card-layout`: a card at or above its minimum with larger type than the minimum shows the
    too-small notice and is reported unfit. Its "minimum" is the floor, which is being changed by the
    open change `card-minimum-at-type-floor` and is not yet archived; the console change relies on the
    changed wording, not the standing one.
  - `audio-vue:scene-render`: a request names its plates and carries the scene's `type` block, and the
    answer says what does not fit.
  - `audio-vue:type-scale`: each text role has a declared minimum and maximum, so the scene's sizes
    are always within those bounds.
- Canvas behaviour (resize, drop, the TOO SMALL notice on a card at its declared minimum) is unchanged.
- No open change in audio-vue modifies `card-layout` or `scene-render`'s wording relied on here, other
  than `card-minimum-at-type-floor`, which is named above. The alignment step checks this.
