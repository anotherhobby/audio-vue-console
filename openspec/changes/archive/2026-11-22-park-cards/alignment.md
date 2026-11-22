# Code alignment

## Read

- 2026-11-22, console: `ConsoleCore/Sources/ConsoleCore/SceneLayout.swift` (`SceneLayout` and its
  checking `init(grid:cards:)`: off-grid, overlap and tiling refusals; `init(checked:)`; `widened`).
- 2026-11-22, console: `SceneLayoutEdits.swift` (`adding`, `moving` with `clampedOffset`,
  `placement`, `resizing`, `grouping`, `ungrouping`, `removing`, `setting`, `unsetting`,
  `changingSetting`).
- 2026-11-22, console: `SceneContent.swift` (layout and blocks, `with(layout:)`).
- 2026-11-22, console: `SceneEditor.swift` whole (selection over `layout.widened`, `selectedCards`,
  `resizableCard`, previews, `move`, `drop`, `group`/`ungroup`, `deleteSelection`, the settings
  edits, `commit`/`commitContent` keeping `selection ∩ next.layout.cards`, `registerUndo`).
- 2026-11-22, console: `LayoutRefusal.swift` (cases and sentences).
- 2026-11-22, console: `GridGeometry.swift` (no origin; `cell(at:)` and `cells(touching:)` clamp to
  the grid; `rect(of:)` is linear, so negative cells map without change).
