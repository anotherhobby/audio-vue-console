# Tasks

## 1. Read the card's sizing from the schema

- [x] 1.1 Read `x-sizing` and `x-aspect` in `SchemaFacts` (`ConsoleCore/Sources/ConsoleCore/SchemaFacts.swift`,
      beside `x-min-cells` at line 127) and carry them on `SchemaFacts.Card`. No value is hard-coded.
      Verify: a `SchemaFactsTests` case reads both from a fixture card with `x-sizing: "aspect"` and `x-aspect`.

## 2. The ladder and the search

- [x] 2.1 Add a ladder type in `LibraryTiles.swift` that yields sizes from a card's declared minimum by equal
      whole-cell steps `k`, up to the grid's smaller dimension. For an ASPECT card, each step keeps the declared
      aspect (`x-aspect`) instead of stepping width and height equally. Verify: unit tests for the ladder
      ordering and for the aspect case, in `LibraryTilesTests.swift`.
- [x] 2.2 Add the binary search over `k` in `LibraryTiles`, using `queue.submit` in the same lane and key form
      as tile requests (`"\(tag)tile:\(card)"`, a separate key for the search). The render request is the
      existing `request(for:as:card:minimum:context:)` with `minimum` set to the ladder size. Verify: a test with
      a fake queue that fits from `k = 3` takes 3 or fewer renders for a 36-row grid and returns `k = 3`.
- [x] 2.3 Keep the render at the found `k` as the tile, so no card is rendered twice. Verify: the test in 2.2
      counts renders of the fitting size as one.
- [x] 2.4 When no `k` fits, draw the tile at the declared minimum (the existing request), and mark it unfit.
      Verify: a test where the fake helper reports unfit at every size, and the tile is at the declared minimum.

## 3. Store the found size

- [x] 3.1 Keep each card's found size in `TileSet` beside the tile, keyed by the settings `Key`. A redraw for the
      same key reads it and sends no search. Verify: a test that calls `draw(for:)` twice with the same draft
      sends no second search (the fake queue records the sends).
- [x] 3.2 Moving a card or editing colours keeps the key, so no search runs. Verify: a test that moves a card
      and sends no search; a test that changes a text role's size and sends one search per card.

## 4. Caption and tile view

- [x] 4.1 Give `LibraryTiles.Tile` its drawn size in cells. The library tile's caption
      (`AudioVueConsole/Scenes/CardLibrary.swift`, line 93) shows the tile's drawn size. It does not show
      `sizeOf` (the card's size on the open scene), unless the maintainer rules otherwise (alignment F2). The "Too small to show its reading" line (line 98) is
      kept, now shown for a tile drawn at its minimum with no fitting size.
      Verify: `xcodebuild`-level build passes; a SwiftUI preview or a manual run shows the caption at the drawn size.

## 5. Verification

- [x] 5.1 Run the ConsoleCore tests: `swift test` in `ConsoleCore/`. Record the result.
- [x] 5.2 Run the app against the proving host, open a scene with large type, and check a readout's tile is
      larger than its declared minimum and names its size. Record what was seen.

## 6. Notes

- [x] 6.1 After archive, update `.claude/kb/agent/working-notes.md` (remove the card-minimum section once the
      readout's TOO SMALL is settled) and `project-map.md`'s note on tiles.
