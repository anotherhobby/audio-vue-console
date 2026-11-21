# Tasks

Built 2026-11-21, once audio-vue's `host-grid` had landed and sent its closing note. Run the core suite with `cd ConsoleCore && xcrun swift test --disable-xctest`
(`commands.md`).

## 1. Follow the host

- [x] 1.1 Read audio-vue's closing note and its `host-grid` as built. Bring this change's design and
  specs up to anything built differently, and settle the two points the proposal lists as
  unconfirmed. Delete the note and `host-grid-handoff.md`, and tell the maintainer.
- [x] 1.2 Refresh the contract (`tools/refresh-contract.sh`), the render bundle
  (`tools/refresh-render-bundle.sh`) and the schema and scene fixtures from audio-vue. Verify the
  package builds; list every test the refresh breaks before changing code.

## 2. The grid from the state

- [x] 2.1 `PanelState.grid` from the display section (design D1). Verify with `PanelStateTests`: a
  state with a display gives its grid; one with none gives nil.
- [x] 2.2 `SchemaFacts` without `defaultGrid`, `scaled`, `minimums(forRows:)` and `referenceRows`
  (design D1, D4); every caller reads the declared minimum. Verify with `SchemaFactsTests`: the
  refreshed schema, whose grid block holds only `gap`, gives facts.
- [x] 2.3 `LaidOutScene.init(_:panel:ids:)` and `SceneContent.isTooWide(for:)` (design D2). Verify
  with `LaidOutSceneTests`: a scene with no spans covers the panel's grid; a card ending at column
  96 on a 64-column panel gives a 96-column layout that is too wide; moving it in clears that.
- [x] 2.4 Writing back (design D3): no `cols` or `rows`; an unset span kept while the card spans the
  grid from column 0, written once it does not. Verify with `LaidOutSceneTests` for both, and for a
  new card.
- [x] 2.5 `SceneDrafts`: `draft(for:panel:)`, `new(on:among:)` writing no grid block, and drafts
  laid out again when the panel's grid changes. Verify with `SceneDraftsTests`.

## 3. What goes

- [x] 3.1 Remove `GridDensity`, `DisplayShape`, their tests, and `LayoutRefusal.tooSmall` if unused
  (design D4). Verify the package builds and the suite passes.
- [x] 3.2 `GallerySections` with `mine` and `builtIn` only; `LibraryTiles.Key` without the grid.
  Verify with `GallerySectionsTests` and `LibraryTilesTests`.

## 4. Too wide

- [x] 4.1 `SceneRendering.draw` and `SceneThumbnails.draw` ask nothing for a scene too wide
  (design D6). Verify with a test in each suite that the queue is sent nothing.
- [x] 4.2 `SceneSession.canApply` is false for a scene too wide, and `canSave` is not (design D7).
  Verify with `SceneSessionTests`.

## 5. The app

- [x] 5.1 `ScenesPage`: the panel's grid from the state, and an unavailable view while there is
  none. `SceneGallery`: two sections, the too-wide note, Duplicate on every row, New Scene on the
  panel's grid.
- [x] 5.2 `SceneCanvas` and `LayerStack` at the display's shape, widened for a scene too wide, its
  extra columns shaded and said (design D5). `SceneEditorView` without the other-shape read-only
  reason; Apply's help.
- [x] 5.3 `SceneSettings`: the Grid section without the density stepper.
- [x] 5.4 Verify 5.1 to 5.3 by building the app (`BuildProject` over Xcode MCP) with no new warnings
  and the quality gate clean, and by previews of the gallery with a too-wide scene and of the
  canvas, one fitting an 8:3 panel and one too wide for a 61-column panel.

## 6. Prove and record

- [x] 6.1 Live helper: `RENDER_HELPER_LIVE=1 xcrun swift test --disable-xctest --filter
  LiveHelperTests`: a card with no spans drawn for an 8:3 and a 16:9 display, and a scene reaching
  column 96 drawn on the first and refused on the second (`theGridIsTheDisplays`).
- [x] 6.2 The maintainer's run against the proving host, together with `scene-settings` task 5.1:
  open, edit, save and apply a scene; duplicate Default and apply the copy; New Scene.
  Run 2026-11-21: everything as expected, a stored scene holding a grid size opened and resaved
  without it.
- [x] 6.3 KB: revise the agent notes on shapes, densities and scaled minimums (`project-map.md`,
  `host-contract.md`, `working-notes.md`, `product.md`).
