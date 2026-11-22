# Tasks

## 1. Keyed block shape and span rules

- [x] 1.1 Add `SettingDeclaration.Shape.keyed(KeyedBlock)` in `ConsoleCore/Sources/ConsoleCore/SettingGroup.swift`, decoded in `shape(_:)` for an object with `x-keys`, and a `KeyedBlock` type (new file `KeyedBlock.swift`) holding one `BlockKey` per `x-keys` entry (name, label, unit, range, anchor), each with `settings` (a `SettingGroup` from `properties[name]`, in its `x-settings` order) and `required`. Verify with a fixture of audio-vue's exported `card.meter` schema, saved as `ConsoleCore/Tests/ConsoleCoreTests/Fixtures/meter-schema.json`, in `KeyedBlockTests`: `scales` decodes as `.keyed` with 22 keys in the export's order, `correlation` has range -1 to 1 and anchor 0, and its settings are lo, hi, anchor with required lo and hi.
- [x] 1.2 Add `KeyedBlock.edit(_:key:lo:hi:anchor:)` in `KeyedBlock.swift`, returning the new block (nil for a removed key or an empty block) or `SpanRefusal` with the three refusals: a missing end, `hi` not above `lo`, an `anchor` outside `lo...hi`. Numbers are stored through the existing `SettingDeclaration.json(_:)`, made internal, since the block's settings declare no range and so `written(_:)` returns nil for them. The anchor check uses the product's anchor where `anchor` is blank, as the card does (see alignment F1, held for the maintainer). Verify in a new `KeyedBlockTests.swift`: each refusal's words, a valid span, clearing both ends removes only that key, clearing the last key returns nil, and an unknown key is refused.

## 2. Per-card edit as one step

- [x] 2.1 Add `SceneLayout.changingSetting(_:on:_:)`, taking a transform from each card's own value to its new value, in `SceneLayoutEdits.swift`, built on `changingSettings`. Verify in the existing layout tests: two cards with different blocks keep their other keys after one row's change.
- [x] 2.2 Add `SceneEditor.editSetting(_:label:on:_:)` in `SceneEditor.swift`, one undo step named `Change <label>`. Verify in `KeyedBlockTests`: one undo restores both cards' blocks, and a transform returning the same value makes no step.

## 3. Inspector rows

- [ ] 3.1 Render `.keyed` in `SettingControls.swift` and `CardSettings.swift` as a `DisclosureGroup` titled with the setting's label, collapsed, with one row per key the cards pick by `x-keyed-by` (`KeyedBlock.keys(picked:)`), set keys first, each row showing the key's label, unit, product range and anchor hint, and fields for Low, High and Anchor. Mixed blocks show Mixed, with blank fields, and a commit edits each card's own block. Verify with `BuildProject` (clean build) and a preview of a meter card with one set key.
- [ ] 3.2 Commit a row on Return (the only commit path built; leaving focus does not commit), through `KeyedBlock.edit` and `SceneEditor.editSetting`; a refusal leaves the card's value and shows its words beside the row. Verify with a preview in each state (valid, missing end, refused anchor) and by the unit tests in 1.2 and 2.2.
- [ ] 3.3 Confirm `segments` is disabled unless `style` is a segmented style (`segment-fill`, `segment-tick`) and `value` is a switch, using the existing controls and unused-case display. Verify in a preview of a meter card with `style` set to `fill`.

## 4. Specs and build

- [x] 4.1 Run `cd ConsoleCore && xcrun swift test --disable-xctest` and confirm the full suite passes (445 tests before this change). Verify: the run reports no failures.
- [x] 4.2 Run `openspec validate meter-scales-editor --strict` and confirm it passes. Verify: the command exits 0.

## Workflow follow-up

- Archive the change once the maintainer has run the app against a meter card with scales set.
- Tell audio-vue's session that the console reads `x-keys`, so its `meter-segments` change can be archived with the export as it is.
