# Code alignment

## Read

Pass 1, 2026-11-08, on `dev` at `a5b6576`, with `card-settings` planned and not built. Pass 2, the
same day, after the maintainer ruled on calibration across rates (F7): the calibration requirement,
D7 and tasks 1.2, 2.4, 4.3 and 5.1 re-read. Reads against
code card-settings will change are marked (planned), and are re-read in task 1.1. Pass 3,
2026-11-09, on `dev` at `433126d` (task 1.1): card-settings as built and archived, and audio-vue's
`card-colours`, built and archived, folded in at the maintainer's ruling.

- `SceneEditor.swift`: `layout`, `commit`, `preview`, `registerUndo`, `show`, `onCommit`.
- `Draft.swift`: `layout`, `isUnsaved`, `doc`. `SceneDrafts.swift`: `keep(_:for:)`, `duplicate`,
  `load`, `revert`, `reread`.
- `LaidOutScene.swift`: `doc(for:)` replaces only `cards`; `grid` read into `SceneLayout.grid`.
- `SceneRendering.swift`: `show(_:)`, `draw(_:plates:through:)` (`plates: nil` is everything),
  `take`. `RenderRequest.swift`: `plates: [Int]?`, `backdrop: Bool`.
- `LibraryTiles.swift`: tiles keyed on the doc without `cards` and `name`;
  `SceneEditorView.drawTiles()` draws from the parse's `laidOut`.
- `LayoutRefusal.swift`: its cases; no `tooSmall`.
- `HostClient+Scenes.swift`: `image(_:at:token:)` only; `ImageStore.fetch`. `openapi.json`:
  `GET /v1/images` (`Images`, `Image`: id, shipped, format, bytes, width, height, added_at) and
  `POST /v1/images` (raw `image/png` or `image/jpeg`; 201, 413, 415, 422, 401).
- `AudioVueConsole/Scenes/SceneInspector.swift`: `SceneSettingsPanel`.
- `grep '\.layout\b'` over the app and core: 38 uses, all reachable as `content.layout` (task 2.1).
- audio-vue `json_schema()`: `scene`'s keys (name, fixed, grid, glass, backdrop, palette, type,
  analysis, display, cards); each block's settings; `gradient` an array of colours, `minItems` 2;
  `rta_weighting`'s standard IEC 61672-1 with F, S and I.
