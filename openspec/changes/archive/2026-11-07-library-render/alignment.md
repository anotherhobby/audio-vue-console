# Code alignment

## Read

Pass 1, 2026-11-07.

- `AudioVueConsole/Scenes/CardLibrary.swift`: `CardLibrary` (search, `LazyVStack`, `sizeOf`),
  `CardTile` (tinted box at the minimum's aspect, `onDrag` setting `draggedKind`), the preview
  (tasks 3.2, design D5).
- `AudioVueConsole/Scenes/SceneEditorView.swift`: `make()` (the `LaidOutScene`, `minimums`,
  `SceneRendering`), `follow(_:)` on `renderer.phase`, `.onChange(of: verdict)` (tasks 3.1, D4).
- `AudioVueConsole/Scenes/ScenesPage.swift`: `drawThumbnails()`'s verdict rule, `laidOut(_:facts:)`
  (task 3.1).
- `AudioVueConsole/Canvas/SceneStore.swift`: `drafts`, `thumbnails`, `forget()` (task 2.3).
- `ConsoleCore/Sources/ConsoleCore/RenderQueue.swift`: `Lane`, `submit` (replacement by key in any
  lane for a canvas job), `sendNext` (the next job is sent before the answered caller resumes),
  `nextIndex` (task 1.1, D2).
- `RenderRequest.swift`: `plates`, `backdrop`, `builtIn`, `message` (D1).
- `LaidOutScene.swift`: `doc(for:)` keeps every field but `cards`, a new card's entry is `card` and
  its cells (D1).
- `SceneLayout.swift`: `SceneLayout(grid:cards:)` throws `offGrid`; `LayoutCard`, `CellRect` inits
  (D1, task 2.2).
- `RenderedLayer.swift`: `layers(of:cardIDs:)`, `unfit`, `image` (task 2.2).
- `SceneRendering.swift`: `draw` keys (`plate:…`, `scene`), `apply(_:)` for each verdict, `scene` is
  public (tasks 2.2, 3.1).
- `SceneRendering+Messages.swift`: the unfit wording "Too small to show its reading" (D5).
- `SceneThumbnails.swift`: the model `LibraryTiles` follows (D3).
- `CardDrift.swift`: `boxes(_:)`, `sharesNothing` (D3). `CardCodeCheck.swift`: `CardCodeVerdict`'s
  four cases (F6).
- `Renderer.swift`: `queue`, `verdict`, `Phase` (D4). `PanelScenes.swift`: `facts`, `context` (task
  3.1). `SchemaFacts.swift`: `placeable` (sorted by name), `minimums(forRows:)`, `scaled(_:toRows:)`
  (task 2.2).
- Tests: `SceneRenderingTests.swift`'s `FakeRender` (honours `plates` and `backdrop: false`, marks a
  card named `tiny` unfit) and `RenderingFixture`; `SceneThumbnailsTests.swift`; `RenderQueueTests.swift`
  exists (tasks 1.1, 2.1).
- audio-vue, read in full: `scene-render`, `card-layout`, `scene-grid`, `settings-schema`
  (`openspec show … --store audio-vue`). Open changes: none (`openspec list --store audio-vue`).
- audio-vue's exported schema (`schema.export.json_schema()`, run 2026-11-07): 17 cards, 15
  placeable, minimums from 6 × 4 (logo) to 32 × 19 (narrowband); grid default 64 × 36; the `scene`
  definition's keys.
- KB: `pitfalls.md` (the gate's type check builds packages only; the drag uses `onDrag`;
  `RenderPreview` for screenshots), `open-questions.md` (no open item).
- Removals and renames: none. No task removes or renames a symbol.

Pass 2, 2026-11-07, after two rulings: Q1 yes, and tiles sit over the scene's backdrop in place of
the plain ground (maintainer). Read again for the backdrop:

- `SceneRendering.swift`: `backdrop` is public; `take` sets it from a backdrop layer, `clear` sets it
  nil on a refusal or failure; `end` sets `.drawn` once no request is in flight (D4, D6).
- `SceneEditorView.swift`: `.onChange(of: rendering?.status)` updates the thumbnail on `.drawn`
  (task 3.1).
- `Thumbnail.swift`: `flatten` stacks in a premultiplied sRGB context, flipping a layer's top-left
  rect into Core Graphics' bottom-left space (task 2.1).
- Every task read again against the new D6; tasks renumbered in group 2 (2.1 `Thumbnail.tile`, 2.2
  `LibraryTiles`, 2.3 `SceneStore`), and the references above follow.

## Findings

- **F1. Tiles submitted one at a time would interleave with thumbnails** (resolved)
  - Plan: the library lane goes before the thumbnails lane.
  - Code: `RenderQueue.sendNext` resumes the answered caller, then sends the next waiting job at
    once, before the caller can submit again. A loop submitting tiles one by one leaves no library
    job waiting at that moment, so a waiting thumbnail is sent between every two tiles.
  - Goes to: design. D2 and D3 now submit every tile at once in a task group; task 2.2 carries it
    and tests that stale answers are dropped.

