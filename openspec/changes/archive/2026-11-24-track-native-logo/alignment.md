# Code alignment

## Read

Pass 1, 2026-11-24:

- `AudioVueConsole/Scenes/CardSettings.swift`: `CardSettingsList.fromScene`, the `.roleColour`
  branch and the inherited branch; `FromScene`, `RoleChoice`, `SceneLook`; `SettingRow.state`;
  `SettingControl`'s `.roleColour`, `.boolean` and `.choice` cases.
- `AudioVueConsole/Scenes/SceneSettings.swift`: `SceneSettingsPanel`; `BlockSection` (holds
  `colours`, the default branch draws `BlockSettingRow`); `BlockSettingRow` (`own`, `taken`, the
  `FromScene(value:owner:)` it builds).
- `ConsoleCore/SettingGroup.swift`: `SettingDeclaration.init(key:property:)` (`x-own` into
  `ownDefault`, `x-inherits` into `inherits`), `shape(_:)` (the `anyOf` of a role `enum` and the
  colour pattern into `.roleColour`).
- `ConsoleCore/SettingValues.swift`: `value(in:)` (`.same(own ?? default, isSet:)`) and
  `drawnColour` (held value, else `role`, else `ownDefault`).
- `ConsoleCore/SceneColours.swift`: `DrawnColour.caption`; role labels from `block.colors`'
  `x-label`. `HexColour.hex` writes uppercase.
- `ConsoleCore/SchemaFacts.swift`: `inheritedValue(of:scene:installed:)`, `installSettings`.
- `ConsoleCore/PanelScenes.swift`: `load()` (`client.install`, `installed`, `viewing`), `display`,
  `save`, `unpairing`, `fail`; the class runs from line 8 to 293.
- `ConsoleCore/HostClient+Install.swift`: `InstallBlockState`, `InstallWritten`, `install`,
  `installBlocks`, `writeInstall` (restart transport, `.stale`, `.conflict`, `.invalid`).
- `ConsoleCore/PanelInput.swift`: `load`, `write`, `refused`, `Note`.
- `ConsoleCore/Sources/HostAPI/openapi.json`: `InstallWritten` (`applies` required, enum of
  `on_restart`, `on_reload`, `restarted` and `on_start`).
- `AudioVueConsole/PanelWindow.swift`: `detail`, `SamplePage`, `PanelSection`.
- `AudioVueConsole/Sketches/SketchPages.swift`, `SketchData.swift`, `sketch.json`.
- `ConsoleCore/Tests/ConsoleCoreTests/LiveHelperTests.swift` (`helper`, `request`, the digest
  check); `PanelScenesTests.answers` (the fake `.install` route); `FakeTransport.Route`
  (`writeInstall(_:)` exists); `HostClientInstallWritesTests`.
- `ConsoleCore/RenderedLayer.swift`: `unfit` is decoded per layer.
- The schema fixture: `block.colors` labels `bar_body` "Bar body"; only `install.display` is named
  by `x-inherits`.
- audio-vue, from the checkout: `json_schema()`'s `card.logo`, `block.display`, `install.display`;
  `git status` and `git log`; `tools/refresh-render-bundle.sh --check` (manifest and
  `src/schema/declare.py` differed).
