# Code alignment

## Read

Pass 1, 2026-11-23.

**This repository:**
- `ConsoleCore/Sources/ConsoleCore/SchemaFacts.swift`, `init?(schema:)`: built once per host from
  `/v1/schema`; keeps settings, blocks and colours, not the raw `$defs`.
- `ConsoleCore/Sources/ConsoleCore/PanelScenes.swift`:
  - `facts` is held here, read at line 78;
  - rename (around line 247) writes the host's document with `dropGridSize` applied.
- `ConsoleCore/Sources/ConsoleCore/LaidOutScene.swift`:
  - `init`: `ids` are used only when their count equals the cards read;
  - `content` and `dropGridSize`: blocks are every root key but `cards` and `name`;
  - `declaresGridSize`;
  - `doc(for:)`: writes `content.blocks`, then each entry with cells, group and `params` replaced;
  - `entry(for:)`: `plate`, `alternate` and unknown keys pass through from `entries`.
- `ConsoleCore/Sources/ConsoleCore/SceneContent.swift`, `blocks(of:)`.
- `ConsoleCore/Sources/ConsoleCore/Draft.swift`:
  - `init`, `isUnsaved` (counts `declaresGridSize`) and `doc`.
- `ConsoleCore/Sources/ConsoleCore/SceneDrafts.swift`:
  - `draft(for:panel:)`, `load`, `revert`, `duplicate`, `saved` and `reread`;
  - `relay` and `relaid`: these rebuild a `Draft`, carrying `source` by hand;
  - in all, `Draft(` is made at seven sites.
- `ConsoleCore/Sources/ConsoleCore/SceneSession.swift`:
  - `load`, `revert` and `newParse`: `newParse` replaces the editor's content, which resets undo.
- `ConsoleCore/Sources/ConsoleCore/SceneRendering.swift`, lines 174, 223 and 229, and
  `SceneThumbnails.swift`, line 70: both render `scene.doc(for: content)`.
- `ConsoleCore/Sources/ConsoleCore/SceneRendering+Messages.swift`, `.refused`: the canvas line
  "The panel would refuse this scene: …".
- `ConsoleCore/Sources/ConsoleCore/SceneSettingsTab.swift`: the Other tab holds the schema's
  undeclared-by-tab blocks and declared scene settings only.
- `AudioVueConsole/Scenes/SceneEditorView.swift`: `banner` and the `EditorBanner` placement.
- `AudioVueConsole/Scenes/EditorBanner.swift`: text only, with no action.
- `AudioVueConsole/Canvas/SceneCanvas.swift`, `footerLine`.
- `AudioVueConsole/Scenes/SceneGallery.swift`, line 164: the too-wide note.
- `ConsoleCore/Tests/ConsoleCoreTests/LaidOutSceneTests.swift`, lines 150–164: the grid-size test.

**The schema export** (`Fixtures/schema-trimmed.json`, refreshed 2026-11-23):
- keyword counts;
- `scene`, `placement` and `alternate` are closed;
- `block.grid` declares `gap` alone;
- `cards` has `minItems: 1`;
- a placement's `card` is an `enum` of names;
- `rta_bars` `hold_s` has a maximum of 10;
- `release` offers `drop` and `fall`;
- `backdrop.gradient` has `minItems: 2`.

**audio-vue:**
- `settings-schema`: "Nothing is accepted that is not declared", "One validation reports every
  failure", "The panel loads only what validation passes" and "The declarations export as JSON
  Schema".
- `scene-render`: "A request carries a scene and its display".
- `settings-store`: "A stale write is refused" and "A write is validated whole before it is
  stored".
- `scene-grid`: "`grid:` holds the layout grid and nothing else" (requirement titles), and "The
  panel starts on default in place of a refused scene".
- `src/scene_model.py`, line 400: loading raises on validation failures.
- Open changes: `rta-spectrogram` (deltas read) and `rta-fine-bands` (no deltas yet).

