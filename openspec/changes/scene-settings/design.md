# Design

## Context

See `proposal.md` for why. This change is planned on top of `card-settings` as designed (not yet
built); "after card-settings" below means the code that change's design leaves. Read on 2026-11-08:

- **The undoable state is a `SceneLayout`.** `SceneEditor.layout`, `commit`, `registerUndo` and
  `show` deal in layouts; `onCommit` hands each to `SceneDrafts.keep(_:for:)`, which sets
  `Draft.layout`. `Draft.isUnsaved` compares it with `laidOut.layout`; `Draft.doc` is
  `laidOut.doc(for: layout)` plus the name. After card-settings, each `LayoutCard` carries its
  settings, so card settings ride in the layout.
- **Scene blocks pass through.** `LaidOutScene.doc(for:)` takes the parse's whole `doc` and replaces
  only `cards`. `grid` is read into `SceneLayout.grid` (a `let`), and nothing writes it back, so a
  scene whose grid is unset is written with none.
- **Rendering.** `SceneRendering.show(_ layout:)` redraws by `PlateChanges` and `draw(_:plates:)`
  sends `scene.doc(for: layout)`; `plates: nil` draws the backdrop and every plate. A request may name
  its plates; no request draws the backdrop alone today.
- **Library tiles.** `LibraryTiles` keys tiles on the scene's doc without `cards` and `name`, and
  `SceneEditorView.drawTiles()` draws them from the parse's `laidOut`, not from the draft's current
  document.
- **Images.** `HostClient.image(_:at:token:)` fetches one; `ImageStore` caches fetched images for the
  helper. The contract's `GET /v1/images` gives `Images.images`, each `Image` with `id`, `shipped`,
  `format`, `bytes`, `width`, `height`, `added_at`; `POST /v1/images` takes the raw bytes as
  `image/png` or `image/jpeg` and answers 201, 413 (too large), 415 (not PNG or JPEG) or 422.
- **The schema's blocks.** `block.grid` (cols, rows, gap), `block.glass` (opacity, radius),
  `block.backdrop` (color, gradient as an array of colours with `minItems` 2, angle, image, blur),
  `block.palette` (13 colours, each with a default), `block.type` (title, label, value: enums of
  sizes), `block.analysis` (six settings: four measurement, `capture_rate` chain), `block.display`
  (three). `SchemaFacts` reads only `block.grid`'s defaults.
- **The inspector.** `SceneSettingsPanel` shows the name, the grid and where the scene is kept.

## Goals / Non-Goals

**Goals:**

- One undo history and one unsaved test for layout, card settings and scene settings.
- Blocks generated from the schema with card-settings' reader and controls; only the backdrop and
  the grid's density have editors of their own.
- Grid density as a pure, tested function in `ConsoleCore`.

**Non-Goals:**

- Styles, which the `styles` change adds over these blocks.
- Deleting images from the host, or managing them outside the backdrop picker.
- A grid of another aspect.

## Decisions

### D1. The editor's state is a `SceneContent`

A new value, `SceneContent { layout: SceneLayout, blocks: [String: JSONValue] }`, replaces
`SceneLayout` as what `SceneEditor` commits, undoes and hands to `onCommit`, and what `Draft` keeps
(`Draft.content`, `laidOut.content`). `blocks` holds the doc's top-level keys other than `cards`
and `name`, `grid` included; the grid's `cols` and `rows` are written from `layout.grid` when a
document is built, and `gap` stays in `blocks`. `LaidOutScene.doc(for:)` takes a `SceneContent`.

The layout operations keep their `SceneLayout` signatures; `SceneEditor` wraps them
(`content.with(layout:)`). `isUnsaved` and the no-op check compare contents, so a block changed and
changed back clears the unsaved mark.

Why: one undo stack, and a density change, which moves cards and changes the grid together, is one
step. Alternative: a second store and undo manager for blocks. Undo order across the two would be
lost, and the spec's "Undoing across kinds of edit" fails.

### D2. Blocks are read with card-settings' reader

`SchemaFacts` reads every `block.<name>` the `scene` definition refers to into card-settings'
`SettingGroup`, the type it reads a card's declarations into (`SchemaFacts.blocks`). The
gradient's `type: array` of colours reads as a new shape, `.colours(minimum:)`. The app's section
order is a fixed list of the seven known blocks, then the rest by label.

`SceneEditor` gains `setBlock(_ block:, _ key:, to:)` and `useDefault(block:key:)`; an emptied block
is removed from `blocks`, as an emptied `params` is (card-settings D1).

### D3. The backdrop editor writes one source

