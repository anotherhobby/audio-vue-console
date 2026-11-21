# Tasks

Built on `card-settings` as archived: its `SettingGroup`, controls, Use Default, colour panel
(`HexColour`) and settings on `LayoutCard` are used throughout. Every block declares `x-settings`,
and audio-vue's `card-colours` gives the swatches and elements (design D8). Run the core suite with
`cd ConsoleCore && xcrun swift test --disable-xctest` (`commands.md`).

## 1. Reconcile with card-settings as built

- [x] 1.1 Read card-settings' archived specs and the code it left (`SettingGroup`, `LayoutCard`,
  `SceneEditor.set`/`useDefault`, `PlateChanges.drawn`, the inspector), and bring this change's
  design D1, D2, D6, D7 and tasks up to the names it used. Rebase this change's `scene-canvas` and
  `scene-rendering` deltas on the requirement text card-settings archived. Verify with
  `openspec validate scene-settings --strict`. Done 2026-11-09, with audio-vue's `card-colours`
  folded in (maintainer): the Elements section, the palette by family, and the card-settings delta
  for unset colours (alignment F8 to F12).

- [x] 1.2 Write `../audio-vue/scene-settings-handoff.md` (design D7): ask for each rate holding a
  valid calibration for the installed chain (rate, run id, `calibrated` or `stale`), from
  `record.active`, as a route such as `GET /v1/calibration`, and its place in the contract. Say why:
  a scene may capture at any calibrated rate, and the console warns only where none holds. Verify the
  file exists, and record the ask in `working-notes.md`.

- [x] 1.3 Write `../audio-vue/meter-colours-handoff.md` (design D9): ask for a declaration of
  when a card setting has no effect, with the setting it depends on, the values and a reason, the
  meter's bar colours under the zoned fields and correlation first. Verify the file exists, and
  record the ask in `working-notes.md`.

## 2. Scene content in the core

- [x] 2.1 Add `SceneContent` (`layout`, `blocks`) and make it what `SceneEditor` commits and undoes,
  `Draft` keeps (`content`, `laidOut.content`), `SceneDrafts.keep` stores and `LaidOutScene.doc(for:)`
  builds from, writing `grid.cols`/`rows` from the layout and keeping `gap` and every other block
  (design D1). Verify with the full core suite passing unchanged in behaviour, plus
  `LaidOutSceneTests`: the RTA fixture's doc round-trips through `content`; a scene with no `grid`
  block is written with none until its grid changes; and `SceneDraftsTests`: a block changed and
  changed back leaves `isUnsaved` false.
- [x] 2.2 Add `SceneEditor.setBlock(_:_:to:label:)` and `useDefault(block:key:label:)`, removing an
  emptied block, through `commit` (design D2). Verify with `SceneEditorUndoTests`: move a card, change
  the backdrop, undo twice restores the backdrop then the card; Use Default on the last palette key
  removes `palette`; a read-only editor refuses both.
- [x] 2.3 Parse every `block.<name>` the `scene` definition names into `SchemaFacts.blocks`
  (`SettingGroup`), with a `.colours(minimum:)` shape for the gradient. Refresh
  `Fixtures/schema-trimmed.json` from audio-vue's current `json_schema()`, with `scene`, the eight
  blocks, `x-swatches`, `x-elements` and the cards' `x-element`. Verify with `SchemaFactsTests`:
  eight blocks in the app's order; `palette` has 21 colours with defaults, `track` among them and no
  `grid`; `elements`' `title` is a choice defaulting to `text_muted`; `gradient` reads
  `.colours(minimum: 2)`; `capture_rate` is chain with no default.
- [x] 2.4 Confirm block settings take card-settings' notes unchanged: measurement off-standard only,
  no note on a chain setting. Verify with `SettingGroupTests`: `rta_weighting` (IEC 61672-1, F, S
  and I) is never flagged; `capture_rate` has no note of its own.
