# Code alignment

## Read

Pass 1, 2026-11-08, on `dev` at `a5b6576`, with `card-settings` planned and not built. Pass 2, the
same day, after the maintainer ruled on calibration across rates (F7): the calibration requirement,
D7 and tasks 1.2, 2.4, 4.3 and 5.1 re-read. Reads against
code card-settings will change are marked (planned), and are re-read in task 1.1.

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

- **F7. The host reports calibration for the running rate only** (resolved, waits on audio-vue)
  - Plan: the scene warns only where no calibration holds at its rate (maintainer, 2026-11-08: a
    user may calibrate at every rate and switch scenes between them).
  - Code: audio-vue applies `record.active(chain)`, the newest record valid for the device and rate
    in use, a stale one included (`src/record.py`, `overrides_for`, `active`; `scene.py`,
    `calibration_status`). The contract's `state.sections.calibration` describes the running rate
    alone; `RunEntry` carries no rate. The console cannot tell whether another rate is calibrated.
  - Goes to: requirement (ruled), design D7, tasks 1.2 and 4.3.
  - Resolution: `scene-settings-handoff.md` asks for every calibrated rate of the installed chain;
    the note waits on the answer and nothing else does.

## Questions for the maintainer

None open. Ruled (maintainer, 2026-11-08): scene settings as their own change after card-settings;
the grid's gap and density at the scene's aspect; a calibration warning only where none holds at the
scene's rate (F7).

## Confirmed

- Every scene block is declared in the schema with labels, help, defaults and classes, so the
  sections need no names from the app beyond their order.
- Image list and upload routes exist in the saved contract; no host work.
- A scene write never changes the screen; Apply reloads it (`audio-vue:settings-store`).
- A gradient needs two stops (`minItems` 2, `scene-backdrop`), so the stop list refuses removal at
  two.
- `rta_weighting`'s values are all its standard's, so it is never flagged; four analysis settings
  are measurement, `capture_rate` is chain.
- Density's counts: 64×36 reduces to 16:9, rows 18 to 108 by 9, 11 choices; 96×36 to 8:3, rows 18
  to 108 by 3, 31 choices; 96×54 maps column 16 of 64 to 24 of 96 and a 32-column span to 48.