- audio-vue `src/render_service.py` (the `render` op's `plates` and `backdrop`) and
  `src/scene_layers.py` (`render`: `chosen is None` draws every plate, an empty list none).
- audio-vue specs read for what the plan relies on: `scene-backdrop` (one source, malformed refused,
  no backdrop is the palette's background), `scene-grid` (declared grid, malformed refused,
  placements stay on it), `type-scale` (the scene chooses each kind's size within its range),
  `scene-render` ("A request may name its plates", "The backdrop is one layer"), `settings-store`
  (images, writes). `openspec list --store audio-vue`: no active changes.
- `card-settings` (planned): its `scene-canvas` and `scene-rendering` deltas, D1 to D8.
- Pass 3: `SettingGroup.swift` (`SettingDeclaration`, `Shape`, `declaresAlike`, `SettingGroup`),
  `SettingValues.swift` (`SettingValue`, `effectiveValue`), `CardSettings.swift` (the "Uses the
  palette" state), `SceneLayout.swift` (`LayoutCard.settings`), `SceneEditor.swift` (`set`,
  `useDefault`); `HostClient+Calibration.swift` (`CalibratedRate`) and `PanelInput.calibrations`;
  the archived `card-settings` design and the standing `card-settings`, `scene-canvas` and
  `scene-rendering` specs.
- Pass 3, audio-vue: `card-colours` (spec, and design D1 to D4), `settings-schema` ("The
  declarations export as JSON Schema", "A colour setting says what it overrides"), and
  `json_schema()` read live: `scene`'s keys now include `elements`; `block.palette` 21 colours;
  `block.elements` 35 choices with labels; `x-swatches`, `x-elements`; every card colour setting's
  `x-element`; no block declares `x-label`. `openspec list --store audio-vue`: `mac-output` open.

Pass 4, 2026-11-19, on `dev` at `e47c193`: `scene-styles-handoff.md`; audio-vue at `ebf804e`:
`scene-styles`' proposal, `json_schema()` read live, `src/render_service.py`, `styles/default.yaml`;
the regenerated contract diffed against the saved one (the style routes, `viewing_set`).

## Findings

- **F1. Two open changes modify the same requirements** (resolved)
  - Plan: this change's `scene-canvas` and `scene-rendering` deltas modify "Edits are kept until
    saved or discarded" and "An edit draws again only what it changed", which `card-settings` also
    modifies.
  - Code: archive replaces a requirement whole, so the later archive wins.
  - Goes to: task.
  - Resolution: this change's deltas carry card-settings' text plus its own, card-settings is
    archived first (tasks preamble), and task 1.1 rebases them on what card-settings archived.
- **F2. A request for the backdrop alone** (resolved)
  - Plan: design D6 asks for the backdrop alone on a backdrop change.
  - Code: `RenderRequest` already has `plates` and `backdrop`; audio-vue's `scene_layers.render`
    draws no plate for an empty `chosen` and the backdrop where asked. The spec's "A request may
    name its plates" says the answer holds the named plates alone and the backdrop where asked,
    which an empty list fits.
  - Goes to: design.
  - Resolution: D6 sends `plates: []`, `backdrop: true`.
- **F3. The grid is not written back today** (resolved)
  - Plan: density changes `cols` and `rows`.
  - Code: `LaidOutScene.doc(for:)` never writes `grid`; a scene with no `grid` block is written with
    none, laid out on the default.
  - Goes to: design and task.
  - Resolution: D1 writes `cols`/`rows` from the layout; task 2.1 checks that a scene with no grid
    block keeps none until its grid changes, so an untouched scene is written as read.
- **F4. Library tiles draw from the parse** (resolved)
  - Plan: tiles follow the scene's settings as edited.
  - Code: `drawTiles()` uses `laidOut`, the parse, so an edited palette would draw tiles in the old
    one.
  - Goes to: task 4.2.
  - Resolution: draw from the draft's current document.
- **F5. The reader's name** (resolved)
  - Plan: blocks read into the same type as cards' declarations.
  - Code: card-settings named it `CardSettings`.
  - Goes to: card-settings' design and tasks.
  - Resolution: card-settings now names it `SettingGroup` from the start, so nothing is renamed.
- **F6. `fixed` is a top-level scene key, not a block** (resolved)
  - Code: `scene` declares `fixed` beside the blocks.
  - Resolution: `SceneContent.blocks` holds every top-level key but `cards` and `name`, so `fixed`
    passes through; only declared `block.*` refs get sections.

- **F7. The host reports calibration for the running rate only** (resolved, answered by audio-vue)
  - Plan: the scene warns only where no calibration holds at its rate (maintainer, 2026-11-08: a
    user may calibrate at every rate and switch scenes between them).
  - Code: audio-vue applies `record.active(chain)`, the newest record valid for the device and rate
    in use, a stale one included (`src/record.py`, `overrides_for`, `active`; `scene.py`,
    `calibration_status`). The contract's `state.sections.calibration` describes the running rate
    alone; `RunEntry` carries no rate. The console cannot tell whether another rate is calibrated.
  - Goes to: requirement (ruled), design D7, tasks 1.2 and 4.3.
  - Resolution: `scene-settings-handoff.md` asked for every calibrated rate of the installed chain.
    Answered by `GET /v1/calibration` (audio-vue `input-and-rates`), read as `CalibratedRate` and
    held in `PanelInput.calibrations` since the console's `input-and-rates`; task 4.3 no longer
    waits (pass 3).
- **F8. The palette is 21 swatches, and `grid` is gone** (resolved)
  - Plan: 13 palette colours; tests and the fixture assume them.
  - Code: audio-vue `card-colours` D1: identity, sequence, status, text, structure and highlight
    families; `grid` renamed `track`, a scene setting `grid` refused. The trimmed fixture is from an
    export before it.
  - Goes to: proposal, spec, design, task 2.3.
  - Resolution: the palette is every declared swatch, grouped by family; 2.3 refreshes the fixture.
- **F9. A new scene block, `elements`** (resolved)
  - Code: `block.elements`, one `enum` of swatch names per element, its default the element's
    swatch; status elements included, which a scene may set and a card may not.
  - Goes to: proposal, spec, design D2 and D8, tasks 2.3 and 4.1.
  - Resolution: an Elements section after Palette, each choice shown in its swatch's colour.
- **F10. One key overrides different elements on different cards** (resolved)
  - Code: `major_color` is `grid_major` on `rta_bars`, `outline` on `loudness_scope`;
    `declaresAlike` would share it, with two different unset colours.
  - Goes to: the card-settings delta, design D8, task 2.5.
  - Resolution: `declaresAlike` also compares the element.
- **F11. A block declares no label** (resolved)
  - Plan: an unknown block's section "by its label".
  - Code: no `block.*` carries `x-label`.
  - Goes to: spec and design D2.
  - Resolution: by its key.
- **F13. The host refuses an angle without a gradient** (resolved; found on the maintainer's run)
  - Plan: the angle survives every switch of source (design D3, spec).
  - Code: audio-vue `src/schema/scene.py` refuses `angle` where the backdrop holds no gradient;
    its `scene-backdrop` spec does not say so. Every switch from a gradient with an angle to Colour
    or Image was refused, and the canvas fell back to boxes.
  - Goes to: spec, design D3, task 3.2.
  - Resolution: the angle is written only with a gradient; `BackdropMemory` brings back the stops
    and angle when Gradient is chosen again (maintainer, 2026-11-09: switching back must not lose
    the gradient). audio-vue's spec could state the rule.
- **F15. A card setting can have no effect, and the export does not say so** (resolved)
  - Plan: every declared setting can be set to effect.
  - Code: audio-vue's meter colours a field with a caution or over threshold by zone, and
    correlation by phase (`src/cards/fields.py`, `src/cards/meter/card.py`), so `bar_body_color`
    and `bar_tip_color` change nothing for `true_peak_max`, `crest_peak`, `ppm_peak`,
    `sample_peak` and `correlation`. The export has no keyword for it.
  - Goes to: card-settings delta, design D9, tasks 1.3 and 4.5.
  - Resolution: `meter-colours-handoff.md` asked audio-vue to declare it (maintainer, 2026-11-09:
    declared by audio-vue, not copied; folded into this change). Answered the same day by
    `x-unused-when`, a list of cases each needing every named setting to hold (audio-vue
    `settings-schema`, "A setting says when it has no effect"); built in task 4.5.
- **F14. A backdrop of blur alone is refused** (resolved; found on the maintainer's run)
  - Plan: None keeps `{blur}` where a blur was set (design D3, task 3.2).
  - Code: audio-vue `scene-backdrop`, "A malformed backdrop is refused": a `backdrop:` holding none
    of `color`, `gradient` and `image` is refused, blur or not. The plan misread it.
  - Goes to: design D3, task 3.2.
  - Resolution: None removes the whole block; the Blur row hides under None; `BackdropMemory` keeps
    the blur and brings it back with the next source.
- **F12. audio-vue's open `mac-output` modifies a relied-on requirement** (resolved, no effect)
  - Code: its `settings-schema` delta to "The declarations export as JSON Schema" adds "choices",
    which this plan already reads as an `enum`. Its Impact names no spec this change modifies.
  - Goes to: nothing.

- **F16. The palette and the elements are gone** (resolved; audio-vue `scene-styles`, 2026-11-19)
  - Plan: 21 swatches by family and an `elements` block pointing 35 elements at them (F8, F9).
  - Code: `block.colors` holds one colour per role (17, in the groups background, text, lines and
    signal), the steps of two scales (Warnings, Stereo phase) and `shadow`, a number; the root has
    `x-roles` and `x-scales` and no `x-swatches` or `x-elements`.
  - Goes to: proposal, spec, design D2 and D8, tasks 6.2, 6.3 and 6.5.
  - Resolution: `SceneColours` reads roles and scales; Colours is wells by group and scale.
- **F17. A card's colour takes a role or a colour** (resolved)
  - Plan: a card colour is `#rrggbb`, unset by `x-element` (F10).
  - Code: `anyOf` an `enum` of the 17 role ids and the pattern, with `x-role`, or `x-own:
    {default}` for a colour of the card's own; no step of a scale is offered. Derived per role a
    card draws, so a card declares many (eight on `vu_meter`), and one name is one role on every
    card.
  - Goes to: the card-settings delta, design D8, tasks 6.2 and 6.5.
  - Resolution: `.roleColour(roles:)`, `drawnColour`, a well beside a role menu, colours under one
    disclosure. F10's case no longer arises.
- **F18. Text sizes are numbers, and the typeface is the scene's own key** (resolved)
  - Plan: Title, label and value sizes as enums in `block.type`.
  - Code: `block.type` holds seven numbers in `px` with bounds and no step; `scene.typeface` is a
    labelled enum outside any block, with `x-choice-labels`.
  - Goes to: spec, design D2, task 6.3.
  - Resolution: the generic number row; `SchemaFacts.sceneSettings`; `SceneEditor.setScene`.
- **F19. The render request changed** (resolved)
  - Plan: the standing `scene-rendering` request carries `fonts` and `fallback`.
  - Code: audio-vue `src/render_service.py` reads `viewing` and `styles` and neither of those; a
    missing image draws the default style's backdrop; the answer adds `style_notice`.
  - Goes to: the scene-rendering delta, design D6, task 6.4.
  - Resolution: `RenderContext.viewing` and `styles`. `style_notice` is the `styles` change's to
    show, since no scene names a stored style before it.
- **F20. No backdrop is the default style's gradient** (resolved)
  - Plan: None shows the palette's background (F14).
  - Code: audio-vue `scene-backdrop`: a scene with no backdrop draws the `default` style's.
  - Goes to: spec, design D3, task 6.5.
  - Resolution: the segment is Default, and says the default backdrop shows.
- **F21. A card's shadow has no default and no keyword saying whose it takes** (resolved, with a
  match by key)
  - Code: a card's `shadow` is a number with no `default`, `x-role` or `x-own`; its help says unset
    uses the scene's.
  - Goes to: design D8, task 6.2.
  - Resolution: first a match by key and shape; since 2026-11-20 the export's `x-inherits` names
    `scene.colors`, read by `SchemaFacts.inheritedValue` (task 7.8).
- **F22. Stored and built-in scenes were renamed on the host** (resolved, no app change)
  - Code: `rta_bars`' and the scope's line colours are `grid_major_color`, `grid_minor_color`,
    `tick_color` and `outline_color`. The app holds no scene of its own, and the host's store was
    rebuilt.
  - Goes to: task 6.1 (the RTA fixture).

- **F23. The host holds no scene without a card** (resolved in the app)
  Read 2026-11-20: the schema's `cards` has `minItems: 1` (`src/schema/export.py`), and the render
  bundle answers "no cards: entries". Ruled (maintainer, 2026-11-20): a new scene is like a new
  document, the app's alone until saved. So the app asks the helper for nothing and disables Save
  and Apply while a scene has no cards (task 7.6), and audio-vue is asked for nothing.
- **F24. The scene's display defaults were not what an unset setting does** (resolved)
  `block.display` declared 0 for both timeouts, but an unset one takes the install's. audio-vue's
  `scene-editor-settings` (2026-11-20) exports `x-inherits` on them and declares no default; the
  app reads it (task 7.8).
- **F25. Labels, a second signal setting and text-size steps were the host's** (resolved, no app
  code)
  audio-vue ruled otherwise on the signal: silence is one fixed line, `threshold_lufs` is gone
  from both display blocks and the state, and the time asked for is `analysis.reset_silence_s`,
  with `mute_on_silence`, both shown by the Analysis tab as declared. The install's `loudness`
  block is gone; the app read none. A scene's display block gains `saver`. Steps are declared on
  the sizes, radius, blur, gap, angle and timeouts, which gives them arrows.
- **F26. The plates' declared default opacity was 1.0** (resolved, no app code)
  `block.glass` now declares `opacity` at 0.6, so a new scene shows and draws 60%.
- **F27. The grid stops being the scene's** (resolved, moved)
  audio-vue's `host-grid` (hand-off, 2026-11-21) makes the grid the panel's and refuses a scene's
  `cols` and `rows`. The density requirements, D5 and task 3.1 are withdrawn here; the code built
  for them, the grid write of F3 and New Scene's grid from a size are removed by the console's
  `host-grid`. Task 5.1 is run once that change is built.

## Questions for the maintainer

None open. Ruled (maintainer, 2026-11-08): scene settings as their own change after card-settings;
the grid's gap and density at the scene's aspect; a calibration warning only where none holds at the
scene's rate (F7). Ruled 2026-11-09: a card's unset colour shown by lookup is part of this change
(F8 to F10). Ruled 2026-11-19: the app follows audio-vue's `scene-styles` in this change, and the
tabs are Scene, Style and Analysis (F16 to F22). Ruled 2026-11-21: the grid's density leaves this
change, and the run on the proving host waits for `host-grid` (F27).

## Confirmed

- Every scene block is declared in the schema with labels, help, defaults and classes, so the
  sections need no names from the app beyond their order.
- Image list and upload routes, and `GET /v1/calibration`, exist in the saved contract; no host
  work.
- Every card colour setting names a role or its own default (`x-role`, `x-own`; checked over the
  export, 2026-11-19), so the lookup covers every card colour the export declares.
- A scene write never changes the screen; Apply reloads it (`audio-vue:settings-store`).
- A gradient needs two stops (`minItems` 2, `scene-backdrop`), so the stop list refuses removal at
  two.
- `rta_weighting`'s values are all its standard's, so it is never flagged; four analysis settings
  are measurement, `capture_rate` is chain.