- [x] 2.5 Add `SceneColours` (`SchemaFacts.colours`) and `colour(of:in:)`, and
  `SettingDeclaration.element` from `x-element`, compared by `declaresAlike` (design D8). Verify
  with `SceneColoursTests`: `grid_minor` in a scene with no palette or elements is `#6D7485`; with
  `elements: {grid_minor: accent}` it is the default accent; with that and `palette: {accent:
  "#112233"}` it is `#112233`; swatches and elements come in declared order with their families.
  And `SettingGroupTests`: `rta_bars` and `loudness_scope` share `minor_color` but not
  `major_color`.

## 3. Backdrop and images

- [x] 3.1 Withdrawn 2026-11-21: the grid's density left this change for `host-grid`, which removes
  `GridDensity` and its tests.
- [x] 3.2 Add `BackdropSource` reading and writing the `backdrop` block (design D3). Verify with a
  `BackdropSourceTests` suite: a gradient switched to Colour holds its first stop and no gradient; a
  colour switched to Gradient holds `[colour, palette background]`; None removes the
  block, blur and all (alignment F14); the angle is written only with a gradient,
  and `BackdropMemoryTests`: Colour then Gradient brings back three stops at 90°; a chosen image
  comes back with no picker (alignment F13).
- [x] 3.3 Add `HostClient+Images.swift`: `images(at:token:)` and `upload(_:type:at:token:)`, with
  413, 415 and 422 mapped to `HostFailure` cases that say why (design D4). Verify with
  `HostClientImagesTests` over `FakeTransport`: the list decodes shipped and uploaded images; an
  upload sends the bytes with `image/jpeg` and returns the new id; a 413 reads as too large.
- [x] 3.4 Draw a backdrop-only change as one request with `plates: []` and `backdrop: true`, any
  other block change as a full redraw, from `SceneRendering.show(_ content:)` (design D6). Verify
  with `SceneRenderingTests`: a gradient change sends one request with no plates; a palette change
  sends one request for everything; a move still sends that plate alone.

## 4. The inspector

- [x] 4.1 In `AudioVueConsole/Scenes/SceneInspector.swift`, grow `SceneSettingsPanel` into the
  block sections (design D2's order), each from `scenes.facts?.blocks` with card-settings'
  controls; Palette and Elements grouped under family headings, each element's `Picker` showing
  each swatch with a chip in its colour as edited (design D8); the Backdrop section with its source `Picker(.segmented)`, colour well, gradient stop
  rows (move up, move down, remove disabled at two, Add Stop), angle, Blur, and an image sheet
  listing the host's images by thumbnail with Upload… (`NSOpenPanel`, PNG and JPEG) and the host's
  refusal shown; the Grid section's gap (its density stepper, built here, is removed by `host-grid`). Everything disabled
  on a read-only editor. Verify by building the app (`BuildProject` over Xcode MCP) with no new
  warnings and the quality gate clean.
- [x] 4.2 Draw library tiles from the draft's current document in `SceneEditorView.drawTiles()`,
  and call it after a block change (design D6). Verify with `LibraryTilesTests`: tiles drawn for one
  palette are dropped and drawn again for another; a layout edit draws none.

- [x] 4.3 Add `CalibrationCoverage` in `ConsoleCore`, giving the note for a scene's rate from
  `PanelInput.calibrations` (design D7); show it at the top of the Analysis section. Verify with
  `CalibrationCoverageTests`: a calibrated 96 kHz capture rate has no note; an uncalibrated 44.1 kHz
  one has the note naming 44,100 Hz; an unset capture rate uses the installed rate; a stale record
  counts as holding; no calibrations read gives no note.
- [x] 4.4 In `AudioVueConsole/Scenes/CardSettings.swift`, show an unset colour that names an
  element in its resolved colour from the editor's current blocks, captioned "Uses <element>, in
  <swatch>", and commit from the well only when the chosen hex differs from the one shown (design
  D8). Verify by building the app with no new warnings and the gate clean, and with a
  `SettingValues` test: an unset `rta_bars` minor colour's shown colour follows a palette change to
  `line`.