- **F2. A corner plate is not the size of a middle one** (resolved)
  - Plan: D1 said a lone card's plate is the same size wherever it sits.
  - Code/spec: audio-vue `scene-grid` gives a whole gap at the region's edge and the same gap between
    cards, so a corner plate is up to half a gap smaller each way (4 px at 1080, 2.5 px at 720).
  - Goes to: design. D1 corrected; the tile is still a plate a drop places, at the corner.

- **F3. The proposal cited `settings-schema` for placeable cards and minimums** (resolved)
  - Plan: `audio-vue:settings-schema` for the placeable cards and their minimums.
  - Spec: `card-layout` states both the declared minimum and that a process's card is exported not
    placeable; `settings-schema` states the export as one JSON Schema.
  - Goes to: proposal's Impact, corrected.

- **F4. `draw` would take six parameters, over the gate's five** (resolved)
  - Plan: `draw(for:cards:minimums:verdict:context:through:)`.
  - Code: each card's minimum is `SchemaFacts.scaled(card.minimum, toRows: grid.rows)`, which is
    what the editor's `minimums` holds, so it needs no parameter. The verdict rule is the caller's,
    as `ScenesPage.drawThumbnails` applies it for thumbnails, leaving the drift. This is the
    simpler shape anyway, not a workaround.
  - Goes to: design D3 and tasks 2.2 and 3.1: `draw(for:cards:drift:context:through:)`.

- **F5. A key holding the scene's name matches no other scene** (resolved)
  - Plan: the key is the doc with `cards` removed.
  - Code: the exported `scene` definition has `name`, and every scene, a Duplicate copy included,
    has its own, so the spec's "two scenes with the same settings" scenario could never hold.
  - Goes to: design D3 and task 2.2: `name` is removed from the key too.

- **F6. A damaged bundle or unreadable manifest is not named in the tile requirement** (resolved)
  - Plan: "A library tile the helper cannot draw is a box" lists the renderer starting or failed,
    a card's own code differing, shared code differing, off the grid, refused or failed.
  - Code: `CardCodeVerdict` also has `.damagedBundle` and `.unreadable`. For these the canvas says
    the renderer is unavailable (`SceneRendering.apply`), and the thumbnails' rule draws nothing.
    D4 follows the same rule, so the tiles would be boxes, but the requirement does not say so.
  - Goes to: requirement. The maintainer rules first (Q1).
  - Resolution: Q1 yes (maintainer, 2026-11-07). The requirement lists code that cannot be
    compared, with a scenario for a damaged bundle; D4 names the two verdicts.

- **F7. The replacement search matches a key in any lane** (resolved)
  - Plan: the library lane replaces by key.
  - Code: `submit` looks for the key among all waiting jobs. The prefixes (`plate:`, `scene`,
    `thumbnail:`, `tile:`) never collide today, but the rule should not depend on that.
  - Goes to: design D2 and task 1.1: the search is within the job's own lane, with a test.

- **F8. Tiles over the scene's backdrop reuse the canvas's layer** (resolved)
  - Plan: the ruling (maintainer, 2026-11-07) replaces the plain ground with the scene's backdrop.
  - Code: `SceneRendering.backdrop` is the whole display's backdrop, held once the canvas has drawn
    and nil after a refusal. The key holds the scene's `backdrop` block and grid, and tiles are
    forgotten on a panel switch, so a held backdrop always belongs to the tiles' settings. A tile
    asks for no backdrop: each would be 1920 × 720 × 4 bytes, about 5.5 MB, 15 times over.
  - Goes to: requirement (the maintainer ruled; spec delta changed), design D3 to D6, tasks 2.1, 2.2,
    3.1, 3.2 and 4.1.
  - Resolution: written in pass 2. With no backdrop, as after a refusal, the plate sits on the plain
    ground (spec scenario "A refused scene").

## Questions for the maintainer

None open. Q1 (F6) was answered yes on 2026-11-07.

## Confirmed

- The helper answers one named plate with `backdrop: false` with that plate's layer alone, over a
  transparent field (audio-vue `scene-render`, "A request may name its plates", "Each plate is a
  layer"). `RenderRequest` already sends both fields.
- `LaidOutScene.doc(for:)` keeps every scene field but `cards`, and a new card's entry is `card` and
  its cells, what a drop places.
- No scene-level block refers to a card (the exported `scene` keys), so a one-card copy of any scene
  is one the panel would load, given a card on the grid.
- `SceneLayout(grid:cards:)` refuses a card off the grid with `offGrid`, so a too-wide tile sends no
  request.
- A card at its minimum at the shipped sizes shows its reading (audio-vue `card-layout`), so an
  unfit tile appears only under larger host sizes; `RenderedLayer.unfit` carries the helper's names.
- `SceneStore` is owned by the App and `forget()` runs on a panel switch (`ScenesPage`), so tiles
  held there are dropped with the thumbnails.
- `RenderingFixture` and `FakeRender` already answer a one-plate, no-backdrop request with one plate
  layer, so task 2.2's tests need no new fake.
- The drag stays on `onDrag` (`pitfalls.md`), untouched by task 3.2.
- Numbers: 15 placeable cards at 21 to 25 ms is 0.32 to 0.38 s; a 720 px region gives 20 px cells
  for 64 × 36 and 96 × 36 alike; narrowband's 32 × 19 is 640 × 380 px less gaps.
