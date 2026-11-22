# Tasks

## 1. The fixture

- [x] 1.1 Refresh `ConsoleCore/Tests/ConsoleCoreTests/Fixtures/schema-trimmed.json` from audio-vue's
      `schema.export.json_schema()`, whole, keeping the tests' `x-categories`, written with
      `json.dumps(..., indent=2)` and a trailing newline as the file is now. Verify: `$defs/block.case`
      is present, `$defs/scene` names `case`, and `cd ConsoleCore && xcrun swift test --disable-xctest`
      passes apart from the tab test 2.1 changes.

## 2. The Style tab

- [x] 2.1 Add `"case"` after `"type"` in `SceneSettingsTab.blockNames` for `.style`
      (`ConsoleCore/Sources/ConsoleCore/SceneSettingsTab.swift`) and in `SchemaFacts.blockOrder`
      (alignment F4). In `SceneSettingsTabTests`,
      `theKnownBlocksFillThreeTabs` expects `["colors", "type", "case"]` on Style and still no Other
      tab, and a new test reads the `case` block's four settings in declared order (`title`, `label`,
      `caption`, `notice`), each with `choiceLabels == ["ALL CAPS", "Title Case"]` and default
      `all_caps`. Verify: `cd ConsoleCore && xcrun swift test --disable-xctest` passes.
- [x] 2.2 Title the section "Text Case" and describe it in `BlockSection.titles` and
      `BlockSection.descriptions` (`AudioVueConsole/Scenes/SceneSettings.swift`). Verify: `xcodebuild
      -project AudioVueConsole.xcodeproj -scheme AudioVueConsole -configuration Debug build` succeeds.

## 3. The styles change

- [x] 3.1 In `openspec/changes/styles/proposal.md`, count six look categories: the "à la carte"
      bullet and the source list gain Text Case, and the Why's list of what a look is gains the case.
      Verify: `grep -n -i "five" openspec/changes/styles/proposal.md` finds no category count.

## 4. Integration

- [x] 4.1 Run the app against the host, open a scene with nothing selected, and check the Style
      tab shows Colours, Text, Text Case, with no Other tab; set Caption case to Title Case and check
      the RTA's caption is drawn again as "1/3 Oct · Fast". Record what was seen.
      Seen (maintainer, 2026-11-22): as described.

## Workflow follow-up

- Archive the change once 4.1 is recorded.