- [x] 4.5 Read audio-vue's answer, `x-unused-when`, into `SettingDeclaration.unusedWhen`, decide in
  `ConsoleCore` whether a setting has no effect across the selected cards, and show such a row
  disabled with the reason, Use Default kept (design D9). Refresh `Fixtures/schema-trimmed.json`.
  Verify with `SettingGroupTests`: a `meter` on `crest_peak` has no effect for `bar_body_color`, one
  on `crest_rms` has; two meters, one of each, are not greyed; a tick leaves only the body unused;
  the RTA's major colour needs both its grid and its labels off. Build the app with no new warnings
  and the gate clean.

## 5. Integration

- [x] 5.1 Against the proving host, paired again: on a stored scene, switch the backdrop to a
  three-stop gradient at 90°, then upload a JPEG and choose it, then Default; change the scene's
  Title colour, Alert, Shadow, Title size and typeface; set a capture rate the host is calibrated
  at (no warning), one it is not (warned), and clear it; on an `rta_bars` card see the unset Grid
  minor colour show the scene's, follow a change to it, then take Tick, then a colour of its own,
  then Use Default; undo across
  kinds; Save, re-open (not marked unsaved, only changed keys stored) and Apply (the panel shows
  it). On a built-in, everything shows and nothing changes. Record the run in `working-notes.md`. Run by the maintainer on 2026-11-21 with
  `host-grid` built, the density step withdrawn with task 3.1: everything as expected.

## 6. Follow audio-vue's scene-styles (2026-11-19)

audio-vue's `scene-styles` replaced what groups 2 and 4 read (alignment F16 to F22). These tasks
rebuild on it; where they differ from a task above, they stand.

- [x] 6.1 Refresh the saved contract (`tools/refresh-contract.sh`), `Fixtures/schema-trimmed.json`
  from audio-vue's `json_schema()` (whole, keeping the tests' `x-categories`) and
  `Fixtures/rta-scene.json` from `scenes/rta.yaml`. Verify the core builds.
- [x] 6.2 Rebuild `SceneColours` on `x-roles` and `x-scales`: roles, scales, `colour(of:in:)`,
  `groups(of:)`, `ungrouped(of:)` (design D8). Read a card's colour as `.roleColour(roles:)` with
  `role` and `ownDefault`, resolved by `drawnColour`; read `x-choice-labels`; read a card's unset
  shadow by `sceneValue`. Verify with `SceneColoursTests`: an unset `grid_minor_color` is
  `#6D7485` and follows the scene's `grid_minor`; set to `track` it is the scene's track; set to
  `#445566` it names no role; `crest_color` unset is `#7AA2FF` and `psr_color` follows `value`; the
  groups are Background, Text, Lines, Signal, Warnings, Stereo phase, with `shadow` ungrouped; a VU
  meter's unset shadow is the scene's. And `SettingGroupTests`: `rta_bars` and `loudness_scope`
  share `grid_minor_color`, not `grid_major_color` or `band1_color`.
- [x] 6.3 Read the scene's own labelled settings into `SchemaFacts.sceneSettings`, and add
  `SceneEditor.setScene` and `useDefault(scene:)` (design D2). Make the tabs Scene, Style and
  Analysis, with the typeface on Style. Verify with `SchemaFactsTests` (seven blocks in order; 24
  colour settings; `type.title` a number from 24 to 75, default 45, `px`; `typeface` with Oxanium's
  label), `SceneSettingsTabTests` and `SceneEditorBlockTests` (the typeface set, left unset and
  undone).
- [x] 6.4 Send `viewing` and the styles a scene names in the render request, with no `fonts` or
  `fallback`; read `viewing` in `PanelScenes` and fetch no fallback image (design D6). Verify with
  `RenderRequestTests` and `PanelScenesTests`, and with the real helper:
  `RENDER_HELPER_LIVE=1 xcrun swift test --disable-xctest --filter LiveHelperTests` draws the RTA
  scene.
- [x] 6.5 In the app: `ColourGroups` in place of the palette and elements views; Colours and Text
  Sizes titled and described; the typeface row; the backdrop's Default; a card's colour as a well
  beside `RoleMenu`, captioned with the role it takes, its colours under one Colours disclosure,
  and its unset shadow showing the scene's. Verify by building the app with no warnings and the
  gate clean.

