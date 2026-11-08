# Code alignment

## Read

Pass 1, 2026-11-07, on `dev` with `scene-save` being built in another session (uncommitted edits to
`SceneGallery`, `SceneEditorView`, `ScenesPage`, `SceneDrafts`, `SceneDocument`, `LaidOutScene`,
`PanelScenes` and the client, with new `Draft.swift` and `HostClient+SceneWrites.swift`). Read as
the tree stood. Pass 2, the same day, after the maintainer ruled that other shapes stay listed and
can be applied: every requirement, decision and task re-read against the reads below. Pass 3,
2026-11-08, for the card library: the reads marked (pass 3). Pass 4, 2026-11-08, after `scene-save`
was archived (`df53b13`): every task re-read against the code it left, the reads marked (pass 4).

- (pass 4) `openspec/specs/scene-apply/spec.md`, "Apply works on any scene of the panel's shape":
  the same text and scenario the delta replaces.
- (pass 4) `openspec/specs/scene-saving/spec.md` and `scene-gallery/spec.md`: their other-shape
  cases (Save and Versions off, Rename and Delete for any shape, Duplicate for This Panel disabled),
  all kept by this plan.
- (pass 4) `AudioVueConsole/Scenes/SceneGallery.swift` (246 lines): `sections`, `Item.fits`,
  `rows` (still `ScenesPage.laidOut`), `menu` (Duplicate by `fits`, Rename… and Delete… for any
  scene not built in), `SceneRow` (unsaved dot, lock, `.opacity`).
- (pass 4) `AudioVueConsole/Scenes/SceneEditorView.swift`: the toolbar's Apply and Duplicate, both
  disabled by `isOtherShape`; `isOtherShape`'s doc comment; `drawTiles()` on `facts.placeable`.
- (pass 4) `AudioVueConsole/Scenes/ScenesPage.swift`: its doc comment ("this panel's shape first").
- (pass 4) `.claude/kb/agent/pitfalls.md`: "A refused drop leaves its library tile undraggable".
- (pass 4) `openspec/changes/calibration/` (open, another session): its specs and alignment F9.

- (pass 3) `ConsoleCore/Sources/ConsoleCore/SchemaFacts.swift`: `init?(schema:)` reads
  `card.<name>` keys into a dictionary by name and ignores other keywords; `placeable` sorts by name.
- (pass 3) `AudioVueConsole/Scenes/CardLibrary.swift`: `shown` filters by `CardTile.title`;
  `CardTile.title` is the name with `_` as spaces; the "Card library" `#Preview`.
- (pass 3) `AudioVueConsole/Scenes/SceneEditorView.swift`: `placeable` feeds `CardLibrary` and
  `drawTiles()`.
- (pass 3) `ConsoleCore/Tests/ConsoleCoreTests/Fixtures/schema-trimmed.json` and its users:
  `SchemaFactsTests`; the gallery preview builds its own schema string.
- (pass 3) `openspec/specs/scene-canvas/spec.md`, "The library offers the host's placeable cards";
  `openspec/specs/scene-rendering/spec.md`, the library tile requirements (unchanged by this plan).
- (pass 3) audio-vue open change `card-categories` (4 of 7 tasks done): proposal, design, its
  `card-categories` spec delta; `src/cards/__init__.py` (`families()` sorted by name);
  `src/cards/peak_rms/manifest.py` (the card names `peak_rms`, `peak_rms_vertical`).
- (pass 3) `.claude/kb/agent/commands.md`: `tools/refresh-render-bundle.sh`.

- `AudioVueConsole/Scenes/SceneGallery.swift`: `rows`, `Item.fits`, `section`, `menu`, `SceneRow`
  (lock and dimming), `GalleryPreview`.
- `AudioVueConsole/Scenes/ScenesPage.swift`: `content` (the listing handed to the gallery),
  `destination`, `shape(of:)`, `laidOut(_:facts:)`, doc comment.
- `AudioVueConsole/Scenes/SceneEditorView.swift`: `make()`'s `readOnly`, which keeps `.shape`.
- `AudioVueConsole/Scenes/SceneMetrics.swift`: `mismatchOpacity`, used only by `SceneRow`.
- `ConsoleCore/Sources/ConsoleCore/LayoutRefusal.swift`: `ReadOnlyReason`, unchanged by this plan.
- `ConsoleCore/Sources/ConsoleCore/DisplayShape.swift`: `matches` (aspect within 0.01).
- `ConsoleCore/Sources/ConsoleCore/PanelScenes.swift`: `load()` drops fixed scenes.
- `ConsoleCore/Sources/ConsoleCore/SceneDrafts.swift`: `listing` is the host's scenes, then copies.
- `ConsoleCore/Sources/ConsoleCore/SceneRendering+Messages.swift`: the editor's unknown-display
  message (design, Risks).
