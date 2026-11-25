# Tasks

Core tests run with `cd ConsoleCore && xcrun swift test --disable-xctest` (add `--filter <Suite>`).
App changes are verified by building the app and trying them against the paired panel.

## 1. The answer and its store (`ConsoleCore`)

- [x] 1.1 Add `CardMinimum`, decoded from a `minimum` answer's `whole` and `readable`, with
  `wholeSize` (fewest cells, the narrower on a tie; else readable; else nil) and `floor`
  (`MinimumFloor`, columns to least rows, nil for a width left out) (`CardMinimum.swift`, design D1).
  Verify: `CardMinimumTests` cases for each `card-minimum` "A card's whole size is the smallest whole
  one" scenario, a width left out, and an answer that does not decode.
- [x] 1.2 Add `CardMinimums` holding answers by scene-settings `Key` and card entry without cells and
  group, with `answer(for:)` and `ask(for:in:from:lane:key:)` sending `op: "minimum"`,
  `placement: 0` on the tile's scene (`CardMinimums.swift`, design D2). Teach the tests' scripted
  helper to answer `minimum`. Verify: `CardMinimumsTests` cases: one request per card and settings;
  a moved card asks nothing; two cards alike share one answer; a changed setting or scene setting
  asks again; a refused answer is no answer.

## 2. Tiles from the answer (`ConsoleCore`)

- [x] 2.1 Draw each plain tile from one `minimum` and one `render` at `wholeSize`, the declared
  minimum where there is none, through `CardMinimums`; do the same in `drawSetup` with the setup,
  keeping its wanted-settings guard (`LibraryTiles.swift`, `LibraryTiles+Setup.swift`, design D3).
  Verify: `LibraryTilesTests` and `LibraryTilesSetupTests` rewritten to the new request count
  (`rendersPerDraw`) pass: a tile drawn at its whole size; a set-up meter with ticks drawn larger; a
  card answered never readable drawn at its declared minimum saying so; last-wins and
  cleared-in-flight still hold.
- [x] 2.2 Remove `LibraryTiles.Ladder` and `TileLadderTests.swift`, and `SchemaFacts.Card.aspect`
  with its parse and its `SchemaFactsTests` lines, which only the ladder read (alignment F3).
  Verify: `rg "Ladder|smallestFitting|\.aspect"` in `ConsoleCore/` finds no card-aspect use; the
  suite passes.

## 3. The resize floor (`ConsoleCore`)

- [x] 3.1 Give `SceneLayout.resizing` and `SceneContent.resizingParked` (through
  `SceneContent.resizing`) a `MinimumFloor` in place of the scalar minimum, narrowing only to widths
  the card's height reads at and lowering only to the floor at the width reached (design D4).
  Verify: `SceneLayoutTests` and `ParkedEditTests` cases for each `scene-layout` "A resize stops at
  a neighbour's edge" and `card-parking` "A parked card resizes within the pane" scenario; the
  existing resize tests pass with a constant floor.
- [x] 3.2 Have `SceneEditor` build a card's floor from a held `CardMinimum`, else its declared
  minimum, and take `CardMinimums` (`SceneEditor.swift`, design D4). Verify: `SceneEditorTests`
  cases: a held answer's floor stops a resize; with none held, the declared minimum does.

## 4. The editor (`AudioVueConsole`)

- [x] 4.1 Hold `CardMinimums` in `LibraryTiles`, which `SceneStore` owns; ask for the selected
  resizable card's minimum when it changes or its or the scene's settings change; give the drop the
  tile's size where its answer is held (`LibraryTiles.swift`, `SceneEditorView.swift`,
  `FollowingEdits.swift`, `EditorTiles.swift`, design D2, D5 and D6).
  Verify: the app builds; in the app a meter with ticks on is shown and dropped with its ticks, a
  resize stops where the meter would say Too Small, and a drag never stalls.
- [x] 4.2 Record in `.claude/kb/agent/host-contract.md` the `minimum` request and what the console
  relies on (`readable` a floor), and in
  `decisions-log.md` the smallest-area rule and the narrowing rule (design D4). Verify: the notes
  name files that exist.

## 5. Against the real helper

- [x] 5.1 Add a `LiveHelperTests` case asking the bundled helper for the RTA fixture's card's
  minimum at 1920 × 720, and printing its time. Verify: `RENDER_HELPER_LIVE=1 xcrun swift test
  --disable-xctest --filter LiveHelperTests` passes; the answer decodes and its `readable` is
  non-empty.

## Workflow follow-up

- Remind the maintainer to delete `card-minimum-handoff.md` once this change is built.
