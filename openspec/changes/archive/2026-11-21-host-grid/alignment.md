# Code alignment

## Read

Pass 2, the same day, on audio-vue's `host-grid` as built and its closing note (F8 to F11).
Pass 1, 2026-11-21, on `dev` after `e47c193` with `scene-settings` built and not archived, against
audio-vue's `host-grid` as designed (0 of 19 tasks built there). Reads of audio-vue are of its plan,
not its code, and are re-read in task 1.1.

- `LaidOutScene.swift`: `init(_:defaultGrid:ids:)`, `doc(for:)`, `entry(for:)`, `card(_:on:id:)`.
- `SceneLayout.swift`: `init(grid:cards:)` (`.offGrid`, `.spaceTaken`, the tiling check).
- `GallerySections.swift`, `DisplayShape.swift`, `GridDensity.swift`, `GridGeometry.swift`.
- `SchemaFacts.swift`: `init?(schema:)` (nil without the grid block's `cols` and `rows` defaults),
  `scaled`, `minimums(forRows:)`.
- `SceneDrafts.swift`: `draft(for:defaultGrid:)`, `new(on:among:)`, the three re-reads that pass
  the old layout's grid. `SceneEditor.minimums`. `SceneSession`: `isEditable`, `canSave`.
- `LibraryTiles.swift`: `Key` (settings and grid), `fill`, `request`.
- `PanelState.swift`: the display section's width and height. `PanelScenes.swift`: fixed scenes
  left out.
- By grep, the app target's uses: `ScenesPage` (`shape(of:)`, `defaultGrid`), `SceneGallery`
  (`GallerySections`, `GridDensity.grid`, "Other Shapes"), `SceneEditorView` (`panel.aspect`, the
  shape test, `minimums(forRows:)`), `SceneSettings` (`GridDensity.choices`), `SceneCanvas` and
  `LayerStack` (the grid's aspect).
- Standing specs: `scene-layout`, `scene-canvas`, `scene-gallery`, `scene-apply`,
  `scene-rendering`, `scene-saving`, every requirement naming a shape, a scaled minimum or a
  scene's own grid.
- audio-vue `host-grid`: `proposal.md`; `specs/` for `scene-grid`, `control-state`, `card-layout`,
  `settings-store`, `control-commands`; `design.md` D3 to D5 and D8; `host-grid-handoff.md`.

## Findings

- **F1. The schema reader fails once the grid block holds only `gap`** (resolved)
  - Plan: the grid comes from the state.
  - Code: `SchemaFacts.init?(schema:)` returns nil without `block.grid`'s `cols` and `rows`
    defaults, and with no facts the Scenes page shows nothing.
  - Goes to: design and task.
  - Resolution: D1 drops the guard with `defaultGrid`; task 2.2 checks the refreshed schema.
- **F2. Every span is written back explicitly** (resolved)
  - Plan: an unset span is kept (ruling 2).
  - Code: `entry(for:)` always writes `colspan` and `rowspan`.
  - Goes to: design and task.
  - Resolution: D3, task 2.4.
- **F3. A layout refuses a card past its grid** (resolved)
  - Plan: a scene too wide is opened (ruling 1).
  - Code: `SceneLayout.init` throws `.offGrid`, so on the panel's grid such a scene would not lay
    out at all.
  - Goes to: design.
  - Resolution: D2 lays it out on its reach, and asks "too wide" of the content against the panel.
- **F4. Too wide was a kind of read-only** (resolved)
  - Plan: a scene too wide is edited and saved.
  - Code: `SceneEditorView` makes a scene of another shape read-only, and `scene-saving`,
    `scene-gallery` and `scene-canvas` each carried a clause for it.
  - Goes to: specs.
  - Resolution: those clauses are removed or replaced in this change's deltas.
- **F5. The canvas fits the scene at `cols ÷ rows`** (resolved)
  - Plan: cells are near-square, the grid filling the display.
  - Code: `LayerStack` and `SceneCanvas` use the grid's own aspect, which is the display's only
    where the column count is whole.
  - Goes to: design and task.
  - Resolution: D5, task 5.2.
- **F6. The app lays out no fixed scene** (confirmed, no change)
  `PanelScenes` leaves fixed scenes out, so calibration's 64 × 36 grid is nothing the app reads.
- **F7. Library tiles are keyed on the grid** (resolved)
  One grid per panel makes the key's grid redundant; D4 removes it.

- **F8. A re-read after a save narrowed an open scene's grid** (resolved; found during apply)
  - Plan: D2 kept the canvas's width until the scene is opened again.
  - Code: `SceneDrafts.reread` laid the saved document out afresh, so a too-wide scene saved with
    its cards moved in came back on fewer columns than the editor's layout, and the two no longer
    compared equal.
  - Resolution: `LaidOutScene.init` takes `keeping:`, the layout it replaces, and keeps its columns.
- **F9. Nothing laid drafts out again on a new grid** (resolved; found during apply)
  - Plan: task 2.5.
  - Resolution: `SceneDrafts.relay(on:)`, called by `SceneStore.follow(grid:)` (D1).
- **F10. audio-vue as built** (confirmed, 2026-11-21, from `host-grid-landed-handoff.md`)
  Built as its hand-off described. Added: an unset `colspan` must start at column 0, which D3's
  rule already keeps; a row past the 36th is refused at load; the helper's refusal reads `does not
  fit this display: <why>`. The app works out a scene's reach from its cards. A stored scene still
  setting `cols` or `rows` is refused by the host. The app first sent the `grid` block back as
  held, so the scene could be neither drawn nor saved; the maintainer expected to open and resave
  it (2026-11-21). `LaidOutScene.content` now drops the two keys and `Draft.isUnsaved` is true
  while the stored document holds them, so it draws, and Save removes them.
- **F11. A colour scale's label changed** (confirmed, no app code)
  The schema's `warnings` scale is labelled "Status"; two tests named the old label.

## Questions for the maintainer

None open. Ruled 2026-11-21: a scene too wide is opened, edited and saved but not applied; an unset
span is kept until its card is resized; no editing with no display; `scene-settings` drops density
and its proving run waits for this change.

## Confirmed

- The state's display section is already read (`PanelState`), so the grid is one more field.
- `GridGeometry` divides a size by the grid, so stretched cells need nothing new.
- "A refused Apply says why" (`scene-apply`) already shows a switch the panel refuses.
- A failed drawing already falls back to boxes (`scene-rendering`), which covers a refusal the app
  did not foresee.
