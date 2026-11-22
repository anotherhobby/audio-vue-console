# Code alignment

## Read

2026-11-22:

- `ConsoleCore/Sources/ConsoleCore/SceneSettingsTab.swift`: `blockNames` (Style is
  `["colors", "type"]`), `blocks(on:)` (a named tab takes its blocks in `blockNames` order where the
  schema declares them; Other takes every block no tab names), `settingsTabs` (a tab shows only with
  something on it).
- `AudioVueConsole/Scenes/SceneSettings.swift`: `BlockSection` titles a block from `titles`, else
  its name capitalised; `descriptions` is optional; every other block's settings are
  `BlockSettingRow`s, set and cleared through `SceneEditor.setBlock` / `useDefault(block:)`.
- `ConsoleCore/Sources/ConsoleCore/SettingGroup.swift`: `SettingDeclaration.shape` takes any
  property with `enum` as `.choice`, with or without `type`; `label(of:)` reads `x-choice-labels`
  by index.
- `ConsoleCore/Sources/ConsoleCore/LibraryTiles.swift`: `TileSet.Key` is the scene's whole doc
  without `cards` and `name`, so a `case` edit redraws the tiles.
- `ConsoleCore/Tests/ConsoleCoreTests/SceneSettingsTabTests.swift` and
  `Fixtures/schema-trimmed.json`: the fixture has no `block.case`; the tab test pins Style to
  `["colors", "type"]`.
- audio-vue `schema.export.json_schema()`: `$defs/block.case` has `title`, `label`, `caption`,
  `notice`, each `enum: [all_caps, title_case]`, default `all_caps`, `x-choice-labels`
  `["ALL CAPS", "Title Case"]`, labels "Title case" … "Notice case", `x-settings` in that order.
  Against the fixture, only `style`, `scene` and `block.case` differ.
- `tools/refresh-contract.sh --check`: the saved contract matches the host's.
- audio-vue open change `text-case` (deltas only), and its proposal's Impact.
- KB: `open-questions.md`, `pitfalls.md` (nothing on the Style tab or case);
  `host-contract.md` "Type and typeface" and "Styles" (count five categories).

## Findings

- **F1. `audio-vue:text-case` is an open change, not yet a spec** (resolved)
  - Plan: the proposal relies on `audio-vue:text-case`, `settings-schema` and `styles`.
  - Code: audio-vue's `text-case` is complete and built but unarchived; it adds `text-case` and
    modifies `styles`, `settings-schema` and `card-layout`.
  - Goes to: none. The export read above is what the app builds against; the deltas say what the
    plan assumes. Archive on audio-vue's side changes no wording relied on.
- **F2. audio-vue's change names this repository's `scene-settings`** (resolved)
  - Plan: this change modifies `scene-settings`.
  - Code: audio-vue `text-case`'s Impact names `audio-vue-console:scene-settings`.
  - Goes to: none. This change is the answer to that hand-off; nothing to tell audio-vue.
- **F3. The KB counts five look categories** (resolved)
  - Code: `host-contract.md` "Styles" lists five; "Type and typeface" has no case.
  - Goes to: task. Updated with this change's build (no task number: KB upkeep).

- **F4. A second list orders the blocks** (resolved, found in build)
  - Plan: task 2.1 changed only `SceneSettingsTab.blockNames`.
  - Code: `SchemaFacts.blockOrder` sorts `SchemaFacts.blocks`, and `SchemaFactsTests
    .theScenesBlocksInTheInspectorsOrder` expects the schema's blocks to equal it.
  - Goes to: task. 2.1 adds `"case"` after `"type"` there too.

## Questions for the maintainer

None.

## Confirmed

- Adding `"case"` to Style's `blockNames` removes it from Other with no other change, and Other
  stops showing once nothing else is unplaced.
- The four settings render as pickers labelled from `x-choice-labels`, unset showing `all_caps`,
  with Use Default once set, through the generic `BlockSettingRow`.
- Tiles and the canvas redraw on a `case` edit; the helper draws the case.
