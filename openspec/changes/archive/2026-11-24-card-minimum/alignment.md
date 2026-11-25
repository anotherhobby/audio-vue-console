# Code alignment

## Read

Pass of 2026-11-24.

- `../audio-vue/openspec/changes/card-minimum/specs/scene-render/spec.md`: "The helper answers where a
  card is drawn whole" and "... where a card shows its reading", in full; the change is complete and
  deployed, not archived.
- `../audio-vue/src/render_service.py` `minimum` (and the module docstring's paragraph): the request's
  fields, `placement` checked against the scene, `whole`/`readable` as lists of `[cols, rows]`.
- `../audio-vue/src/scene_model.py` `Scene.minimum`, `_lowest`: a stand-in `Placement(p.card, 0, 0,
  cols, rows)` with its alternate, so cells and neighbours do not affect the answer; widths from the
  slot's `min_cells` to the grid's; `content` fits an aspect-locked card (`rect.fit(m.aspect)`).
- `RenderRequest.swift` (`RenderContext.fields`, `message`), `RenderQueue` (`Lane`, `submit`, keyed
  replacement), `HelperFrame.swift` (`HelperAnswer`).
- `LibraryTiles.swift` (`Key`, `TileSet`, `Ladder`, `drawTile`, `settle`, `request(for:card:context:)`,
  `kept`, `touch`), `LibraryTiles+Setup.swift` (`drawSetup`, `fitted`).
- `SceneLayoutEdits.swift` (`resizing`, `resizedAcross`), `SceneContent+Parking.swift`
  (`resizing`, `resizingParked`), `SceneEditor.swift` (`minimums`, `minimum(of:)`, `resize`,
  `previewResize`).
- `SchemaFacts.swift` (`Card.aspect`, read from `x-sizing`/`x-aspect`), `EditorTiles.dropSize`,
  `SceneEditorView` (`sizeOf`, `make`), `SceneStore` (owns `LibraryTiles`).
- Tests: `TileLadderTests`, `LibraryTilesTests` (`rendersPerDraw`, used 10 times),
  `LibraryTilesSetupTests` (ladder probes via `fitting(from:)`), `SchemaFactsTests` (aspect),
  `FakeRender.reply` (answers `render` and a fixed `hello`-like answer for every other op).
- KB: `pitfalls.md`, `open-questions.md`: nothing held on tile sizing or resize floors.
- Every task read against the code above.

## Findings

- **F1. The relied-on requirements are in audio-vue's open change** (resolved)
  - Plan: relies on `audio-vue:scene-render`'s two `minimum` requirements.
  - Code: they are deltas in audio-vue's `card-minimum`, complete and deployed but not archived, so
    `openspec show scene-render --store audio-vue` does not yet hold them.
  - Goes to: task (none needed).
  - Resolution: read from the change; the helper in the mirrored bundle answers them. Recheck
    the archived wording before archiving this change.

- **F2. `FakeRender` answers every op but `render` as `hello`** (resolved)
  - Plan: tests drive `minimum` through the scripted helper.
  - Code: `FakeRender.reply` answers `{"ok": true, "cards": "d1", "runs": 1}` to anything not
    `render`, which would decode as no answer.
  - Goes to: task 1.2, which teaches it `minimum`.

- **F3. `SchemaFacts.Card.aspect` is read only by the ladder** (resolved)
  - Plan: 2.2 removes the ladder.
  - Code: `aspect` is parsed from `x-sizing`/`x-aspect` and read only in `Ladder.size`;
    `SchemaFactsTests` checks it.
  - Goes to: task 2.2: remove `aspect`, its parse and its `SchemaFactsTests` lines with the ladder.

- **F4. Tile request counts change everywhere** (resolved)
  - Plan: one `minimum` and one `render` per tile.
  - Code: `LibraryTilesTests.rendersPerDraw` (6 + 6 + 2) appears in 10 expectations, and
    `LibraryTilesSetupTests.fitting(from:)` scripts unfit by `colspan`.
  - Goes to: task 2.1, which rewrites both to answer `minimum`.

- **F5. `whole` may be empty for a card at its settings** (resolved)
  - Plan: `wholeSize` falls back to the smallest readable size, then the declared minimum.
  - Code: `Scene.minimum` leaves out every width with no whole height; cards that thin labels by a
    drop step can answer few or none.
  - Goes to: design D1, as written.

## Questions for the maintainer

None. The two rulings this change needed (whole at the smallest area, narrower on a tie; archive
`editor-conveniences` first) were given on 2026-11-24.

## Confirmed

- `minimum` takes the same fields as `render` plus `placement`, and its answer is decoded from the
  header alone (no payload), so `RenderQueue.submit` serves it unchanged.
- A tile's request scene (the card alone at the corner) is a valid `minimum` scene with placement 0.
- `readable` is monotone per width (audio-vue `tests/test_card_minimum.py::TestReadable`, read in the
  hand-off), so D4 can treat it as a floor.
- `LibraryTiles` keeps answers per scene-settings `Key` with `kept` = 12 and `touch` eviction, which
  D2 mirrors.