**KB:** `pitfalls.md` (the keyed block's per-key schema) and `open-questions.md` (nothing on this
code).

**Removals searched:**
- `declaresGridSize` and `dropGridSize` across `ConsoleCore/`, `AudioVueConsole/` and the KB. The
  hits are `Draft.swift`, `LaidOutScene.swift`, `PanelScenes.swift` and `LaidOutSceneTests.swift`,
  all assigned to task 2.1 or 2.2.

Pass 2, 2026-11-23, during apply:
- `SceneWrites` and the app's `SceneStore` own the drafts, not `PanelScenes`. See F8.
- `SceneDrafts.revert` keyed a new parse on `source != rev` alone. See F9.
- `SceneSettings.title` and its `titles` table (app target), and the three copies of the card-name
  rule (`CardLibrary`, `SceneInspector`, `SceneRendering+Messages`), are now in `SceneSettingsTab`.
  The repair's wording needs them from `ConsoleCore`.

## Findings

- **F1. A stored repair would need the schema at seven construction sites** (resolved)
  - Plan: design D4 and task 2.2 stored the repair on `Draft` at each parse.
  - Code: `Draft(` is made at seven sites in `SceneDrafts`, none of which holds `SchemaFacts`. Only
    `PanelScenes` holds both the facts and the drafts.
  - Goes to: design and task.
  - Resolution: the repair is computed on demand by `PanelScenes.repair(of:)` (design D4, task
    2.4), and task 4.1 times it.
- **F2. `relaid` would drop the repaired flag** (resolved)
  - Plan: design D5 set `Draft.repaired` at repair.
  - Code: `SceneDrafts.relaid` builds a new `Draft` on a panel change and carries only `source` by
    hand.
  - Goes to: design and task.
  - Resolution: `relaid` carries `repaired` (design D5, task 2.2).
- **F3. Card ids by position need the removed cards' indices** (resolved)
  - Plan: surviving cards keep their ids.
  - Code: `LaidOutScene.init` takes `ids` only when the count matches the cards read.
  - Goes to: design and task.
  - Resolution: `removedCard` carries its index, and `repair(_:with:)` passes the survivors' ids
    (design D3 and D5, task 2.3).
- **F4. Rename is refused while the host's document needs a repair** (resolved, Q2)
  - Plan: design D7, saving not blocked.
  - Code: rename in `PanelScenes` writes the host's current document. It dropped the grid size
    for exactly this case, and task 2.1 removes that.
  - Goes to: design.
  - Resolution: maintainer, 2026-11-23, took the recommendation. A rename is refused by the host
    with its failures until the repair is saved (design D7).
- **F5. Repair is not on the editor's undo history** (resolved, Q1)
  - Plan: the first proposal in chat had "one undoable edit".
  - Code: `plate`, `alternate` and unknown entry keys live in `LaidOutScene.entries`, outside
    `SceneContent`, which is all undo covers. `newParse()` resets the editor.
  - Goes to: requirement. `scene-repair`'s "Repair makes the listed changes as one unsaved edit"
    names Revert to Saved as the way back, not Undo.
  - Resolution: maintainer, 2026-11-23, took the recommendation. Repair starts the undo history
    afresh, and Revert to Saved is the way back (design D5).
- **F6. A scene stored with a grid size is no longer drawn before it is repaired** (resolved, Q3)
  - Plan: design D6 folds the grid size into the repair.
  - Code: today `LaidOutScene.content` drops `cols` and `rows`, so the helper never sees them and
    draws the scene, which opens unsaved. Once they are kept, the helper refuses the scene until it
    is repaired.
  - Goes to: requirement. `scene-saving`, "A saved scene declares no grid size", is modified and
    departs from the 2026-11-21 ruling that such a scene is opened and resaved.
  - Resolution: maintainer, 2026-11-23, took the recommendation. The grid size is repaired as any
    undeclared key is, which replaces the 2026-11-21 ruling (design D6).