- audio-vue specs read: `screensaver` (the `native-logo` delta, then the standing spec after
  `aebdbf1`), `logo` ("The logo's colours are the card's own"), `display-sleep` ("Two timeouts set
  the stages", "A zero skips only its own stage", "A scene may override the timeouts and the
  screensaver"), `settings-store` ("A stale write is refused", "An install write says when it
  applies"), `settings-schema` (the scene's `saver_after_min` scenario), `native-logo` design D4 and
  D6, alignment F7. Open changes: `render-shed` (delta to `scene-render`).
- KB: `pitfalls.md` (install values, the popover `Form` crash, the chain write), `project-map.md`
  (Sketches), `open-questions.md` (nothing on display or colours), `product.md` (the gate's limits).
- Removals searched: `SketchDisplayPage`, `SamplePage`, `SketchData`, `SketchPanel`, `sketch.json`,
  `HostClient.install(at:token:)` in `AudioVueConsole/`, `ConsoleCore/`, `project.xcproj` and the KB.

## Findings

- **F1. A second copy of the display block** (resolved, design)
  - Plan: the first draft had a `PanelDisplay` model like `PanelInput`, pushing each write into
    `PanelScenes.installed`.
  - Code: `pitfalls.md` (2026-11-09), "The installed capture rate has one model", rules out a
    second copy of an install value in another model. `PanelScenes.installed` already holds the
    block the scenes inherit from.
  - Goes to: design D2, D4, and tasks 3.2 and 3.3.
  - Resolution: `PanelScenes` keeps the block's revision and writes it. The page holds only its
    note.

- **F2. `PanelScenes` is at the gate's type limit** (resolved, design)
  - Plan: D2 adds the revisions and `writeInstall` to `PanelScenes`.
  - Code: the class spans lines 8 to 293, 285 lines against the gate's 300. The write and its
    stale re-read add about 30.
  - Goes to: design D2, task 3.3.
  - Resolution (maintainer, 2026-11-24): the extension file. The write goes in `PanelScenes+Install.swift`, an extension
    by concern as `HostClient+Install.swift` and `LibraryTiles+Setup.swift` are. That needs
    `address`, `client`, `pairing` and `unpairing(_:)` internal rather than private, within
    `ConsoleCore` only.

- **F3. Removing the sketch leaves `SamplePage` and `SketchData` with no use** (resolved, task)
  - Plan: task 4.2 dropped `.display` from `SamplePage`'s switch.
  - Code: `SamplePage` switches over every `PanelSection`, so `.display` cannot simply be dropped.
    Its `if let panel` would then bind a panel nothing uses. `SketchData.panels` has no other
    reader, and History shows `SketchLaterPage`, which reads no data.
  - Goes to: task 4.2, and task 5.3 for `project-map.md` lines 49 and 56.
  - Resolution: `.history` goes straight to `SketchLaterPage`. `SamplePage`, `SketchData.swift`
    and `sketch.json` go.

- **F4. `native-logo` was archived during this review** (resolved, proposal)
  - Plan: the proposal named `native-logo`'s deltas until audio-vue archived it.
  - Code: audio-vue `aebdbf1` archived it as `2026-11-24-native-logo`. `logo`, `screensaver`,
    `card-colours` and `panel-screen` now hold its requirements.
  - Goes to: the proposal's Impact.
  - Resolution: the proposal names the standing specs.

- **F5. The mirror differed from audio-vue's bundle** (resolved, design)
  - Plan: the bundle the app carries is the panel's.
  - Code: `refresh-render-bundle.sh --check` named `manifest.json` and `src/schema/declare.py`. The
    edit was uncommitted in audio-vue, and `aebdbf1` committed it. Every build mirrors it.
  - Goes to: design Risks; task 5.1 checks against the running panel.
  - Resolution: nothing to change here. A difference task 5.1 finds is listed for the maintainer
    to deploy.

- **F6. audio-vue's open `render-shed` changes `scene-render`** (resolved, no effect)
  - Plan: the change relies on `audio-vue:render-bundle` and the helper's `render` answer through
    task 1.3.
  - Code: `render-shed` adds `shed` to each plate layer and raises the helper's protocol number. No
    console code reads that number. `RenderedLayer.layers` ignores fields it does not know. audio-vue
    holds no code for it yet.
  - Goes to: nothing. `editor-conveniences` owns reading `shed`.

- **F7. Callers the review did not list** (resolved, task; found during apply, 2026-11-24)
  - Plan: task 2.2 named `BlockSection` as `BlockSettingRow`'s caller, and the removal search for
    `HostClient.install(at:token:)` found no test.
  - Code: `ColourGroups` (`ColourSettings.swift`) and `BackdropEditor` also make `BlockSettingRow`,
    and `HostClientScenesTests.theInstallBlocksAreReadByName` called `install(at:token:)` across a
    line break the search pattern missed. The two `PanelScenes` install tests took
    `PanelScenesTests` past the gate's 300-line type limit.
  - Goes to: tasks 2.2, 3.2 and 3.3.
  - Resolution: both callers pass the `colours` they already hold. The `install` test went with
    the function, since `theInstallBlocksAreReadWithTheirRevisions` reads the same answer. The
    install tests are their own suite, `PanelScenesInstallTests`, beside `PanelScenes+Install.swift`.

- **F8. The Display rows crashed the app as the window went inactive** (resolved, code; found
  in the maintainer's run, 2026-11-24)
  - Plan: task 2.2 gave scene block colours the card's well and role menu, unchanged.
  - Code: `NSColorWell` in `ColourWell` took whatever width its row left. In the Display rows
    beside a long label, the form's layout cycled and placed the label at NaN, a fatal error in
    `GroupedFormRowLayout`.
  - Goes to: `ColourWell.sizeThatFits` (`SettingControls.swift`), `SceneMetrics.colourWellWidth`,
    `pitfalls.md`.
  - Resolution: every well is a fixed 64 x 24. The maintainer ran it: no crash on leaving the app
    or on the Image source.

## Questions for the maintainer

None open. F2 was ruled 2026-11-24: the extension file.

## Confirmed

- `SettingDeclaration.init(key:property:)` reads the four `saver_*_color` settings and the logo
  card's four colours as `.roleColour`, with their `x-own` defaults in `ownDefault` and no `role`.
- `drawnColour(nil, …)` on such a setting gives its own colour with no role, so `DrawnColour.caption`
  is nil and no role is named. This is the `card-settings` scenario "A colour of the card's own".
  The logo card's Colours group needs no code.
- `BlockSettingRow` passes no `drawn` and no `roles`, so the scene's colour rows show an empty well
  and an empty menu today, as the handoff said.
- `BlockSection` already holds the scene's `SceneColours` (`facts.colours`), which D1's builder needs.
- The two `saver_scene_*` settings are booleans with a default of false. `SettingControl` draws a
  `Toggle` from `shown?.boolValue ?? false`.
- `saver`, `saver_after_min` and `sleep_after_min` in the scene's block inherit from
  `install.display`. `inheritedValue` reads `installed["display"]`, else the install default, so a
  write held in `installed` shows in a scene at once.
- `install.display` declares `saver` (`bounce`, default `bounce`) and the two timeouts (minimum 0,
  default 0, step 1, unit `min`), all with defaults. `SettingRow` draws a picker and two number
  fields with no Use Default while unset.
- The host's `InstallWritten` requires `applies`. `settings-store` says a `display` write applies at
  the next start and leaves the running panel as it is.
- `HostClient.writeInstall` maps a stale write to `.stale(currentRev:)`, a calibration refusal to
  `.conflict`, and an invalid block to `.invalid`.
- `FakeTransport.Route.writeInstall(_:)` exists, and `PanelScenesTests.answers` already serves a
  `display` block at revision 2.
- `HostClient.install(at:token:)` has one caller, `PanelScenes.load()`, and no test or KB entry
  names it.
- `HexColour.hex` is uppercase, so `#1AD9CC` is what the well shows. `block.colors` labels
  `bar_body` "Bar body", so the caption reads "Uses the scene's Bar body colour".
- The mirror already holds `src/logo.py` and no `assets/` SVG.
- `RenderedLayer` decodes `unfit` per layer, which task 1.3 checks.
- The project's one folder entry is `AudioVueConsole`, so `DisplayPage.swift` joins the target
  without a project edit. Deleting `sketch.json` removes it from the bundle the same way.
