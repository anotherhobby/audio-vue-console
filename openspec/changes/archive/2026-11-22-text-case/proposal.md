# Proposal

## Why

audio-vue's `text-case` adds a `case` block to the scene: one case, ALL CAPS or Title Case, for each
of `title`, `label`, `caption` and `notice`. The app shows a block it does not place under the
Other tab, so `case` sits there as "Case", away from the typeface and the sizes it belongs with.
Case is a typographic choice made once for a scene (audio-vue maintainer, 2026-11-22), so it
belongs on the Style tab beside Text.

## What Changes

- The Style tab lists Colours, then Text, then **Text Case**: the `case` block's four settings, in
  declared order, each a choice labelled as the schema exports it ("ALL CAPS", "Title Case"). A
  scene opened on this host shows no Other tab again.
- The canvas, the library tiles and the panel need nothing from the app: the render helper draws
  each card in the scene's case, and the bundle is mirrored on every build.
- The open `styles` change counts six look categories, Text Case among them, with the same
  This Scene / style / Default source as the others. That is an edit to its proposal, not a delta
  of this change.

Not doing: a per-card case (audio-vue maintainer, 2026-11-22: there is none).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `scene-settings`: the Style tab lists Text Case after Text.

## Impact

- Code: `ConsoleCore/Sources/ConsoleCore/SceneSettingsTab.swift` (the Style tab's blocks),
  `AudioVueConsole/Scenes/SceneSettings.swift` (the section's title and description), and
  `ConsoleCore/Tests/ConsoleCoreTests/SceneSettingsTabTests.swift` with its trimmed schema fixture.
- Planning: `openspec/changes/styles/proposal.md` counts six categories.
- Referenced specs relied on: `audio-vue:text-case` (the four roles and their two cases, ALL CAPS
  the default), `audio-vue:settings-schema` (the scene's `case` block in the export, with
  `x-choice-labels`) and `audio-vue:styles` (`case` is a look category, resolved like the others).
