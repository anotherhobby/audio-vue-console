# Tasks

Built after `card-settings` is built and archived: its `SettingGroup`, controls, Use Default,
colour panel (`HexColour`) and settings on `LayoutCard` are used throughout. Settings order within
a block waits on the same audio-vue answer as card-settings (`x-settings` on `block.<name>`). Run
the core suite with `cd ConsoleCore && xcrun swift test --disable-xctest` (`commands.md`).

## 1. Reconcile with card-settings as built

- [ ] 1.1 Read card-settings' archived specs and the code it left (`SettingGroup`, `LayoutCard`,
  `SceneEditor.set`/`useDefault`, `PlateChanges.drawn`, the inspector), and bring this change's
  design D1, D2, D6, D7 and tasks up to the names it used. Rebase this change's `scene-canvas` and
  `scene-rendering` deltas on the requirement text card-settings archived. Verify with
  `openspec validate scene-settings --strict`.

- [x] 1.2 Write `../audio-vue/scene-settings-handoff.md` (design D7): ask for each rate holding a
  valid calibration for the installed chain (rate, run id, `calibrated` or `stale`), from
  `record.active`, as a route such as `GET /v1/calibration`, and its place in the contract. Say why:
  a scene may capture at any calibrated rate, and the console warns only where none holds. Verify the
  file exists, and record the ask in `working-notes.md`.

## 2. Scene content in the core

- [ ] 2.1 Add `SceneContent` (`layout`, `blocks`) and make it what `SceneEditor` commits and undoes,
  `Draft` keeps (`content`, `laidOut.content`), `SceneDrafts.keep` stores and `LaidOutScene.doc(for:)`
  builds from, writing `grid.cols`/`rows` from the layout and keeping `gap` and every other block
  (design D1). Verify with the full core suite passing unchanged in behaviour, plus
  `LaidOutSceneTests`: the RTA fixture's doc round-trips through `content`; a scene with no `grid`
  block is written with none until its grid changes; and `SceneDraftsTests`: a block changed and
  changed back leaves `isUnsaved` false.
- [ ] 2.2 Add `SceneEditor.setBlock(_:_:to:label:)` and `useDefault(block:key:label:)`, removing an
  emptied block, through `commit` (design D2). Verify with `SceneEditorUndoTests`: move a card, change
  the backdrop, undo twice restores the backdrop then the card; Use Default on the last palette key
  removes `palette`; a read-only editor refuses both.
- [ ] 2.3 Parse every `block.<name>` the `scene` definition names into `SchemaFacts.blocks`
  (`SettingGroup`), with a `.colours(minimum:)` shape for the gradient. Extend
  `Fixtures/schema-trimmed.json` from audio-vue's `json_schema()` with `scene` and the seven blocks.
  Verify with `SchemaFactsTests`: seven blocks; `palette` has 13 colours with defaults; `gradient`
  reads `.colours(minimum: 2)`; `capture_rate` is chain with no default.
- [ ] 2.4 Confirm block settings take card-settings' notes unchanged: measurement off-standard only,
  no note on a chain setting. Verify with `SettingGroupTests`: `rta_weighting` (IEC 61672-1, F, S
  and I) is never flagged; `capture_rate` has no note of its own.

## 3. Backdrop, images and density

- [ ] 3.1 Add `GridDensity.choices(for:)` and `relaid(_:to:minimums:)` and
  `LayoutRefusal.tooSmall(_:)` (design D5). Verify with `GridDensityTests`: 64×36 gives 11 choices,
  rows 18 to 108 by 9; 96×36 gives 31, rows 18 to 108 by 3; a card at column 16, 32 wide, on 64×36
  is at column 24, 48 wide, on 96×54; two grouped cards still tile after 64×36 to 96×54 and back to
  64×36; a card at its minimum refuses a coarser grid naming its kind.
- [ ] 3.2 Add `BackdropSource` reading and writing the `backdrop` block (design D3). Verify with a
  `BackdropSourceTests` suite: a gradient switched to Colour holds its first stop and no gradient; a
  colour switched to Gradient holds `[colour, palette background]`; None with a blur keeps
  `{blur}`; None with nothing else removes the block; angle survives every switch.
- [ ] 3.3 Add `HostClient+Images.swift`: `images(at:token:)` and `upload(_:type:at:token:)`, with
  413, 415 and 422 mapped to `HostFailure` cases that say why (design D4). Verify with
  `HostClientImagesTests` over `FakeTransport`: the list decodes shipped and uploaded images; an
  upload sends the bytes with `image/jpeg` and returns the new id; a 413 reads as too large.
- [ ] 3.4 Draw a backdrop-only change as one request with `plates: []` and `backdrop: true`, any
  other block change as a full redraw, from `SceneRendering.show(_ content:)` (design D6). Verify
  with `SceneRenderingTests`: a gradient change sends one request with no plates; a palette change
  sends one request for everything; a move still sends that plate alone.

## 4. The inspector

- [ ] 4.1 In `AudioVueConsole/Scenes/SceneInspector.swift`, grow `SceneSettingsPanel` into the
  block sections (design D2's order), each from `scenes.facts?.blocks` with card-settings'
  controls; the Backdrop section with its source `Picker(.segmented)`, colour well, gradient stop
  rows (move up, move down, remove disabled at two, Add Stop), angle, Blur, and an image sheet
  listing the host's images by thumbnail with Upload… (`NSOpenPanel`, PNG and JPEG) and the host's
  refusal shown; the Grid section's gap and density `Stepper` with its refusal. Everything disabled
  on a read-only editor. Verify by building the app (`BuildProject` over Xcode MCP) with no new
  warnings and the quality gate clean.
- [ ] 4.2 Draw library tiles from the draft's current document in `SceneEditorView.drawTiles()`,
  and call it after a block change (design D6). Verify with `LibraryTilesTests`: tiles drawn for one
  palette are dropped and drawn again for another; a layout edit draws none.

- [ ] 4.3 Once audio-vue answers task 1.2's handoff and is deployed: add the calibrated-rates read
  to `HostClient` from the regenerated contract, and `CalibrationCoverage` in `ConsoleCore`, giving
  the note for a scene's rate (design D7); show it at the top of the Analysis section. Verify with
  `CalibrationCoverageTests`: a calibrated 96 kHz capture rate has no note; an uncalibrated 44.1 kHz
  one has the note naming 44,100 Hz; an unset capture rate uses the installed rate; a stale record
  counts as holding. Update `host-contract.md`'s Calibration section.

## 5. Integration

- [ ] 5.1 Against the proving host: on a stored scene, switch the backdrop to a three-stop gradient
  at 90°, then upload a JPEG and choose it, then None; change Signal and Title size; set a capture
  rate the host is calibrated at (no warning), one it is not (warned), and clear it; make the grid
  finer and coarser and see a refusal at the coarsest; undo across kinds; Save, re-open (not marked
  unsaved, only changed keys stored) and Apply (the panel shows it). On a built-in, everything shows
  and nothing changes. Record the run in `working-notes.md`.

## Workflow follow-up

- The maintainer's run of the app, then verify and archive the change and sync its specs.
- Before the pull request, review agent-maintained KB updates (`host-contract.md` for images,
  `project-map.md`, `working-notes.md`).
