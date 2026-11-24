# Code alignment

## Read

Pass of 2026-11-24.

- `ConsoleCore/.../SceneEditor.swift`: selection, `setSelection`, `clearSelection`, `preview`,
  `commitContent`, `drop`, `set`/`useDefault`/`editSetting`; checked D5's exclusivity hook and that
  a read-only scene refuses in `preview`.
- `ConsoleCore/.../SceneContent.swift`: fields `layout`, `blocks`, `parked`; `with(layout:)`, `cards`,
  `widened`; checked D2's new field against every constructor.
- `ConsoleCore/.../SceneContent+Parking.swift`: `dragging`, `nudging`, `removing`, `parking`,
  `pushedOff`; checked D3 can park through the same rules.
- `ConsoleCore/.../SceneLayoutEdits.swift`: `adding`, `placement`, `newGroupName` (private); checked
  group naming for pasted groups.
- `ConsoleCore/.../LaidOutScene.swift`: `entries`, `entry(for:)`, `copy(_:as:)`, `doc(for:)`, the
  parse's `card(_:on:id:)`; checked D1's entry form and D2's fallback.
- `ConsoleCore/.../SceneDrafts.swift` `duplicate`, `saved`: checked a copy carries the content.
- `ConsoleCore/.../SceneSession.swift` `apply`, `canApply`, `isEditable`; `SceneWrites.apply`:
  checked a gallery Apply needs no editor (D8).
- `ConsoleCore/.../LibraryTiles.swift`: `Key`, `TileSet`, `request(for:as:card:minimum:context:)`,
  `drawTile`, `settle`; `RenderQueue.submit` key replacement; checked D7.
- `ConsoleCore/.../SchemaFacts.swift` `placeable`, `library`: the placeable set D3 refuses by.
- `AudioVueConsole/Canvas/SceneCanvas.swift`: `paneView`, `region`, `reach`, focus, `pick`, footer
  refusal line; `CanvasStack.swift` `PaneFrame`; checked D4 and D9.
- `AudioVueConsole/Canvas/CanvasDropDelegate.swift`: `performDrop` → `editor.drop`.
- `AudioVueConsole/Scenes/CardLibrary.swift` `CardTile`: `.onDrag`, `.id(drops)`.
- `AudioVueConsole/Scenes/CardSettings.swift` `CardSettingsList.edit`, `blockEdit`, `fromScene`;
  `KeyedBlockRows.set`; `SettingControls.swift` `ColourWell`; checked D6 and D9's colour control.
- `AudioVueConsole/Scenes/SceneInspector.swift` `single`, `several`.
- `AudioVueConsole/Scenes/SceneEditorView.swift`: `make`, toolbar, `applyHelp`, `apply`.
- `AudioVueConsole/Scenes/ScenesPage.swift`, `SceneGallery.swift` (`SceneRow`, `menu`, tap to open),
  `WriteFailureAlert.swift` `writeFailureAlert(_:saveOver:discardMine:)`.
- KB: `pitfalls.md` (drag and drop, toolbar items), `open-questions.md` (nothing on these surfaces).
- audio-vue: `control-commands`, `settings-schema`, `scene-grid`, `scene-render` exist in the store;
  open change `backdrop-blur-dither` carries deltas to `scene-backdrop` only.
- Every task read against the code above. No task removes or renames a symbol.

Revision pass of 2026-11-24 (parked cards as editable as cards on the panel):

- `SceneLayoutEdits` `resizing` and `CellRect.resizedAcross`: bounded by `0...width`, so parked
  coordinates below zero need a range; the grid's callers pass `0...grid.cols` unchanged.
- `SceneEditor.resizableCard` (`layout.card(card.id) != nil`), `minimum(of:)` (reads the layout
  only), `groupRefusal` (`.parkedCannotGroup`), `previewResize` (answers a layout): each changed by 7.2.
- `ParkedPlates.sort`: redraws on settings alone; `SceneRendering.unfit`: `plates` only.
- `LayoutRefusal.parkedCannotGroup`: referenced in `SceneEditor.groupRefusal`, `ParkingTests`, and
  `SceneEditorParkingTests` (searched `AudioVueConsole/`, `ConsoleCore/`); 7.2 replaces each.

Revision pass of 2026-11-24 (library drops off the panel):

- `CanvasDropDelegate`: attached to `SceneCanvas.region`, with the region's geometry; the cell under
  the pointer comes from `GridGeometry.cell(at:)`, which clamps to the grid, so a drop could never
  land off it. Confirmed: library drops off the panel were never supported.
- `SceneContent+Parking` `pushedOff` (private) and `dragging`: the push-off rule 6.1 reuses.
- `SceneEditor.drop`, `previewDrop` and `SceneCanvas.outlineRects`'s `.dropping` case: what 6.2 and
  6.3 change. No other caller of `previewDrop` (searched `AudioVueConsole/`, `ConsoleCore/`).

Revision pass of 2026-11-24 (set-up tiles sized to fit):