- `openspec/changes/scene-save/`: `proposal.md`, `tasks.md` (7.3, the Apply button), and its deltas
  to `scene-gallery`, `scene-saving` and `scene-apply`, for every other-shape case.
- `openspec/specs/scene-gallery/spec.md`.
- audio-vue `settings-store` ("Every repository scene is a read-only built-in", "Only a built-in
  scene is fixed"), `scene-grid` (the default grid, "A scene is fitted to the display at its own
  aspect"), `control-commands` (every refusal of a switch), `control-api` (scenes routes). Open
  change `command-results-and-reset`: deltas and Impact.
- KB: `product.md`, `project-map.md`, `open-questions.md`, `pitfalls.md`.
- Removals searched across `AudioVueConsole/`, `ConsoleCore/`, `.claude/kb/` and `openspec/specs/`:
  `mismatchOpacity`, `Item.fits`, "For this panel", "Other shapes". Each hit is assigned to task
  3.1 or 5.2.

## Findings

- **F1. `product.md` promises "duplicate for this panel"** (resolved)
  - Plan (pass 1): a scene of another shape was hidden, which contradicted `product.md`'s "The app
    offers 'duplicate for this panel' where a scene's shape does not match (Recommended)".
  - Code: `.claude/kb/agent/product.md`, "Scenes are tied to a display shape".
  - Goes to: task 5.2.
  - Resolution: the maintainer ruled (2026-11-07) that scenes of another shape stay listed, which
    answers this too: `product.md` is not changed, and the disabled Duplicate for This Panel stays.

- **F2. The proposal cited the wrong audio-vue spec for built-in and fixed** (resolved)
  - Plan: Impact named `audio-vue:control-api` for the listing's `built_in` and `fixed`.
  - Code: `control-api` gives the scenes routes; `settings-store` states that every repository
    scene is listed marked built in, and a fixed one marked fixed.
  - Goes to: proposal.
  - Resolution: Impact names `audio-vue:settings-store`, `scene-grid` and `control-commands`. The
    unmodified "The gallery lists the panel's scenes" still cites `control-api`; left as it is, since
    this change does not touch that requirement.

- **F3. The host shows a scene of another shape** (resolved, ruled)
  - Plan (pass 1): a scene of another shape could not be shown on the panel, as its dimming implied.
  - Code: audio-vue `scene-grid`, "A scene is fitted to the display at its own aspect": a 16:9 scene
    runs on the 8:3 panel with backdrop either side. `control-commands` refuses a switch only during
    a calibration, for a scene that will not load, or for a path; never for its shape.
  - Goes to: requirement.
  - Resolution: the maintainer ruled (2026-11-07) that such scenes stay listed, not dimmed, and that
    Apply works on them while editing stays off. The `scene-apply` delta carries it.

- **F4. The `scene-apply` delta rested on unarchived text** (resolved)
  - Plan: RENAMED and MODIFIED blocks for a requirement `scene-save` added.
  - Code: `scene-save` is archived (2026-11-08); `openspec/specs/scene-apply/spec.md` holds "Apply
    works on any scene of the panel's shape" with the text and the "Another shape" scenario the
    delta was written from.
  - Goes to: task.
  - Resolution: checked in pass 4; the old task 1.1 that would have checked it is removed, and
    `openspec validate gallery-sections --strict` passes with no INFO line.

- **F5. A MODIFIED block cannot drop a scenario** (resolved)
  - Plan: the `scene-apply` delta replaces scene-save's "Another shape" scenario.
  - Code: `openspec validate --strict` refuses a MODIFIED block that omits a scenario the current
    spec has, since archive will not drop it.
  - Goes to: requirement (wording only).
  - Resolution: the scenario keeps its name "Another shape" and now says Apply switches the panel to
    the scene, fitted with backdrop either side.

- **F6. The card order within a category is not exported** (open, with audio-vue)
  - Plan: the cards within a category come in the panel's order (maintainer, 2026-11-08).
  - Code: `card-categories` exports `x-category` per card and `x-categories` (`{id, label}` in
    order) at the root, and nothing that orders cards; `$defs` is an object, which `SchemaFacts`
    reads into a dictionary, and audio-vue's `families()` is sorted by name.
  - Goes to: audio-vue, then design D7 and task 1.1.
  - Resolution: asked by `../audio-vue/card-order-handoff.md` (2026-11-08), passed by the
    maintainer to the session building `card-categories`. Task 1.1 reads the answer before group 5.

- **F7. The plan relies on an open audio-vue change** (deferred to task 1.1)
  - Plan: the library reads `card-categories`' keywords.
  - Code: `card-categories` is being built (4 of 7 tasks) and has no standing spec yet, so its
    keywords can change under this plan.
  - Goes to: task.
  - Resolution: group 5 waits on its archive; task 1.1 reads the archived spec and a real export
    first.

- **F8. `card-categories` names this project's `scene-canvas`, which this change modifies**
  (resolved, to tell audio-vue)
  - Plan: the `scene-canvas` delta modifies "The library offers the host's placeable cards".
  - Code: `card-categories`' proposal, Impact: "Referenced project specs:
    `audio-vue-console:scene-canvas`, whose requirement 'The library offers the host's placeable
    cards' is what the grouping serves."
  - Goes to: the maintainer, to tell that session.
  - Resolution: the handoff says the console's `gallery-sections` groups the library; nothing in
    audio-vue's plan needs to change for it.

- **F9. The tiles are drawn in `placeable`'s order** (resolved)
  - Plan: the library shows cards grouped, not by name.
  - Code: `SceneEditorView.drawTiles()` walks `facts.placeable`, so with the old order the tiles
    would draw out of the order shown.
  - Goes to: design.
  - Resolution: D7 makes `placeable` the library's order flattened; task 5.2 leaves `drawTiles` on
    it.

- **F10. A changed manifest stops every card drawing until deployed** (resolved)
  - Plan: the run in the app with `card-categories`.
  - Code: `working-notes.md`, scene rendering: any difference in shared code draws no card;
    `card-categories` edits every card's `manifest.py`.
  - Goes to: task.
  - Resolution: task 6.1 deploys audio-vue to the panel and refreshes the bundle first.

- **F11. Library tile ids must stay unique** (resolved)
  - Plan: design D8 puts the library's tiles under headings.
  - Code: `pitfalls.md`, "A refused drop leaves its library tile undraggable": each `CardTile`
    carries `.id("\(card.name) \(store.drops)")`, and one `.id(drops)` on every tile collapsed the
    library to one card. Pass 3 missed this item.
  - Goes to: task.
  - Resolution: task 5.2 keeps each tile's own id, and a card is in exactly one category
    (`card-categories`, "Every card declares one category"), so ids stay unique across headings.
    Task 6.1 drags a card after a refused drop.

- **F12. Apply and Duplicate share `isOtherShape`** (resolved)
  - Plan: D5 enables Apply for another shape; Duplicate for another shape stays off.
  - Code: `SceneEditorView`'s toolbar disables both by `isOtherShape`, whose doc comment says
    "neither duplicated nor applied here".
  - Goes to: task.
  - Resolution: task 4.1 removes the condition from Apply only and rewords the doc comment.

- **F13. `calibration`'s alignment lists this change's surface as before the library** (open, for
  that session)
  - Plan: this change now also modifies `scene-canvas`.
  - Code: `openspec/changes/calibration/alignment.md` F9 says `gallery-sections` has deltas for
    `scene-apply` and `scene-gallery` only. `calibration`'s own deltas (`calibration-history`,
    `calibration-player`, `calibration-run`, `panel-window`) touch none of this change's specs.
  - Goes to: the maintainer, to tell that session; not edited from here.
  - Resolution: no conflict in specs; only that note is stale.

