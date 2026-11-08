# Design

## Context

See `proposal.md` for why. The state today, read on 2026-11-07:

- **The library.** `CardLibrary` (`AudioVueConsole/Scenes/CardLibrary.swift`) lists
  `scenes.facts?.placeable` in a `LazyVStack` with a search field. Each `CardTile` fills a rounded
  rectangle with `CanvasMetrics.color(for:)` at the aspect of `sizeOf(name)` (the editor's
  `minimums`, the schema's minimum scaled to the scene's rows), inside a 110 pt preview on
  `CanvasMetrics.backdrop`, with the name and `cols × rows` under it. `onDrag` sets
  `store.draggedKind`. `SceneEditorView` makes it with `editor?.minimums`.
- **The queue.** `RenderQueue` has two lanes, `.canvas` and `.thumbnails`. `nextIndex` takes the
  first canvas job, else the first job of any lane. Only the canvas lane replaces a waiting job with
  the same key, answering the replaced one `nil`.
- **The thumbnails.** `SceneThumbnails` (`@MainActor @Observable`, held by `SceneStore`) draws each
  scene in the thumbnails lane and keeps a `CGImage` by scene id. `ScenesPage.drawThumbnails` runs
  only once `renderer.verdict` is `.same` or a drift that is not `sharesNothing`. `SceneStore.forget`
  drops drafts and thumbnails when another panel is shown.
- **The request.** `RenderRequest(doc:builtIn:context:plates:backdrop:)` already carries `plates`
  and `backdrop`. `LaidOutScene.doc(for:)` writes the scene's doc with any layout's cards, giving a
  new card only `card` and its cells. `SceneLayout(grid:cards:)` throws `offGrid` for a card outside
  its grid. `RenderedLayer.layers(of:cardIDs:)` turns an answer into layers with `image`, `rect` and
  `unfit`.
- **The helper** (audio-vue `scene-render`): a request naming one plate, with `backdrop: false`,
  answers that plate's layer alone, the plate and its cards over a transparent field, at the plate's
  rect. A plate may be translucent; its layer is premultiplied.
- **The canvas's backdrop.** `SceneRendering.backdrop` (public) is the backdrop layer at the
  display's full size, rect `[0, 0, width, height]`, set by `take` from a whole-scene answer and
  cleared by `clear` on a refusal or failure. `SceneEditorView` already reacts to
  `rendering?.status` becoming `.drawn` by updating the scene's thumbnail. `Thumbnail.flatten`
  stacks layers in a premultiplied sRGB context, which matched audio-vue's stacking to 0 steps
  (`host-contract.md`).
- **Drift.** `CardDrift.boxes(name)` says whether a card must be a box; `sharesNothing` whether no
  card may be drawn.

## Goals / Non-Goals

**Goals:**

- The tile rules (what a tile request is, when tiles are drawn again, which cards are boxes) live in
  `ConsoleCore`, tested through the scripted helper as the thumbnails are.
- Tiles never delay the canvas, and a scene switch does not leave the helper drawing the last
  scene's tiles first.

**Non-Goals:**

- Asking the helper for a backdrop per tile: the canvas's is reused (D6).
- Drawing each card at a common size (ruled out: a tile is the card at its minimum).
- A tile per alternate or per card setting. A tile is the card as a drop places it: `card` and its
  cells only.
- Changing what a drop places, or the library's list, search or drag.

## Decisions

### D1. A tile is a one-card copy of the open scene, naming its one plate

For each placeable card the request's doc is `laidOut.doc(for: layout)`, where `layout` is
`SceneLayout(grid: laidOut.layout.grid, cards: [LayoutCard(kind: name, cells: CellRect(col: 0,
row: 0, cols: min.cols, rows: min.rows))])`, with `plates: [0]`, `backdrop: false` and the scene's
own `builtIn`. Every scene field but `cards` is kept, so the tile has the scene's analysis block,
type and plate settings.

