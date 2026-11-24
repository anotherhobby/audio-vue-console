# Tasks

## 1. The host's bundle and schema

- [x] 1.1 Refresh `ConsoleCore/Tests/ConsoleCoreTests/Fixtures/schema-trimmed.json` from audio-vue's
  `json_schema()` as `commands.md` (2026-11-23) records, keeping the fixture's `x-categories`. Verify
  that `card.logo` and `block.display` in the fixture hold the four colours each, and that
  `xcrun swift test --disable-xctest` in `ConsoleCore/` passes, or that each failure is a test
  pinned to the old schema and is fixed here. (Done: `rta_bars` gained `channel`, so 24 settings;
  the card with none is now `calibration`.)
- [x] 1.2 In `SceneColoursTests` (beside the other `drawnColour` cases), hold `card.logo`'s `wordmark_color`, `bar_foot_color`,
  `bar_top_color` and `hold_color` and `block.display`'s four `saver_*_color` to `.roleColour`. Each
  has its `x-own` default as `ownDefault` and no `role`, and `drawnColour(nil, …)` is that colour with
  no role. Hold `saver_scene_backdrop` and `saver_scene_plate` to `.boolean`, defaulting to false.
  Verify that the new cases pass.
- [x] 1.3 Run `tools/refresh-render-bundle.sh`, then add a `LiveHelperTests` case that draws a scene
  holding one `logo` card. It checks that `hello`'s digest equals the mirrored manifest's, and that
  the card's plate layer is drawn and not named in `unfit`. Verify with
  `RENDER_HELPER_LIVE=1 xcrun swift test --disable-xctest --filter LiveHelperTests`.

## 2. A colour in a scene block

- [x] 2.1 Move the `.roleColour` branch of `CardSettingsList.fromScene`
  (`AudioVueConsole/Scenes/CardSettings.swift`) into a static `FromScene` builder, taking the
  declaration, the held value, the scene's blocks and its `SceneColours` (design D1).
  `CardSettingsList.fromScene` calls it. Verify that the app builds and that a card's colour row
  still shows its role and colour (`card-settings`, "A setting shows the scene's value or the
  card's default").
- [x] 2.2 Give `BlockSettingRow` (`AudioVueConsole/Scenes/SceneSettings.swift`) the scene's
  `SceneColours` from `BlockSection`. For a `.roleColour` declaration, it builds its `FromScene` with
  the 2.1 builder from the display block's value as edited. Verify in the running app against the
  `scene-settings` scenarios "Unset", "A role", "The role changes", "A colour of its own", "Opening
  Display" and "The scene's backdrop".

## 3. The installation's display block

- [x] 3.1 Add `applies` to `InstallWritten` (`ConsoleCore/HostClient+Install.swift`) as an enum of
  `on_start`, `on_restart`, `on_reload` and `restarted`, read from the answer (design D3). Verify
  with `HostClientInstallWritesTests` cases for `on_start` and `restarted`.
- [x] 3.2 In `PanelScenes.load()`, read `installBlocks` in place of `install`, keeping `installed`
  as each block's document and each block's revision beside it. Remove `HostClient.install(at:token:)`,
  which then has no caller, and its test `HostClientScenesTests.theInstallBlocksAreReadByName`
  (alignment F7). Verify that `PanelScenesTests` pass unchanged.
- [x] 3.3 Add `PanelScenes.writeInstall(_:block:)` in `ConsoleCore/PanelScenes+Install.swift`
  (design D2), with `address`, `client`, `pairing` and `unpairing(_:)` made internal. On success it
  replaces the block's document and revision. On `.stale` it reads the blocks again and rethrows.
  Verify with
  cases in `PanelScenesInstallTests` (its own suite, as `PanelScenesTests` is at the gate's limit):
  - a stored write changes `facts.inheritedValue` for an unset `saver_after_min`, and the next
    write is made on the new revision;
  - a stale write leaves the host's block held.

## 4. The Display page

- [x] 4.1 Add `AudioVueConsole/DisplayPage.swift` (design D4, D5): a Screen section with
  `PanelScenes.display`, and When Idle with a `SettingRow` per `facts.installSettings["display"]`
  declaration, writing through `writeInstall`. The note shows under the section. Without
  `store.scenes`, it says the panel must be paired first. Verify that the app builds.
- [x] 4.2 In `PanelWindow.detail`, send `.display` to `DisplayPage` and `.history` to
  `SketchLaterPage`. Delete `SamplePage` (`PanelWindow.swift`), `SketchDisplayPage`,
  `AudioVueConsole/Sketches/SketchData.swift` and `sketch.json`, which then have no caller
  (alignment F3). Verify that `grep -rn "SketchDisplayPage\|SamplePage\|SketchData\|SketchPanel"
  AudioVueConsole` finds nothing and that the app builds.
- [x] 4.3 Run the app against the proving host and check the `panel-display` scenarios: a host with
  no display block, Screensaver after ten minutes, back to the default, not paired, and ten minutes
  then a scene. Check `panel-window`'s "The Display page" scenario too. Check that the host's
  revisions (`GET /v1/install/display/revisions`) show each write once.

- [x] 4.4 Add `RenderRequest.undrawnBlocks` (`display`) and leave those blocks out of
  `SceneRendering.show`'s changed blocks and `LibraryTiles.Key` (design D7). Verify with a
  `SceneRenderingTests` case where a display-only change sends no request, a `LibraryTilesTests`
  case where it draws no tile again, and the maintainer stepping Screensaver after with no redraw.

## 5. Integration

- [x] 5.1 Open the app against the panel and check that the canvas names no code difference, and
  that a scene holding a `logo` card draws it with Wordmark, Bar foot, Bar top and Hold colour under
  Colours, each at the logo's own colour and naming no role. If a difference is named, list it for
  the maintainer. It is theirs to deploy or commit on the audio-vue side.
- [x] 5.2 Run `xcrun swift test --disable-xctest` in `ConsoleCore/` and the Swift quality gate on the
  changed files. Verify that both pass, or that each gate finding is raised with the maintainer as
  `.claude/CLAUDE.md` says.
- [x] 5.3 Update the KB:
  - `commands.md`: the new live test;
  - `project-map.md`: the Display page, and `PanelScenes` as the install blocks' one model; lines
    49 and 56 lose `SketchData`, `sketch.json` and the Display sample page;
  - `pitfalls.md`, "The installed capture rate has one model": the display block's model.

  Verify that each entry names a file that exists.

## Workflow follow-up

- Archive the change once the maintainer has run the Display page and a scene's Display section.
- Remind the maintainer to delete `console-native-logo-handoff.md` at this repository's root.
