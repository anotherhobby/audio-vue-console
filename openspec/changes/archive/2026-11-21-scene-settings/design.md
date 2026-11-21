# Design

## Context

See `proposal.md` for why. Planned on 2026-11-08 on top of `card-settings` as designed, and
reconciled on 2026-11-09 with it as built and archived (`SettingGroup`, `SettingDeclaration`,
`LayoutCard.settings`, `SceneEditor.set`/`useDefault`, `PlateChanges.drawn`, `HexColour`, the names
its design used) and with audio-vue's `card-colours`. Reconciled again on 2026-11-19 with
audio-vue's `scene-styles` as deployed, which replaced the palette, the elements and the named
sizes (alignment F16 to F22); D2, D3, D6 and D8 below are as rebuilt. Read on 2026-11-08 and
2026-11-09, with the 2026-11-19 state after:

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
  `block.analysis` (six settings: four measurement, `capture_rate` chain), `block.display` (three).
  Each block declares `x-settings` in order and no label. `SchemaFacts` reads only `block.grid`'s
  defaults. The colour and type blocks read then are replaced; see the 2026-11-19 state below.
- **Calibrated rates.** `input-and-rates` built the read: `HostClient` gives `[CalibratedRate]`
  from `GET /v1/calibration`, and `PanelInput.calibrations` holds each rate's status.
- **The inspector.** `SceneSettingsPanel` shows the name, the grid and where the scene is kept.
- **As of 2026-11-19** (audio-vue `scene-styles`). The scene's blocks are `grid`, `glass`,
  `backdrop`, `colors`, `type`, `analysis` and `display`; `palette` and `elements` are gone.
  `block.colors` holds a colour per role and per scale step and `shadow`, a number; `block.type` a
  number per text role, unit `px`, no step. `scene` also declares `typeface`, a labelled choice
  with `x-choice-labels`, and `styles`, a list with no label. The root lists `x-roles` (`id`,
  `group`, `default`, `help`) and `x-scales` (`id`, `label`, `steps`). A card's colour setting is
  `anyOf` an `enum` of role ids and the colour pattern, with `x-role`, or `x-own: {default}` for a
  colour of the card's own; a card's `shadow` is a number with no default. The render request
  takes `viewing` and `styles` and no `fonts` or `fallback`, and its answer adds `style_notice`.

## Goals / Non-Goals

**Goals:**

- One undo history and one unsaved test for layout, card settings and scene settings.
- Blocks generated from the schema with card-settings' reader and controls; only the backdrop has
  an editor of its own.
- One colour lookup in `ConsoleCore`, the panel's own, used by the card inspector.

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

Why: one undo stack, and an edit that moves cards and changes a setting together is one
step. Alternative: a second store and undo manager for blocks. Undo order across the two would be
lost, and the spec's "Undoing across kinds of edit" fails.

### D2. Blocks are read with card-settings' reader

`SchemaFacts` reads every `block.<name>` the `scene` definition refers to into card-settings'
`SettingGroup`, the type it reads a card's declarations into (`SchemaFacts.blocks`). The
gradient's `type: array` of colours reads as a new shape, `.colours(minimum:)`. The app's section
order is a fixed list of the seven known blocks (backdrop, glass, grid, display, colors, type,
analysis), then the rest by key, since a block declares no label. The scene's own labelled
properties, its typeface today, are read the same way into `SchemaFacts.sceneSettings`; `styles`
carries no label and is the `styles` change's. A choice's names come from `x-choice-labels`
(`SettingDeclaration.label(of:)`).

The blocks are shown in tabs, a segmented control pinned above the settings, which scroll under
it and start at their top on each tab (maintainer, 2026-11-20), at the inspector's head (maintainer, 2026-11-09:
one long list was too much to read; 2026-11-19: Scene, Style, Analysis; 2026-11-20: no name or
Kept row above them, which the title and the gallery already say): Scene (Backdrop, Cards, Grid,
Display), Style (Colours, then Text), Analysis, and Other only where the schema declares a block
or a scene setting no tab names (`SceneSettingsTab`, `SchemaFacts.blocks(on:)`,
`sceneSettings(on:)`). A scene's own setting the app knows is listed at the head of a block's
section (`SceneSettingsTab.settingBlocks`, `sceneSettings(with:)`): the typeface heads Text. The tab chosen is kept across scenes. Rows are
compact for card and scene settings alike: help on hover, Use Default as a small button beside a
setting the scene sets, and a caption only for an off-standard value, mixed cards, or the scene's
colour or value a card's setting takes; a value at its default is plain. Colours is a grid of
colour wells under their groups and scales, named beneath (D8). Colours, Text and Cards are titled
by the app, since `colors`, `type` and `glass` do not read as titles, and the first two say what
they are under their titles.