- **F7. audio-vue's open `rta-spectrogram` has a delta to `scene-render`** (resolved)
  - Plan: relies on `scene-render`, "A request carries a scene and its display".
  - Code: the delta adds "The frame carries the cards' band-level histories" and "A run serves a
    scene asking fewer histories" only, and modifies nothing relied on.
  - Goes to: none.
  - Resolution: recorded. `rta-fine-bands` has no deltas yet. Its new `bands` choices reach the
    repair only as the schema's choices.

- **F8. The drafts are not `PanelScenes`'** (resolved)
  - Plan: design D4 put `repair(of:)` on `PanelScenes`, "the one place that holds both".
  - Code: `PanelScenes` holds the facts. `SceneWrites` (`scenes` and `drafts`) and the app's
    `SceneStore` hold the drafts.
  - Goes to: design and task.
  - Resolution: `SceneDrafts.repair(of:shape:)`, with `SceneWrites.repair(of:)` for the session
    (design D4, task 2.4).
- **F9. Revert after a repair stayed on the repaired parse** (resolved)
  - Plan: design D5, Revert to Saved reads the host's document again.
  - Code: `SceneDrafts.revert` took the same-parse path whenever `source == rev`, which a repair
    keeps.
  - Goes to: task.
  - Resolution: `revert` also takes a new parse for a repaired draft, tested in
    `SceneRepairDraftTests`.

- **F10. A gallery pass took over a millisecond** (resolved)
  - Plan: task 4.1 allowed a millisecond per pass before holding repairs.
  - Code: `LiveRepairTests` measured 7.4 ms cold in debug and 1.6 ms warm in release.
    Recording-based conformance, skipping structural walks for schemas without object or array
    keywords, and not copying each node in `resolved` brought release to 1.2 ms.
  - Goes to: design.
  - Resolution: `SceneDrafts` holds each scene's repair by checked document and shape identity
    (design D4), and the held pass is about 2 µs. `aHeldRepairFollowsAnEdit` shows the held repair
    follows an edit.

## Questions for the maintainer

All three were answered on 2026-11-23: the maintainer took each recommendation.


- **Q1 (F5): Undo or Revert?** Recommended: Repair starts the undo history afresh, as loading an
  earlier version does, and Revert to Saved is the way back. Making it undoable means moving each
  card's whole entry into the editor's content, which is a larger change than the repair.
- **Q2 (F4): Rename before saving a repair.** Recommended: let the host refuse it, showing its
  failures as for any invalid write. The note says to save the repair first. The alternative,
  writing the repaired document on rename, stores a repair under the name of a rename.
- **Q3 (F6): The grid size asks too.** Recommended: yes, one rule for every undeclared key. This
  replaces the 2026-11-21 ruling that a scene with a grid size opens unsaved and drawn without it.
  The alternative keeps that special case beside the repair.

## Confirmed

- The inspector never shows an undeclared key. Its tabs read the schema's blocks and declared scene
  settings (`SceneSettingsTab`), so a stale key is visible only in the repair's list.
- The canvas and the thumbnails render `doc(for: content)`, so a repaired draft is drawn as it
  would be saved.
- Every object a scene holds is closed in the export (`additionalProperties: false`), so "undeclared
  at any depth" is decidable from the export alone.
- The design's numbers match the export:
  - `rta_bars` `hold_s` has a maximum of 10;
  - `release` offers `drop` and `fall`;
  - `cards` has `minItems: 1`;
  - `gradient` has `minItems: 2`;
  - `grid` declares `gap` alone.
- The panel refuses an invalid stored scene. audio-vue's `scene_model.py` raises on validation
  failures, and `settings-schema` says "The panel loads only what validation passes". So marking
  every scene in the gallery is warranted.
- `SceneDrafts.load` with `SceneSession.newParse` is a working precedent for applying a new parse as
  an unsaved edit.