## Questions for the maintainer

None open. F6 waits on audio-vue's answer to the handoff, not on a ruling.

## Confirmed

- `SceneGallery.rows` places a scene that cannot be laid out by `facts.defaultGrid`, which design D1
  keeps.
- `ScenesPage.destination` opens any id in `store.drafts.listing(...)`, so a scene under "Other
  Shapes" opens as it does today, read-only by `ReadOnlyReason.shape`.
- `PanelScenes.load()` already drops fixed scenes; the gallery need not.
- `SceneDrafts.listing` gives the host's scenes in its order, then copies (design D2).
- `SceneMetrics.mismatchOpacity` is used only by `SceneRow`.
- A scene of another shape is read-only, so it is never unsaved and Apply on it only switches
  (design D5).
- `ScenesPage.shape(of:)` reads `scenes.context.display`, the 16:9 stand-in where the host gives no
  size (design, Risks).
- audio-vue's open change `command-results-and-reset` has no delta to `settings-store`, `scene-grid`
  or a switch's refusals (its `control-commands` deltas add the reset refusal and the command list),
  and its Impact names no spec of this project.
- `open-questions.md` and `pitfalls.md` hold nothing on the gallery, shapes or read-only scenes.
- (pass 3) `SchemaFacts` reads keywords by name and ignores the rest, so the new keywords break
  nothing before group 5, as `card-categories`' design also read.
- (pass 3) The scenario names in the `scene-canvas` delta (`meter`, `readout`, `vu_meter`,
  `peak_rms`) are cards `card-categories` assigns to Readouts and Level.