**Drawing ahead (maintainer, 2026-11-20).** `PanelWindow` makes and reads the panel's
`PanelScenes` as soon as it is paired, beside the helper's start, and keeps it in `SceneStore`;
`SceneStore.drawAhead` then draws the thumbnails and `LibraryTiles.prepare` each scene's tiles and
backdrop, in the thumbnails' lane so an open scene's drawing goes first. `LibraryTiles` keeps a
set of tiles per settings key, the `kept` drawn last, in place of one set dropped at each change.
The Scenes page reads the scenes again when shown, the gallery staying up meanwhile
(`PanelScenes.load` once loaded). The helper's first
drawing after a start takes two to three seconds (measured 2026-11-20: 2.7 s, then 0.03 s a
plate), which the maintainer beat to the gallery, so thumbnails drawn by the panel's code are also
kept on disk (`ThumbnailCache`, in the app's caches), each filed under a digest of its render
request and the panel's card code, and `SceneThumbnails.restore` shows them as soon as the scenes
are read; a changed scene, viewing, style or code finds no file and is drawn again. Rejected:
drawing each scene's canvas layers ahead, which holds
a display-sized image per plate per scene for a first draw that is already quick.

**The maintainer's review, 2026-11-20.** A number bounded 0 to 1 is an amount and takes a slider
(`SettingDeclaration.isAmount`, `AmountSlider`), written once as the drag ends. A setting
that declares `x-inherits` shows, while unset, the setting of the same key in the block it names,
the install's as stored or the scene's as edited, else that setting's default
(`SettingDeclaration.inherits`, `SchemaFacts.inheritedValue`, `installSettings`,
`PanelScenes.installed`): a scene's display timeouts and screensaver take the install's, a card's
shadow the scene's colours'. audio-vue declared the keyword the same day, in place of the app's
first match by block name, key and shape. `PanelScenes`
reads the built-in `default` style for its backdrop, which Use Default Gradient writes
(`BackdropSource.gradient(of:over:)`). New Scene makes an empty copy on the panel's grid; rejected: a starter card, since the maintainer asked
for none. The host holds no scene without a card, so an empty one is the app's alone, like a new
document (maintainer, 2026-11-20): `SceneRendering` and `SceneThumbnails` ask the helper for
nothing while it has no cards, and `SceneSession.hasCards` gates Save and Apply. Rejected: asking
audio-vue to store and draw an empty scene, which nothing but this moment needs. Its backdrop is
real all the same: `LibraryTiles`, which already draws each tile as the scene's settings around
one card, asks once for the backdrop alone the same way (`backdropMessage`), and the empty canvas
and every tile's surround show it (`SceneBackdrop`) in place of the app's stand-in gradient.

`SceneEditor` gains `setBlock(_ block:, _ key:, to:)` and `useDefault(block:key:)`; an emptied block
is removed from `blocks`, as an emptied `params` is (card-settings D1). `setScene(_ key:, to:)` and
`useDefault(scene:)` write a scene's own setting, a top-level key of `blocks`.

### D3. The backdrop editor writes one source

`BackdropSource` in `ConsoleCore` reads a `backdrop` block as `.unset`, `.colour`, `.gradient` or
`.image` and writes it back holding one source. The angle is written only with a gradient, since
audio-vue refuses an angle without one (`src/schema/scene.py`, found on the maintainer's first run,
2026-11-09); the blur stays with any source but None. Switching source is one write of the whole `backdrop`
block through `SceneEditor.switchBackdrop` and `setBackdrop`. `SceneEditor.backdropMemory`
(`BackdropMemory`) keeps what each source last held while the scene is open, so a source chosen
again comes back as it was: the gradient with its stops and angle, the colour, the image. With
nothing remembered, Colour from a gradient takes its first stop, Gradient from a colour takes
`[colour, the scene's card colour]`, and Gradient from nothing takes the card colour twice; Image
opens the picker and changes nothing until an image is chosen. The source with no block is offered
as Default, since a scene with no backdrop draws the default style's gradient (audio-vue
`scene-backdrop`, 2026-11-19): it removes the whole block, blur included, since the host refuses a
backdrop with no source; the Blur row hides under Default, and the remembered blur comes back with
the next source. The memory sits beside the selection on the
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

