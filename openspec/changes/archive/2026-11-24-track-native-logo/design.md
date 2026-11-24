# Design

## Context

See proposal.md for why. The code as it stands:

- **A card's role colour.** `CardSettingsList.fromScene` (`AudioVueConsole/Scenes/CardSettings.swift`)
  builds a `FromScene` for a `.roleColour` setting: `drawn` from `SettingDeclaration.drawnColour`
  (`ConsoleCore/SettingValues.swift`, taking the held value, else `role`, else `ownDefault`), and
  `roles` from the declaration's role ids through `SceneColours`. For any other setting it gives
  the inherited value and whose it is.
- **A scene block's setting.** `BlockSettingRow` (`AudioVueConsole/Scenes/SceneSettings.swift`) gives
  `SettingRow` a `FromScene(value:owner:)` only. `SettingControl`'s `.roleColour` case draws
  `ColourWell(hex: fromScene.drawn?.colour.hex …)` and `RoleMenu(roles: fromScene.roles …)`, so a
  role colour in a scene block shows an empty well and an empty menu. `BlockSection` holds the
  scene's `SceneColours` but passes it only to the backdrop and the Colours block.
- **The schema.** `SettingDeclaration.init(key:property:)` reads `x-own` into `ownDefault` and an
  `anyOf` of a role `enum` and the colour pattern into `.roleColour(roles:)`. The host's
  `block.display` declares the four `saver_*_color` settings that way, each with `x-own` and no
  `x-inherits`, and the two `saver_scene_*` settings as booleans defaulting to false. `card.logo`
  declares its four colours the same way. `SchemaFacts.installSettings["display"]` is the
  installation's block: `saver`, `saver_after_min`, `sleep_after_min`.
- **The installation's blocks.** `PanelInput` (`ConsoleCore/PanelInput.swift`) reads the `input`
  block with its revision (`HostClient.installBlocks`), writes it whole on that revision
  (`writeInstall`), and turns a stale write, a refusal and a failure into a `Note`.
  `InstallWritten` keeps `rev`, `chainChanged` and `calibration`. The host's answer also carries
  `applies` (`on_start` for `display`), which nothing reads. `PanelScenes.installed` is each install
  block's document, read once in `load()` through `HostClient.install`, which drops revisions. A
  scene's inherited values come from it. `display` is the only block any scene setting inherits
  from (`x-inherits` in the schema). `pitfalls.md` (2026-11-09) rules out a second copy of an
  install value in another model.
- **The Display page.** `PanelWindow.detail` sends `.display` and `.history` to `SamplePage`, and
  `.display` draws `SketchDisplayPage` (`AudioVueConsole/Sketches/SketchPages.swift`). That page
  shows a sample panel's size, a "Screen saver" picker of Bounce and Off, and a "Sleep when quiet"
  toggle.
- **The bundle.** `tools/refresh-render-bundle.sh` runs on every build and mirrors audio-vue's
  `make render-bundle`. On 2026-11-24 the mirror already held the native-logo bundle (`src/logo.py`,
  no `assets/` SVG). `LiveHelperTests` draws the RTA fixture scene with the real helper and checks
  `hello`'s digest against the mirrored manifest.

## Goals / Non-Goals

**Goals:**
- One rule for what a role colour takes from the scene, whichever list draws it.
- The Display page writes the installation's block as the Capture page writes `input`, with the
  same notes.

**Non-Goals:**
- A Colours disclosure inside the Display section. Four colours and two switches stay in the
  block's one section, in declared order.
- Any change to how a scene block's non-colour settings resolve.

## Decisions

### D1. One `FromScene` builder for a role colour

`FromScene` gains a static builder for a role colour, taking the declaration, the held value, the
scene's blocks as edited and its `SceneColours`. It holds the `.roleColour` branch that
`CardSettingsList.fromScene` holds today. `CardSettingsList.fromScene` calls it, and so does
`BlockSettingRow` for a `.roleColour` declaration, given `colours` by `BlockSection`. Any other
setting keeps the inherited value it is given now.

Alternative: copy the branch into `BlockSettingRow`. That is two copies of the rule `card-settings`
and `scene-settings` now share, and the next change to it would have to find both.

### D2. `PanelScenes` holds the `display` block's one copy and writes it