`BackdropSource` in `ConsoleCore` reads a `backdrop` block as `.none`, `.colour`, `.gradient` or
`.image` (with angle and blur kept apart) and writes it back holding one source. Switching source is
one `setBlock` of the whole `backdrop` block: to Colour from a gradient takes its first stop, to
Gradient from a colour takes `[colour, palette background]`, to Image opens the picker and changes
nothing until an image is chosen. None removes `color`, `gradient` and `image`; if `angle` and
`blur` remain, the block stays with them.

The stop list is a `List`-free `VStack` of rows in the inspector's `Form` (`pitfalls.md`, the List
crash in the editor): a colour well per stop (the system panel, card-settings D8), move up and down
buttons, a remove button disabled at two stops, and Add Stop. Each is one step.

### D4. Images are listed and uploaded through `HostClient`

`HostClient+Images.swift` adds `images(at:token:)` (`GET /v1/images`, giving `HostImage`: id,
shipped, size, pixel width and height, added date) and `upload(_ data:, type:, at:token:)`
(`POST /v1/images`, mapping 413 and 415 and 422 to `HostFailure` cases naming the reason). The
picker is a sheet of thumbnails fetched through `ImageStore`, shipped images first, then uploaded,
newest first, with Upload… opening an `NSOpenPanel` for PNG and JPEG. The app sends the file's bytes
untouched.

### D5. Density is a pure function

`GridDensity` in `ConsoleCore`:

- `choices(for grid:)`: reduce `cols:rows` by their greatest common divisor to `a:b`, then every
  `k·a × k·b` with `18 ≤ k·b ≤ 108`, the current grid among them. 64×36 (16:9) gives rows 18, 27, 36,
  ... 108, 11 choices; 96×36 (8:3) gives every multiple of 3 from 18 to 108, 31 choices.
- `relaid(_ layout:, to grid:, minimums:)`: each card's left and right edges scaled by
  `newCols / oldCols` and rounded half up, likewise top and bottom by rows, so a shared edge maps to
  the same cell, no two cards overlap that did not, and groups still tile. Refused with a new
  `LayoutRefusal.tooSmall(kind)` where a card's new size is under its minimum scaled to the new rows
  (`SchemaFacts.minimums(forRows:)`), or a span rounds to zero.

The Grid section shows the density as a `Stepper` labelled with the grid ("96 × 54 cells"), Finer
and Coarser walking the choices in order, every choice reachable; a refused step leaves the grid and
shows the refusal under it. A stepper rather than a menu, since 31 entries make a poor menu.

### D6. Redraws follow what changed

`SceneRendering.show(_ content:)` compares the new content's blocks with what it drew: only
`backdrop` changed → one request with `plates: []` and `backdrop: true`, which the helper answers
with the backdrop alone (audio-vue `scene-render`, "A request may name its plates";
`scene_layers.render` takes an empty `chosen` as none); any other block changed → `plates: nil`,
everything. Plates still follow `PlateChanges` for layout edits. `RenderRequest` already carries
`plates` and `backdrop`.

`SceneEditorView.drawTiles()` draws from the draft's current document instead of the parse, so
`LibraryTiles`' existing key (the doc without cards and name) changes when a block does, and tiles
redraw. Thumbnails already draw from `Draft.doc`.

### D7. The calibration note follows the host's calibrated rates

A scene's rate is its `analysis.capture_rate`, else the installed rate (`install.input.rate`, else
its schema default, as calibration reads it). The Analysis section shows "No calibration holds at
<rate>, so this scene's readings are uncalibrated." where the host reports no valid calibration at
that rate, and nothing otherwise. The note is computed in `ConsoleCore` (`CalibrationCoverage`,
from the scene's rate and the host's calibrated rates), not from the setting's class: card-settings'
rule of no note on a chain setting stands, and the warning is about the scene's readings, not a
setting.

The host gives `state.sections.calibration` for the rate it runs only, and `GET /v1/runs` gives no
rate. `scene-settings-handoff.md` asks audio-vue to report, for the installed chain, each rate with
a valid record: the rate, the run id and the status (`calibrated` or `stale`, as `calibration_status`
words them), from the same `record.active` the panel uses, for example as `GET /v1/calibration`.
Until it answers, the note is not shown (task 4.3 waits); nothing else in this change waits on it.

## Risks / Trade-offs

- [`SceneContent` touches every user of `Draft.layout` and `SceneEditor.layout`] → the layout stays
  reachable as `content.layout`; the change is mechanical, done in one task with the full suite.
- [Grid density on scenes with unset spans] → `LaidOutScene` already fills unset spans and offsets
  from the grid, and writes them back explicitly, so density works on resolved cells.