### D5. Withdrawn

Grid density left this change on 2026-11-21 (`host-grid`: the grid is the panel's). The code built
for it is removed there.

### D6. Redraws follow what changed

`SceneRendering.show(_ content:)` compares the new content's blocks with what it drew: only
`backdrop` changed → one request with `plates: []` and `backdrop: true`, which the helper answers
with the backdrop alone (audio-vue `scene-render`, "A request may name its plates";
`scene_layers.render` takes an empty `chosen` as none); any other block changed → `plates: nil`,
everything. Plates still follow `PlateChanges` for layout edits. `RenderRequest` already carries
`plates` and `backdrop`.

`SceneEditorView.drawTiles()` draws from the draft's current document instead of the parse, so
`LibraryTiles`' existing key (the doc without cards and name) changes when a block does, and tiles
redraw. Thumbnails already draw from `Draft.doc`. A change to the typeface is a change to a key
other than `backdrop`, so it draws everything. The card inspector resolves colours from the
editor's current blocks, so it follows a colour edit at once.

`RenderContext` carries the install's `viewing` block and the stored styles by id, and
`RenderRequest.message` sends `viewing` and, under `styles`, those the scene's `styles:` names; no
`fonts` or `fallback` (audio-vue `scene-render`). `PanelScenes` reads `viewing` from the install and
fetches the images the scenes name, the fallback's no longer. Until the `styles` change reads the
host's styles the map is empty, and no scene can name a stored style, since only that change
creates one.

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

`SchemaFacts.colours` is a `SceneColours` in `ConsoleCore`, read from the root's `x-roles` and
`x-scales`: each role's id, group and default, labelled as `block.colors` labels its setting, and
each scale's label and steps, in declared order. `colour(of role:, in blocks:)` is the scene's
`colors` entry for the role, else the role's default, as `HexColour`. `groups(of:)` lists the
colours block's settings under each group of roles, then each scale; `ungrouped(of:)` is the rest,
the shadow. No rule is copied: every name and default is read.

A card's colour setting reads as a new shape, `.roleColour(roles:)`, from its `anyOf` of role ids
and the colour pattern. `SettingDeclaration` gains `role` (`x-role`) and `ownDefault` (`x-own`'s
default, a role's id or a colour), and `drawnColour(_ value:, in blocks:, colours:)` resolves as
the panel does: a colour as it is; a role's id as the scene's colour for it; unset as the role the
setting takes, else its own default read the same way. It gives a `DrawnColour`, the colour and the
role it came from, whose caption is "Uses the scene's <role> colour". `declaresAlike` compares the
role. Settings of one name on different cards take the same role, since audio-vue derives each from
it, so the same-key-different-element case (F10) is gone.

The control is a colour well showing the drawn colour beside a menu of the roles the setting may
take, each with a chip in its colour in this scene as edited, the one taken ticked (`RoleMenu`).
The well commits only when the chosen hex differs from the one shown, so opening the panel on an
unset colour sets nothing. A card's colour settings are listed under one Colours disclosure after
its other settings, closed until opened, since a card now declares one per role it draws (eight on
a VU meter).

A card's `shadow` is a number with no default and no role; unset, it takes the scene's, which its
`x-inherits: scene.colors` says (`SchemaFacts.inheritedValue`), and the row says "Uses the scene's
Shadow".

Alternative: a render-helper call reporting effective colours. A round trip for each inspector
redraw, and a second path to the same answer the export gives by lookup.

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
- [A scene that takes its colours from a style will resolve them from the style, not its own
  block] → `colour(of:in:)` reads the scene's block today; the `styles` change gives it the
  resolved look.