- audio-vue `src/render_service.py` (the answer's layers carry `kind`, `placements`, `rect`, `unfit`,
  `bytes`) and `src/scene_layers.py` `_unfit`: `unfit` names only cards below their minimum or laid
  out to the too-small notice. `src/cards/base.py` `fit`: a card sheds drop steps (`Layout.level`)
  before that, and the meter's steps are its inner labels, end labels, then ticks
  (`src/cards/meter/card.py`). No field of the answer reports `level`.
- `LibraryTiles.Ladder` and `drawTile`: the search 5.1 reuses.
- `SceneCanvas.sizeOf` and `CanvasDropDelegate.dragged`: where 5.2's drop size enters.

Revision pass of 2026-11-24 (Cut added):

- `SceneContent.removing` (`SceneContent+Parking.swift`) and `SceneEditor.deleteSelection`: checked
  that a removal widens to whole groups and takes parked cards, so Cut needs no new removal rule.
- Tasks 3.4 and 3.5 read again with Cut in them; no other task touches the surface.

## Findings

- **F1. `with(layout:)` would drop pasted entries** (resolved)
  - Plan: D2 adds `SceneContent.entries`.
  - Code: `SceneContent.with(layout:)` builds a new value from `layout`, `blocks` and `parked`, and
    every layout edit goes through it (`SceneEditor.commit`), so a pasted card's entry would vanish at
    the next move.
  - Goes to: task.
  - Resolution: task 3.1 carries `entries` through `with(layout:)` and the initialiser, with a test
    that a pasted card moved keeps its entry.

- **F2. The canvas does not know which cards are placeable** (resolved)
  - Plan: D3's `.notPlaceable` needs the placeable set.
  - Code: `SceneCanvas` gets `minimums` through the editor and `sizeOf`; `SchemaFacts.placeable` is
    read only in `SceneEditorView`.
  - Goes to: task.
  - Resolution: task 3.5 passes the placeable names from `SceneEditorView` to the canvas.

- **F3. `newGroupName` is private to the layout** (resolved)
  - Plan: D3 names pasted groups `group-N`, unused on the grid or among parked cards.
  - Code: `SceneLayout.newGroupName(replacing:)` is private and sees only the layout's cards.
  - Goes to: task.
  - Resolution: task 3.3 adds a name finder over all the content's cards, parked included.

- **F4. A tile now takes a click and a drag** (resolved)
  - Plan: 4.3 adds a click to `CardTile` beside `.onDrag`.
  - Code: `pitfalls.md`, "A refused drop leaves its library tile undraggable": each tile is remade
    after a drop through `.id(drops)`. The library selection is held by kind on the editor, so a
    remade tile keeps its mark; no pitfall records a tap and `onDrag` conflicting.
  - Goes to: task.
  - Resolution: 4.3's Verify drags a tile after a refused drop and after a click.

- **F5. Save Over It from a gallery Apply saves only** (resolved)
  - Plan: D8 offers Save Over It and discard through the gallery's session.
  - Code: the editor's `save(overRev:)` saves without switching, after which the user chooses Apply
    again. The gallery does the same.
  - Goes to: design (stated in D8).

- **F6. A shed tick is not reported** (open, deferred)
  - Plan: a setup that asks for ticks is drawn with them.
  - Code: the helper reports only `unfit`; ticks are shed silently before it (audio-vue's `scene_layers.py` and `cards/base.py`, read above).
  - Goes to: audio-vue, through `handoff-shed-detail.md`; nothing in this change.
  - Resolution: deferred until audio-vue reports shed steps. 5.1 sizes for the reading only.

## Questions for the maintainer

None. The two rulings this change needed (a gallery Apply saves first; a paste lands nearest its
copied cells) were given on 2026-11-24 before it was drafted.

## Confirmed

- `SceneWrites.apply` saves an unsaved draft, a copy included, then switches, and needs no editor:
  `SceneSession.apply` never reads `isEditable`.
- `SceneDrafts.duplicate` hands the draft's content to the copy, so entries in the content carry.
- `writeFailureAlert` takes optional `saveOver` and `discardMine`, so the gallery can pass them.
- `CardSettingsList` gates writes in `edit` and `blockEdit` on `editor.readOnly`, the one place D6
  keeps the check for the cards target.
- `RenderQueue.submit(_:lane:key:)` drops a waiting request when a newer one with the same key
  arrives, which D7's coalescing relies on.
- `PaneFrame.region` is the grid's frame in the pane's space, from the region's own geometry, so D9's
  lines share the parked cards' cells.
- `ColourWell` (`SettingControls.swift`) is the inspector's `NSColorWell` control D9 reuses.
- A 96 × 36 grid gives at most 96 × 36 = 3,456 top-left offsets, as D3 says.
- `SceneRow` opens the scene on a tap of the whole row; a `Button` inside takes its own click first.
- None of audio-vue's open changes touches a spec this change relies on or names ours.
- `SceneContent.removing` widens to whole groups and filters parked cards as well as the layout's,
  which is what Cut removes.