`PanelScenes.load()` reads `installBlocks` in place of `install`. It keeps `installed` as it is,
and each block's revision beside it. The write goes in `PanelScenes+Install.swift`, an extension by
concern as `HostClient+Install.swift` is. The class is 285 lines against the gate's 300, so its
`address`, `client`, `pairing` and `unpairing(_:)` go from `private` to internal (alignment F2).
A new `writeInstall(_ doc:, block:)` writes on the held
revision through `HostClient.writeInstall`. Where the host stores the write, it replaces the
block's document and revision and returns the `InstallWritten`. On `.stale`, it reads the blocks
again, then rethrows. Because a scene's inherited values and the Display page read the same
`installed`, a write shows in an open scene at once (`panel-display`, "A scene shows the panel's
idle settings as written"). The schema's declarations come from `facts.installSettings["display"]`,
which `PanelScenes` already holds.

Alternatives:
- A `PanelDisplay` model like `PanelInput`. It would hold a second copy of the block beside
  `PanelScenes.installed`, which a write from another Mac would leave behind. `pitfalls.md` rules
  that out after the installed rate went stale that way.
- `PanelScenes.load()` after each write. That reads every scene and image to change one block.

### D3. `InstallWritten` carries when a write applies

`InstallWritten` gains `applies`, an enum of the host's values (`onStart`, `onRestart`, `onReload`,
`restarted`), read from the answer's `applies`. The Display page words `onStart` as "Applies at the
panel's next start." The Capture page's notes are unchanged.

### D4. The page keeps its own note

`DisplayPage` holds its note as view state, set from each write's outcome:
- written, with when it applies;
- changed elsewhere, on `.stale`, with the values shown as `PanelScenes` read them again;
- refused, in the host's words, on `.conflict` or `.invalid`;
- failed, in `ReadFailureText`'s words for the `HostFailure`, otherwise.

A refused token goes through `PanelScenes`' own `onUnpaired`, as its other writes do. Nothing else
reads the note, so it needs no model.

### D5. The page draws each setting with the inspector's `SettingRow`

`DisplayPage` (app target, `AudioVueConsole/DisplayPage.swift`) is a grouped `Form` over
`store.scenes`. It has a Screen section with `PanelScenes.display`, the size the host gives, and a
When Idle section with one `SettingRow` per declaration. Each row's `SettingEdit` writes the block
with the key set, or without it for Use Default, which shows only where the block holds the key. So the timeouts are the inspector's number fields with their unit
and step, and the screensaver is a picker of the schema's choices. The note shows under the
section. While a write is under way, the rows are disabled.

### D6. The logo is checked by the live helper, and the fixture comes from the host

`LiveHelperTests` gains a test that draws a one-card `logo` scene and checks that its plate layer
is drawn, not unfit. The schema fixture is refreshed as `commands.md` records (2026-11-23), keeping
its own `x-categories`. A `SchemaFactsTests` case then holds the `card.logo` and `block.display`
colours to `.roleColour` with their `x-own` defaults.

### D7. A change to the scene's `display` block draws nothing

Added after the maintainer's run (2026-11-24): each step of the screensaver's timeout redrew every
library tile and the whole canvas. `LibraryTiles.Key` was the scene's doc without cards and name,
and `SceneRendering.show` drew everything for a change to any block but `backdrop`
(`scene-settings` design D6). audio-vue reads a scene's `display:` block only into its idle
stages and the screensaver's look (`scene_model`: `scene.display`, `scene.saver_look`), and draws
nothing from it.

`RenderRequest.undrawnBlocks` names the blocks no render reads, `display` alone, with the reason.
`SceneRendering.show` leaves them out of the blocks that changed, and `LibraryTiles.Key` leaves
them out of the settings tiles are held for. The request still carries the whole doc, and saving,
drafts and gallery thumbnails are unchanged.

Alternative: a schema mark for settings that draw nothing. The export has none, and one block
named in one place covers what audio-vue does today.

## Risks / Trade-offs

- [The app's bundle differs from the panel's] Every shared entry that differs draws no card
  (`card-code`). On 2026-11-24 the mirror differed from audio-vue's bundle in
  `src/schema/declare.py`, which audio-vue has since committed (`aebdbf1`) and the next build
  mirrors. → The last task opens the app against the panel and checks that the canvas names no
  difference. If one is named, the maintainer deploys on the audio-vue side.
- [A display write does nothing until the panel restarts] The user may expect the screensaver to
  change at once. → The page says when it applies, in the host's terms. A restart is not the
  client's to make.
- [`bounce` is shown as its id] The schema declares no choice labels for `saver`, so the picker
  shows `bounce`, as the scene's Display section already does. Accepted until audio-vue labels it.
