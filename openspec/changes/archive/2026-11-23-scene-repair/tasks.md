# Tasks

## 1. The repair (`ConsoleCore`)

- [x] 1.1 Add `SceneRepair` and `RepairChange` (`ConsoleCore/Sources/ConsoleCore/SceneRepair.swift`)
  as design D3 gives them: the repaired `doc`, and each change's place and outcome (`removed`,
  `clamped(from:to:)`, `unset(was:)`, `removedCard` with the card's index), plus a `cannotRepair`
  answer for a scene left with no card. Verify: it builds, and the quality gate reports the file clean.
- [x] 1.2 Add `SceneShape` (`ConsoleCore/Sources/ConsoleCore/SceneShape.swift`), built from the
  `/v1/schema` body, with `repair(of:) -> SceneRepair?` walking the keywords of design D2 from
  `$defs/scene`. It resolves `$ref`, picks a card's definition by `allOf`'s `if`/`then` on `card`,
  and judges nothing by a keyword it does not know. `SchemaFacts.init?(schema:)` builds it into a new
  `shape` property. Verify: new `SceneShapeTests` against `Fixtures/schema-trimmed.json`:
  - `Fixtures/rta-scene.json` needs no repair.
  - The same scene with `analysis` holding `rta_hold_s`, `rta_peak_fall_db_s` and `rta_weighting`
    (the fixture before 2026-11-23) has exactly those three removed.
  - `grid` with `cols`, `rows` and `gap` keeps `gap`.
  - `rta_bars` `hold_s` 20 is clamped to 10.
  - `release: "hold"` is unset.
  - An unknown card is removed, and a scene whose only card is unknown cannot be repaired.
  - A gradient with one bad stop out of two is removed.
  - Every keyword the fixture uses is one the walker knows.
- [x] 1.3 Word each change for the canvas in `RepairChange.description`, naming a block by the
  inspector's section name (`SceneSettingsTab`) and a card by its canvas label and number. Verify: a
  `SceneShapeTests` case reads "Analysis: rta_hold_s removed" and "RTA bars (card 1): hold_s 20 → 10"
  or the labels the code gives.

## 2. Applying a repair (`ConsoleCore`)

- [x] 2.1 Fold the grid size into the repair (design D6):
  - Remove `LaidOutScene.dropGridSize`, `declaresGridSize` and `gridSize`.
  - `LaidOutScene.content` keeps the blocks as read.
  - `PanelScenes`' rename stops dropping the grid size, so a rename of a scene needing a repair is
    refused by the host as any invalid write is.

  Verify: the grid case in `LaidOutSceneTests` (lines 150–164) is rewritten. A stored grid size is
  kept in the content, and `Draft(laid).isUnsaved` is false.
- [x] 2.2 Add `Draft.repaired`, counted by `Draft.isUnsaved` in place of `declaresGridSize`, and
  carried by `SceneDrafts.relaid` as `source` is. Verify: a test relays a repaired draft onto
  another panel and it stays unsaved.
- [x] 2.3 Add `SceneDrafts.repair(_ id:, with: SceneRepair)`, which lays the repaired document out
  on the draft's panel, keeping surviving cards' ids by position (from `removedCard`'s index) and
  the draft's `rev`, with `repaired` set. Add `SceneSession.repair()`, which takes the repair from
  `PanelScenes`, calls it and then `newParse()`. Verify: tests check that after repair:
  - the draft is unsaved, its `doc` holds no undeclared key, and its repair is nil;
  - a removed card's neighbours keep their ids;
  - `revert()` brings back the host's document and its repair.
- [x] 2.4 Add `SceneDrafts.repair(of:shape:)` (design D4): nil for a built-in, else the shape's
  repair of the draft's `doc` where the scene has a draft, or of the host's document.
  `SceneWrites.repair(of:)` gives it the panel's shape for the session. Verify:
  `SceneRepairDraftTests` reports a stored scene needing a repair, none for a built-in, and none for
  a repaired draft.

## 3. Offering it (app target)

- [x] 3.1 Add the repair banner to the editor (`AudioVueConsole/Scenes/`), beside `EditorBanner` in
  `SceneEditorView`. It reads "This scene holds N settings the panel no longer takes", offers
  Repair (calling `session.repair()`) and Show Changes (a popover listing every
  `RepairChange.description`). It shows no button on a read-only scene, and only the no-card
  sentence where no repair is possible. Verify: a `#Preview` for each of the three cases, and the
  app builds.
- [x] 3.2 Give the gallery's card a note for a scene that needs a repair, next to the too-wide note
  in `SceneGallery.swift`. Verify: a `#Preview` with the note, and the app builds.

## 4. Integration

- [x] 4.1 Run `cd ConsoleCore && xcrun swift test --disable-xctest` and the quality gate on every
  Swift file changed, and time `repair(of:)` over every scene the proving host holds. Verify: all
  pass, every file is clean, and one pass over the gallery takes under a millisecond. If it does
  not, hold each repair by scene id and revision (design D4).
- [x] 4.2 On the proving host, open Primary: the gallery marks it, and the banner lists
  `rta_hold_s`, `rta_peak_fall_db_s` and `rta_weighting`. Repair it and Save. Verify: the canvas
  draws its plates, the gallery's note goes, and the host stores the scene.
- [x] 4.3 Update `.claude/kb/agent/host-contract.md` or `project-map.md` with where the repair lives
  and that it reads only the schema's shape. Verify: the note names `SceneShape` and design D2.