- 2026-11-22, console: `LaidOutScene.swift` (`doc(for:)` and `isTooWide` read `content.layout`
  only; `entry(for:)` finds a card's entry by its parse id).
- 2026-11-22, console: `SceneThumbnails.swift` (draws from `content`, skips empty and too-wide
  layouts).
- 2026-11-22, console: `SceneRendering.swift` (`PlacedLayer`, `plates` by card ids, `Target`,
  `show(_:)` through `PlateChanges.needed`, `draw` (clears for an empty or too-wide layout), `take`
  (keeps only layers whose cards are in the current layout), `clear`).
- 2026-11-22, console: `LibraryTiles.swift` (`request(for:as:card:minimum:context:)`: one card at
  the grid's top-left, one plate, no backdrop).
- 2026-11-22, console: `SceneSession.swift` (`hasCards`, `canSave`, `isTooWide`, `canApply`,
  `save`, `apply` through `writes.apply`), `SceneWrites.swift` (`saveAll`, `Failed`),
  `SceneDrafts.duplicate` (copies `draft.content` whole).
- 2026-11-22, console app: `Canvas/SceneCanvas.swift` whole (region-local targets, outlines,
  handles and marquee; the pane-level tap clears the selection; `nudge` calls `editor.move`;
  `footerLine`'s order), `Canvas/LayerStack.swift` (`rect(of:scale:cells:)` is `private`),
  `Canvas/CanvasMetrics.swift` (`nudge` 1, `shiftedNudge` 4), `Canvas/ArrangeCommands.swift`
  (Group through `groupRefusal`, Ungroup through `canUngroup`).
- 2026-11-22, console app: `Scenes/SceneEditorView.swift` (the toolbar: Save on `canSave`, Apply on
  `canApply` with `applyHelp`, Duplicate always enabled; `fileActions`), `Scenes/SceneGallery.swift`
  (`SceneRow`'s too-wide note, the menu's Duplicate), `Scenes/UnsavedScenes.swift` (`Failed` read
  at lines 22, 77, 88, 111, 139), `Scenes/SceneInspector.swift` (reads `editor.selectedCards`).
- 2026-11-22, callers searched: `move(by:`, `previewMove`, `select(touching` across
  `AudioVueConsole/` and `ConsoleCore/` (results in F4).
- 2026-11-22, audio-vue specs: `scene-render` and `scene-plate`, read in full
  (`openspec show <id> --type spec --store audio-vue`).
- 2026-11-22, audio-vue open changes: `openspec list` shows only `text-case` (14 of 26). Its deltas
  are to `card-layout`, `settings-schema`, `styles` and `text-case`, none to `scene-render` or
  `scene-plate`. Its Impact names `audio-vue-console:scene-settings`, which this change does not
  modify.
- 2026-11-22, KB: `pitfalls.md` (undo manager not there in `init`; dragged text unreadable while
  hovering; a refused drop leaves its tile undraggable; a layout's card ids belong to one parse; a
  MODIFIED block cannot drop a scenario), `open-questions.md` (nothing on the canvas or saving).
- 2026-11-22, the suite: `xcrun swift test --disable-xctest` in `ConsoleCore`, 756 tests in 100
  suites pass, with the refreshed contract.
- Tasks read, groups 1 to 6, each against the files above. Removals and renames: `move(by:)` →
  `nudge(by:within:)`, `previewMove` → `previewDrag`, `SceneWrites.Failed` → an enum. Each caller
  is assigned in F4 and F6.

## Findings

- **F1. The corner scenario's numbers** (resolved)
  - Plan: `card-parking` "Crossing a corner" said the push clears the grid by 4 rows rather than 8
    columns.
  - Code: design D2 measures the push from the dragged position. A 10 × 4 card at the bottom-right
    corner dragged +2 columns, +1 row sits at column `cols − 8`, row `rows − 3`. Clearing the
    bottom edge takes 3 rows, and clearing the right edge takes 8 columns.
  - Goes to: the scenario's wording. The requirement is unchanged.
  - Resolution: the scenario now reads "pushed 3 more rows down … rather than 8 more columns right".

- **F2. A pane with no room beyond the crossed edge** (resolved)
  - Plan: `card-parking` "No room off the panel" refuses a drag across the right edge when the
    panel fills the pane's width.
  - Code: design D2 clamps the shifted block to the reach before deciding. With no room right of
    the panel, the reach ends at the grid's last column, so the clamped block stays wholly on the
    grid and the drag is an ordinary move that stops at the edge, as it does today. A refusal comes
    only where there is some room, but less than the card needs.
  - Goes to: requirement. The maintainer rules first.
  - Resolution: ruled (maintainer, 2026-11-22): refused. D2 now decides on the unclamped block, and
    refuses `.noRoomOffPanel` where clamping to the reach brings it back onto the grid. The spec
    keeps "No room off the panel" and adds "Too little room off the panel". Task 1.3 tests both.

- **F3. Parked plates cannot go through the scene's draw path** (resolved)
  - Plan: design D7 drew a parked plate "alone", unspecified path.
  - Code: `SceneRendering.take` keeps only layers whose cards are in the current layout
    (`current[members] != nil`), and `draw` clears every plate for an empty or too-wide layout.
  - Goes to: design and task.
  - Resolution: D7 and task 5.2 give parked plates their own request path, with a `parked:` queue
    key, stored in `parked`, and `clear` empties `parked` too.

- **F4. Callers of the renamed move** (resolved)
  - Plan: task 2.3 adds a drag and keeps the nudge.
  - Code: `editor.move(by:)` is called for drags and nudges in `SceneCanvas.swift` (lines 182, 230)
    and in tests (`SceneSessionTests.swift:38`, `SceneEditorUndoTests.swift` at lines 21, 60, 61,
    70, 77, 88, 98, 200). `previewMove` is called in `SceneCanvas.swift:238` and
    `SceneEditorTests.swift:55,58`.
  - Goes to: task.
  - Resolution: task 2.3 renames to `nudge(by:within:)` and `previewDrag(by:within:)` and lists
    every caller. A test moving past the edge is re-read, since a drag there now parks.

- **F5. Apply would save a scene with parked cards** (resolved)
  - Plan: task 3.1 refused `save()` while parked.
  - Code: `SceneSession.apply` calls `SceneWrites.apply`, which saves first and does not go
    through `SceneSession.save`.
  - Goes to: task.
  - Resolution: task 3.1 also makes `apply()` refuse while parked, verified by `FakeTransport`.

- **F6. `SceneWrites.Failed` becomes an enum** (resolved)
  - Plan: design D8.
  - Code: `Failed` is read in `UnsavedScenes.swift` (lines 22, 77, 88, 111, 139) and constructed in
    `SceneWritesTests.swift:40`.
  - Goes to: task.
  - Resolution: tasks 3.2 (test) and 3.3 (`UnsavedScenes`) own both.

- **F7. `LayerStack.rect(of:scale:cells:)` is private** (resolved)
  - Plan: task 4.2 slides parked plates as `LayerStack` slides plates.
  - Code: the slide is a `private` method of `LayerStack`.
  - Goes to: task.
  - Resolution: task 4.2 makes it a shared static.

- **F8. The scene-rendering source line overstated audio-vue's spec** (resolved)
  - Plan: the source line said `scene-render` lets a client ask for a scene of the card alone.
  - Code: audio-vue `scene-render` states that a request carries a scene as the store holds it and
    may name its plates. It does not mention a one-card scene. The console already sends one for
    library tiles (`LibraryTiles.request`).
  - Goes to: the source line.
  - Resolution: it now cites "A request carries a scene and its display" and "A request may name
    its plates".

## Questions for the maintainer

- **Q1 (F2), answered 2026-11-22: refused.** When a card is dragged across an edge where the pane has no room at all beyond it
  (for example, a panel that fills the pane's width, dragged right), should the drag stop at the
  panel's edge as it does today, or be refused, saying there's no room off the panel?
  *Recommended: stop at the edge.* The drag cannot go past the pane anyway, it is what happens
  today, and the user sees where the card can go. A refusal would stay only for a pane with some
  room, but less than the card needs. The spec's scenario would become "the pane has 3 columns
  right of the panel and a 10-column card is dragged across its right edge: refused", plus "no room
  at all: the card stops at the edge".

## Confirmed

- `Draft.doc`, `LaidOutScene.isTooWide`, `SceneThumbnails` and the scene's render request read only
  `content.layout`, so parked cards in `SceneContent` never reach the host, the helper's scene or a
  thumbnail (`LaidOutScene.doc(for:)`, `isTooWide`; `SceneRendering.draw`).
- `Draft.isUnsaved` compares `content` with the content read, which has no parked cards, so a parked
  card marks the scene unsaved, and Revert (`SceneEditor.revert(to:)`) and Versions
  (`replace(with:)`) leave none parked.
- A parked card keeps its parse id, so a returning card's entry and settings are found by
  `entry(for:)`, and a parked plate's one-card doc through `scene.doc(for:)` keeps its settings
  (pitfall "A layout's card ids belong to one parse").
- `SceneLayout(grid:cards:)` checks overlap and tiling, so building the returning layout through it
  gives `.spaceTaken` without a new check (D2 step 3). A group moved whole keeps its tiling.
- The inspector reads `editor.selectedCards`, so basing that on all cards shows a parked card's
  settings (D4).
- The Arrange menu's Group and Ungroup read `groupRefusal` and `canUngroup`, so D4 disables Group for
  a parked selection with no menu change.
- `SceneDrafts.duplicate` copies `draft.content` whole, so Duplicate must be gated (D8). The
  editor's Duplicate is enabled unconditionally today.
- audio-vue `scene-render`: a request may name its plates and leave out the backdrop, and each
  plate is its own layer with its rect. audio-vue `scene-plate`: a group shares one plate, so a
  parked group is drawn as one plate (D7).
- `shiftedNudge` is 4, as the scene-layout scenario "A move past the edge" assumes.
- No held item in `pitfalls.md` or `open-questions.md` bears on parking. The pitfalls on library
  drags concern library drops, which this change leaves alone.
