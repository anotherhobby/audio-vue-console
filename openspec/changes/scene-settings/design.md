# Design

## Context

See `proposal.md` for why. Planned on 2026-11-08 on top of `card-settings` as designed, and
reconciled on 2026-11-09 with it as built and archived (`SettingGroup`, `SettingDeclaration`,
`LayoutCard.settings`, `SceneEditor.set`/`useDefault`, `PlateChanges.drawn`, `HexColour`, the names
its design used) and with audio-vue's `card-colours`. Read on 2026-11-08 and 2026-11-09:

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
  `block.palette` (one colour per swatch, each with a literal default; `grid` is now `track`),
  `block.elements` (one choice per element among the swatch names, defaulting to the element's
  swatch), `block.type` (title, label, value: enums of sizes), `block.analysis` (six settings: four
  measurement, `capture_rate` chain), `block.display` (three). Each block declares `x-settings` in
  order and no label. `SchemaFacts` reads only `block.grid`'s defaults.
- **Colours** (audio-vue `card-colours`). The root's `x-swatches` gives each swatch's family and
  `x-elements` each element's family and default swatch, both in declared order. A card's colour
  setting has no default and names the element it overrides as `x-element`; one key can name
  different elements on different cards (`major_color` is `grid_major` on `rta_bars`, `outline` on
  `loudness_scope`). Today the inspector shows such a setting unset as "Uses the palette" over a
  black well.
- **Calibrated rates.** `input-and-rates` built the read: `HostClient` gives `[CalibratedRate]`
  from `GET /v1/calibration`, and `PanelInput.calibrations` holds each rate's status.
- **The inspector.** `SceneSettingsPanel` shows the name, the grid and where the scene is kept.

## Goals / Non-Goals

**Goals:**

- One undo history and one unsaved test for layout, card settings and scene settings.
- Blocks generated from the schema with card-settings' reader and controls; only the backdrop and
  the grid's density have editors of their own.
- Grid density as a pure, tested function in `ConsoleCore`.
- One colour lookup in `ConsoleCore`, the panel's own (`Card.colour`), used by the Elements section
  and the card inspector alike.

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
order is a fixed list of the eight known blocks (backdrop, palette, elements, glass, type,
analysis, display, grid), then the rest by key, since a block declares no label. Palette and
Elements group their settings by family (D8).

The blocks are shown in tabs, a segmented control under the scene's name (maintainer, 2026-11-09:
one long list was too much to read): Look (Backdrop, Glass, Type), Colours (Palette, Elements),
Analysis (Analysis, Display), Grid, and Other only where the schema declares a block no tab names
(`SceneSettingsTab`, `SchemaFacts.blocks(on:)`). The tab chosen is kept across scenes. Rows are
compact for card and scene settings alike: help on hover, Use Default as a small button beside a
setting the scene sets, and a caption only for an off-standard value, mixed cards, or an unset
colour's element and swatch; a value at its default is plain. The palette is a grid of colour wells
under their families, named beneath; the elements are collapsed families of one-row choices, each
saying how many of its parts the scene changed. Each colour section says what it is under its
title, since names such as Shadow are both a swatch and an element.

`SceneEditor` gains `setBlock(_ block:, _ key:, to:)` and `useDefault(block:key:)`; an emptied block
is removed from `blocks`, as an emptied `params` is (card-settings D1).

### D3. The backdrop editor writes one source

`BackdropSource` in `ConsoleCore` reads a `backdrop` block as `.unset`, `.colour`, `.gradient` or
`.image` and writes it back holding one source. The angle is written only with a gradient, since
audio-vue refuses an angle without one (`src/schema/scene.py`, found on the maintainer's first run,
2026-11-09); the blur stays with any source but None. Switching source is one write of the whole `backdrop`
block through `SceneEditor.switchBackdrop` and `setBackdrop`. `SceneEditor.backdropMemory`
(`BackdropMemory`) keeps what each source last held while the scene is open, so a source chosen
again comes back as it was: the gradient with its stops and angle, the colour, the image. With
nothing remembered, Colour from a gradient takes its first stop, Gradient from a colour takes
`[colour, palette background]`, and Gradient from nothing takes the background twice; Image opens
the picker and changes nothing until an image is chosen. None removes the whole block, blur
included, since the host refuses a backdrop with no source; the Blur row hides under None, and the
remembered blur comes back with the next source. The memory sits beside the selection on the
editor, not in the view, so it outlives the inspector being rebuilt; it is not undone, since it is
only where a switch starts.

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
redraw. Thumbnails already draw from `Draft.doc`. A change to `elements` is any other block, so it
draws everything. The card inspector resolves unset colours from the editor's current blocks, so
it follows a palette or element edit at once.