## 7. The maintainer's review of 2026-11-20

- [x] 7.1 Inspector: drop the name and Kept section; title `glass` Cards and `type` Text; list the
  typeface at the head of Text (`sceneSettings(with:)`). Verify with `SceneSettingsTabTests`.
- [x] 7.2 A number from 0 to 1 as `AmountSlider`. Verify with `SchemaFactsTests`
  (`aNumberFromNoneToAllIsAnAmount`) and the app build.
- [x] 7.3 An unset scene setting shows the panel's: `installSettings`, `installedValue`,
  `PanelScenes.installed`. Verify with `SchemaFactsTests` (`anUnsetDisplaySettingTakesThePanels`)
  and `PanelScenesTests`.
- [x] 7.4 Use Default Gradient: `HostClient.style`, `PanelScenes.defaultBackdrop`,
  `SceneEditor.useDefaultGradient`. Verify with `BackdropSourceTests`.
- [x] 7.5 New Scene: `SceneDrafts.new(on:among:)` on the panel's grid, the
  gallery's toolbar button. Verify with `SceneDraftsTests`.
- [x] 7.6 A scene with no cards asks the helper for nothing and cannot be saved or applied
  (`SceneRendering.draw`, `SceneThumbnails.draw`, `SceneSession.hasCards`). Verify with
  `SceneThumbnailsTests` (`aSceneWithNoCardsIsNotAskedFor`) and `SceneSessionTests`
  (`aSceneWithNoCardsCannotBeSaved`).

- [x] 7.7 Tiles and an empty canvas on the scene's backdrop: `LibraryTiles.backdropMessage`,
  `SceneBackdrop`. Verify with `LibraryTilesTests` (`aSceneWithNoCardsHasItsBackdropAskedForOnce`,
  `aSceneWithCardsLeavesItsBackdropToTheCanvas`).

- [x] 7.8 Follow audio-vue's `scene-editor-settings`: refresh the contract, the render bundle and
  the fixtures; read `x-inherits` (`SettingDeclaration.inherits`, `SchemaFacts.inheritedValue`) in
  place of `sceneValue` and `installedValue`; an unset number with no value shows None, not Mixed.
  Verify with `SchemaFactsTests`, `SceneColoursTests` and the live helper tests.

- [x] 7.9 The editor's banner insets the library and canvas, not the inspector, whose safe area
  it moved as it came and went, leaving the settings stuck scrolled down. Verify by the app
  build; the maintainer's run checks it: apply a scene, then edit it.

- [x] 7.10 Pin the tabs above the settings form (`safeAreaInset`), each tab's settings starting
  at their top. Verify by the app build.

## 8. Drawing ahead (maintainer, 2026-11-20)

- [x] 8.1 `LibraryTiles` keeps a set per settings key and draws one ahead (`prepare`, `Source`).
  Verify with `LibraryTilesTests` (`tilesDrawnAheadAreShownWithNoRequest`,
  `onlyTheLastScenesTilesAreKept`).
- [x] 8.2 The window reads the scenes once paired and calls `SceneStore.drawAhead`; the Scenes
  page reads them again quietly. Verify by the app build; the maintainer's run checks that the
  gallery and a scene's library show at once after a launch left on the Panel page.

- [x] 8.3 Keep thumbnails between launches (`ThumbnailCache`, `SceneThumbnails.restore`,
  `SceneStore.restoreThumbnails`), restored once the scenes are read. Verify with
  `SceneThumbnailsTests` (`aKeptThumbnailIsShownAtTheNextLaunchWithNoRequest`).

## Workflow follow-up

- The maintainer's run of the app, then verify and archive the change and sync its specs.
- Before the pull request, review agent-maintained KB updates (`host-contract.md` for images and
  colours, `project-map.md`, `working-notes.md`).
- Delete `scene-styles-handoff.md` once `styles` is planned from it, and tell the maintainer.