- *Why (0, 0):* the corner is the one place every grid has, and the plate there is one a drop at
  the corner places. audio-vue `scene-grid` gives a card a whole gap at the region's edge and the
  same gap between cards, so a plate at the corner is at most half a gap smaller each way than one
  in the middle: 4 px at a 1080 px region with an 8 px gap, 2.5 px at 720.
- *A card whose minimum is off the grid:* `SceneLayout` throws, and the tile stays a box with no
  request.
- *Alternative:* a request with the scene's own cards plus the new one somewhere free. Rejected: a
  full scene may have no free space, and the other cards would be drawn for nothing.

### D2. A third lane, between the canvas and the thumbnails, that replaces by key

`RenderQueue.Lane` gains `.library`. `nextIndex` takes the first canvas job, then the first library
job, then any. The library lane replaces a waiting job with the same key, as the canvas lane does,
and a tile's key is `tile:<card name>`. A replacement looks only within the job's own lane, so a key
can never reach across lanes. When the user opens a scene with other settings before the last
scene's tiles are drawn, each waiting tile is replaced by the new scene's request for the same card,
and the old draw's call is answered `nil` and skipped. Nothing waits for a scene no longer open, and
the queue needs no cancel.

Every tile is submitted at once (D3), not one after another. `sendNext` runs as soon as an answer is
handed back, before the caller can submit its next request, so tiles submitted one at a time would
let a waiting thumbnail go between every two tiles.

- *Alternative:* tiles in the thumbnails lane. Rejected: the gallery's thumbnails, drawn when the
  Scenes page opened, would come first while the library is on screen and the gallery is not.

### D3. `LibraryTiles` keeps one set of tiles, for the settings they were drawn in

A `@MainActor @Observable` `LibraryTiles` in `ConsoleCore`, held by `SceneStore` beside the
thumbnails, keeps:

- `key`: the open scene's doc with `cards` and `name` removed, and its grid (`JSONValue` and
  `CellSize`, both `Hashable`). Every scene has its own `name`, a copy from Duplicate included, and a
  plate does not draw it, so a key keeping it would match no other scene. A doc that declares no
  grid takes the schema's default, so the grid is kept apart from the doc. The scene's other keys
  (`grid`, `glass`, `backdrop`, `palette`, `type`, `analysis`, `display`, `fixed`, read from
  audio-vue's exported `scene` definition, 2026-11-07) all stay in the key.
- `tiles`: by card name, the plate's layer, its `unfit` names, and its image: the plate stacked over
  the backdrop's patch (D6), or the plate alone while there is no backdrop.
- `backdrop`: the canvas's backdrop layer, given by `show(backdrop:)`, which stacks every tile held
  again with no request. It is cleared with the tiles when the key changes. The key holds the
  scene's `backdrop` block and grid, and `forget()` runs when another panel, with another display,
  is shown, so a tile never sits over another scene's backdrop.

`draw(for laidOut:, cards:, drift:, context:, through queue:)` empties `tiles` when the key differs,
then submits, all at once in a task group, a request for each card it has neither a tile for nor a
request under way for under the current key, skipping a card `drift.boxes` names. Each card's
minimum is `SchemaFacts.scaled(card.minimum, toRows: grid.rows)`, the value the editor's `minimums`
holds. The caller applies the verdict, as `ScenesPage.drawThumbnails` does: it calls `draw` only for
`.same` (drift nil) or a drift that is not `sharesNothing`. A failed or refused answer leaves that
card a box. An answer that arrives after the key has changed is dropped. A card `drift.boxes`
names loses any tile drawn before, and the editor forgets every tile when the verdict lets no card be
drawn, so a card whose code comes to differ while the editor is open is a box again (added in the
build). `forget()` empties it, and `SceneStore.forget` calls it beside the thumbnails, so another
panel's tiles are never shown.

Only one key is kept. Scenes on one panel usually share their settings, and the library is redrawn
in under half a second (15 placeable cards in the current schema at the measured 21 to 25 ms a
plate), so a cache of several keys would add little.

- *Alternative:* key by scene id. Rejected: scenes with the same settings would draw the same tiles
  again, and a scene-settings edit, when it comes, would not draw them again.

### D4. The editor starts the draw once the canvas has attached

`SceneEditorView` already follows `renderer.phase` in `.task(id:)`. After the canvas's
`rendering.attach(queue)`, the same task calls `store.tiles.draw(...)`, under the same rule as the
thumbnails: only once `verdict` is `.same` or a drift that is not `sharesNothing`. Before that, and
when the renderer failed or the code cannot be compared (`.damagedBundle`, `.unreadable`), the
tiles stay boxes. The lane already orders the requests; starting after `attach` only stops the first
scene's tiles being queued before the canvas's first request.

The existing `.onChange(of: rendering?.status)` that updates the thumbnail on `.drawn` also calls
`store.tiles.show(backdrop: rendering.backdrop)` when the backdrop is there.

### D5. `CardTile` shows the layer's image, or the box it shows today

`CardLibrary` takes the tiles by name. `CardTile` takes an optional image and the unfit flag. With
an image, the preview shows it with `.resizable().aspectRatio(contentMode: .fit)` in place of the
tinted rectangle. The image carries the scene's backdrop, so the `CanvasMetrics.backdrop` ground
shows only round it, or behind a plate drawn with no backdrop. Without one, it is the tinted
rectangle, as now. An unfit card adds a line under its name, "Too small to show its reading", in the
secondary style, the canvas's wording. The name, size label and drag are unchanged.

The image's pixels are the plate's at the panel's size. On a 720 px panel a cell is 20 px whether
the grid is 64 × 36 or 96 × 36 (audio-vue `scene-grid`), so the RTA's minimum of 17 × 10 cells is
340 × 200 px less its gaps, and the largest, narrowband at 32 × 19, is 640 × 380. Into a column of
230 pt ideal width, these are scaled down, and the logo (6 × 4, 120 × 80) up. Either way it is the
plate a drop places.

### D6. A tile is its plate stacked over the canvas's backdrop, cut to the plate's rect

A new `Thumbnail.tile(plate:over:)` cuts the backdrop's image to the plate's rect with
`CGImage.cropping(to:)`, whose rect counts from the image's top left in pixels, as a layer's rect
does, then draws the cut and the plate in a premultiplied sRGB context the plate's size, as
`flatten` stacks them. The result is what the panel shows where a card sits at the region's
top-left corner, blur and a translucent plate included. It is made when a tile arrives with the
backdrop held, and for every tile held when `show(backdrop:)` gives one.

- *Alternative:* `backdrop: true` on each tile request. Rejected: each answer would carry the whole
  display's backdrop, 5.5 MB at 1920 × 720, to use one corner, 15 times over, the same image the
  canvas already holds.
- *Alternative:* centre the plate on the backdrop, or show the whole backdrop scaled. Rejected: no
  card sits there, so the tile would show a place the panel does not.

## Risks / Trade-offs

- [A gradient or image backdrop shows only its top-left patch] → Accepted: it is what the panel
  shows under a card there, and every tile shows the same corner, so tiles compare fairly.
- [The canvas cannot draw the scene, so there is no backdrop] → The plate sits on the library's
  plain ground, as before the ruling; the tile still shows the card.
- [The helper prepares a new run for a scene whose analysis block differs from the default] → The
  canvas's first request for that scene pays it before any tile's, so the tiles reuse it.
- [15 requests every time settings change] → Library lane, behind the canvas, replaced by key.
  The search field filters what is shown, not what is drawn, so the tiles are ready when it is
  cleared.
- [A card the schema marks placeable but the bundle does not carry] → `drift.boxes` names it (no
  manifest declares it), or the helper refuses it. Either way it stays a box.