### D7. The calibration note follows the host's calibrated rates

A scene's rate is its `analysis.capture_rate`, else the installed rate (`install.input.rate`, else
its schema default, as calibration reads it). The Analysis section shows "No calibration holds at
<rate>, so this scene's readings are uncalibrated." where the host reports no calibration at that
rate, and nothing otherwise; a stale record holds, as the panel applies it. The note is computed in
`ConsoleCore` (`CalibrationCoverage`, from the scene's rate and `PanelInput.calibrations`), not from
the setting's class: card-settings' rule of no note on a chain setting stands, and the warning is
about the scene's readings, not a setting. Before the host's calibrations are read, no note is
shown.

### D8. One colour lookup, `SceneColours`

`SchemaFacts.colours` is a `SceneColours` in `ConsoleCore`, read from `x-swatches`, `x-elements`,
`block.palette` and `block.elements`: each swatch's name, family, label and default, and each
element's name, family, label and default swatch, in declared order. It resolves as the panel does
(audio-vue `Card.colour`): `colour(of element:, in blocks:)` is the swatch `blocks["elements"]`
points the element at, else its default swatch, then that swatch's colour in `blocks["palette"]`,
else its default, as `HexColour`. No rule is copied: every name and default is read.

`SettingDeclaration` gains `element: String?` from `x-element`, and `declaresAlike` compares it, so
cards selected together share a colour setting only where it overrides the same element. Within
one scene every card sharing it then resolves the same colour.

The card inspector shows an unset colour with an element in its resolved colour, captioned "Uses
<element label>, in <swatch label>". The colour well commits only when the chosen hex differs from
the one shown, so opening the panel on an unset colour sets nothing. A colour declaring neither a
default nor an element says "Unset".

The Elements section is each element's choice as a `Picker`, each swatch labelled with a chip in its
colour in this scene as edited. Palette and Elements group their rows under family headings, in
declared order (`x-swatches`, `x-elements`). Status elements are included: a scene may set them,
only a card may not (audio-vue `card-colours`).

Alternative: a render-helper call reporting effective colours. A round trip for each inspector
redraw, and a second path to the same answer the export now gives by lookup.

### D9. A setting with no effect is greyed out with the host's reason

The meter's `bar_body_color` and `bar_tip_color` change nothing for a field coloured by zone or by
phase, which the export did not say (maintainer, 2026-11-09). The rule is audio-vue's
(`src/cards/fields.py`), so the console copies no list of fields. audio-vue answered
`meter-colours-handoff.md` with `x-unused-when` (its `unused-settings`, archived and deployed
2026-11-09): a list of cases, each `{when: {setting: [values]}, reason}`. The setting has no effect
where any case matches, and a case matches where every setting it names holds one of its values.
`SettingDeclaration.unusedWhen` reads it; `unusedReason(in:declaredBy:)` matches on each named
setting as the card holds it, set or else its default, and gives the first declared case's reason,
so a zoned field in the tick style says its thresholds. Across selected cards the setting is greyed
only where every card matches a case (`SettingGroup.unusedReason`), giving the first card's reason.
The row's control is then disabled with the reason as its caption, and Use Default stays where the
scene sets it. The declaration also covers `vu_meter`'s custom reference and `rta_bars`' grid
lines, whose major pair needs the major grid and the labels both off.

## Risks / Trade-offs

- [`SceneContent` touches every user of `Draft.layout` and `SceneEditor.layout`] → the layout stays
  reachable as `content.layout`; the change is mechanical, done in one task with the full suite.
- [Element labels name what cards draw, such as Grid minor, not how a given card words it] → the
  card's own setting keeps its label (Minor line colour); only the caption names the element.
- [Grid density on scenes with unset spans] → `LaidOutScene` already fills unset spans and offsets
  from the grid, and writes them back explicitly, so density works on resolved cells.
