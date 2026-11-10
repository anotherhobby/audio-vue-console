# Code alignment

## Read

Pass 1, 2026-11-08, on `dev` at `a5b6576`, tree clean. Pass 2, the same day, after the maintainer
answered Q1 and Q2 and ruled out the name Reset (F8): the spec, design D3 to D5 and tasks 2.2, 2.3,
3.3, 4.2 and 5.1 re-read against the reads below. Pass 3, the same day, after the maintainer asked for a full colour
picker: the colour requirement, design D8 and tasks 3.4, 4.2 and 5.1 read against `JSONValue`, the
colour pattern in audio-vue's `check.py` (`#[0-9a-fA-F]{6}`, either case accepted) and the
inspector's `Form`; no new finding. The live run checks the panel's behaviour (D8's risks).

- `ConsoleCore/Sources/ConsoleCore/LaidOutScene.swift`: `init`, `copy`, `doc(for:)`,
  `entry(for:)` (writes cells and group over the kept entry), `card(_:on:id:)`, `cell(_:unset:)`.
- `SceneLayout.swift`: `LayoutCard` (id, kind, cells, group), `SceneLayout.init` checks.
- `SceneEditor.swift`: `select`, `toggle`, `select(touching:adding:)` (all `widened` to whole
  groups), `selectedCards`, `resizableCard`, `preview` (refuses with `.readOnly`), `commit`
  (skips `next == layout`), `registerUndo`, `show`, `replace(with:)`.
- `Draft.swift`: `isUnsaved` (layout equality), `doc`.
- `PlateChanges.swift`: `cells(of:)`, `needed(drawn:for:)`, `between`; callers in
  `SceneRendering.show(_:)` and `take(_:drawnFor:cardIDs:)`, and `PlateChangesTests`.
- `SceneRendering.swift`: `PlacedLayer` (layer, cells), `show(_:)`, `draw(_:plates:through:)`
  (sends `scene.doc(for: layout)`), `take`.
- `AudioVueConsole/Canvas/LayerStack.swift`: `rect(of:scale:cells:)` reads `placed.cells`.
- `JSONValue.swift`: object is a dictionary; decode order null, bool, int, decimal; whole numbers
  decode as integers. Checked with Foundation: `-80.0` decodes as `Int` -80, `Double` -80 encodes
  as `-80`.
- `SchemaFacts.swift`: `init?(schema:)`, its fixture use in `SchemaFactsTests`;
  `Fixtures/schema-trimmed.json` (sorted keys, a schema older than the panel's).
- `PanelScenes.swift`: fetches `/v1/schema` once and keeps `SchemaFacts` only.
- `AudioVueConsole/Scenes/SceneInspector.swift`: one card, several, none; uses `Form`.
- `HostAPI/openapi.json`: `/v1/schema`'s 200 body is `{}`, untyped.
- audio-vue `src/schema/export.py` (`_shape`, `setting`: no step, no order), `declare.py`
  (`Param.step`), `check.py` (`_number` takes int for float; colour `#[0-9a-fA-F]{6}`),
  `scene.py` (`PLACEMENT`'s `plate`, `params`, `alternate`; `ALTERNATE`'s `params`),
  `cards/vu_meter/manifest.py`, `cards/peak_rms/manifest.py`, `cards/rta_bars/manifest.py`; and
  `json_schema()` run whole: 17 cards, 13 with settings, 58 settings (28 number, 16 boolean, 10 enum,
  2 integer, 2 colour), shared keys and their declarations.
- audio-vue specs read in full for what the plan relies on: `settings-schema` (every setting
  declared once; nothing undeclared; class; a scene sets no measured value; standard; one
  validation; export), `settings-store` (one document per scene; stale write refused; validated
  whole; a write leaves the screen as it is), `scene-render` ("A request carries a scene and its
  display"). `openspec list --store audio-vue`: no active changes.
- Our specs: `scene-canvas` (selection, read-only, "Edits are kept until saved or discarded", undo),
  `scene-rendering` ("An edit draws again only what it changed"), `scene-layout` ("Every edit can
  be undone"), `scene-saving` ("An invalid scene names each failure").
- KB: `pitfalls.md` (List crash in the editor; MODIFIED cannot drop a scenario; Foundation's
  decimal-as-integer error; a layout's ids belong to one parse), `open-questions.md` (none held).
- Every task read against the files above. No task removes or renames a symbol; `cells(of:)` is
  kept (F3).

## Findings

- **F1. A whole number written as `.decimal` reads back as `.integer`** (resolved)
  - Plan: design D4 wrote every number setting as `.decimal`, and listed the round-trip as a risk to
    test later.
  - Code: `JSONValue.init(from:)` reads `-80.0` as `.integer(-80)`; Foundation encodes `.decimal(-80)`
    as `-80`. A setting written as `.decimal(-80)` would read back as `.integer(-80)` after a save,
    `LayoutCard` equality would differ, and the saved scene would stay marked unsaved.
  - Goes to: design.
  - Resolution: D4 writes a whole number as `.integer` and a fraction as `.decimal`, the decoder's own
    forms; audio-vue's `_number` accepts an int for a float setting, and the app already sends
    whole floats as integers on every save today. Task 3.3's Verify checks both forms; step rounding
    goes to the step's decimal places.
- **F2. A grouped card cannot be selected alone** (resolved)
  - Plan: the spec shows "the selected card's settings" for one card, and shared settings for
    several.
  - Code: `SceneEditor.select(_:)`, `toggle` and the marquee all widen to whole groups
    (`scene-canvas`, "Clicking a group member"). A card in a group is never the sole selection, so
    its own settings would show only where every card in the group shares them, and a setting only
    it has (a VU's Channel beside a peak meter) could be reached only by ungrouping.
  - Goes to: requirement (the maintainer rules first).
  - Resolution: Q1, ruled as recommended (maintainer, 2026-11-08). The spec adds "Each selected
    card's own settings are reachable": after the shared settings, a collapsed section per selected
    card. Design D3 and D4 (`set`/`useDefault` take the ids), tasks 2.3 and 4.2.
- **F3. `PlateChanges.cells(of:)` has readers that need cells alone** (resolved)
  - Plan: design D6 renamed `cells(of:)` to `drawn(of:)`.
  - Code: `SceneRendering.take` maps drawn cells into `PlacedLayer.cells`, which `LayerStack` reads
    to slide a plate during a move.
  - Goes to: design and task.
  - Resolution: D6 and task 2.4 keep `cells(of:)`, add `drawn(of:)` for `needed`, and give
    `PlacedLayer` the settings it was drawn with.
- **F4. The chain warning on a card's own chain setting** (resolved)
  - Plan: the spec warns on every chain setting that calibration no longer applies, as `product.md`
    rules.
  - Code: the only card chain settings are `vu_meter.channel` (left or right of the measured pair,
    "Which channel the needle reads") and `narrowband.source` (one choice, `calibration`). Neither
    changes which audio the panel captures or what calibration measured; the capture pair and rate,
    which do, are install and scene settings outside this change.
  - Goes to: requirement (the maintainer rules first).
  - Resolution: Q2, ruled as recommended (maintainer, 2026-11-08): no warning. The spec's chain
    requirement becomes "A card's chain setting carries no calibration warning"; design D5 drops
    `.chain`; task 3.3 checks `vu_meter.channel` has no note. The maintainer adds that `narrowband`
    is now a calibration card, not placeable (confirmed in `json_schema()`: `x-placeable` false,
    `x-category` calibration), so it is reached only in the built-in calibration scene, read-only.
    `product.md`'s ruling ("a chain setting warns that calibration no longer applies") now reads
    wider than this; proposed to the maintainer to narrow it to the capture's chain settings.
- **F5. Undo names use the declared label** (resolved)
  - Plan: the spec's scenario named "Undo Change Lamp Hold", title-cased.
  - Code: labels are sentence case ("Lamp hold", "0 VU at (custom)"); title-casing them in the app
    would be guesswork.
  - Goes to: requirement, our new spec only, wording.
  - Resolution: the requirement names the step by the declared label, "Undo Change Lamp hold".
- **F6. Order and step are not in the export** (resolved, waits on audio-vue)
  - Plan: settings in declared order; numbers step by the card's step.
  - Code: `JSONValue.object` drops key order; `export.setting` omits `Param.step`.
  - Goes to: design (D2, D7) and tasks (1.1, 4.1).
  - Resolution: the handoff asks for `x-settings` and `x-step`; task 4.1 reconciles with the answer.
- **F7. `settings-schema`'s "A scene sets no measured value" reads wider than the code** (noted for
  audio-vue)
  - Plan: a card's chain setting (`vu_meter.channel`) can be set in a scene.
  - Code: audio-vue's validation refuses chain settings only in install blocks and a scene's
    `analysis`; card params of any class are accepted. The requirement's text says a scene setting
    "a chain setting" is refused, while its scenarios cover only `analysis:`.
  - Goes to: nothing in this change; mention to audio-vue in the handoff so its spec can say which
    chain settings it means.
- **F8. "Reset" already means the panel's measurement reset** (resolved)
  - Plan: the spec offered a per-setting Reset in the inspector.
  - Code: `SceneEditorView`'s toolbar has Reset (`POST /v1/commands/reset`, `EditorNote.Kind.reset`),
    and `PanelPage` another; the same word in the inspector would read as one action with two
    meanings (maintainer, 2026-11-08).
  - Goes to: requirement, our new spec.
  - Resolution: the inspector's button is Use Default, its undo step "Use Default for <label>", and
    the spec says it is not named Reset. `SceneLayout.unsetting` and `SceneEditor.useDefault` keep
    the word out of the code (design D4, tasks 2.2, 2.3, 4.2).

## Questions for the maintainer

All answered (maintainer, 2026-11-08):

- **Q1 (F2).** A grouped card's own settings: a collapsed section per selected card after the shared
  settings. Agreed.
- **Q2 (F4).** No calibration warning on a card's own chain setting. Agreed.

## Confirmed

- Settings travel only in the scene document: no route sets a value on the running panel
  (`openapi.json` paths), and a scene write leaves the screen as it is until a reload or switch
  (`audio-vue:settings-store`).
- Undo, the unsaved mark, copies, Save and rendering all derive from `SceneLayout`
  (`SceneEditor.commit`, `Draft.isUnsaved`, `Draft.doc`, `LaidOutScene.copy`,
  `SceneRendering.draw`), so settings on `LayoutCard` reach them all (D1).
- `commit` refuses every edit on a read-only editor through `preview`, so the new edits are refused
  there without a check of their own (task 2.3).
- The host validates a scene whole on write and names every failure; `scene-saving` already shows
  them, so the inspector needs no validation beyond its controls.
- The render request carries the scene as the store holds it (`audio-vue:scene-render`), and the
  app sends `scene.doc(for: layout)`, so changed params are drawn.
- Shared-key counts (D3): `floor_db` 4 cards with 3 declarations, `ceiling_db` 3 with 3,
  `show_readout` 3 with 2 (defaults differ); `peak_rms` and `peak_rms_vertical` declare the same 7
  settings identically; `dynamics_gauge` and `peak_rms` share `show_readout` and `show_scale`, whose
  labels differ ("Scale and legend", "Scale and labels").
- `vu_meter` declares channel, alignment, reference_dbfs, lamp_hold_s, show_face, in that order.
- audio-vue has no open change, so nothing can move under the referenced specs.
- Moving params onto `LayoutCard` also eases `pitfalls.md`'s "A layout's card ids belong to one
  parse": settings then travel with the card, not only in `entries`.
