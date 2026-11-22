# Code alignment

## Read

- 2026-11-21, console: `ConsoleCore/Sources/ConsoleCore/SettingGroup.swift` (`SettingDeclaration`,
  `Shape`, `shape(_:)`: an object is `.other`, the `x-keys` form is not read).
- 2026-11-21, console: `ConsoleCore/Sources/ConsoleCore/SettingValues.swift` (`written`, `json`
  private, `stepped`, `value(in:)`; `written` returns nil for a shape with no range).
- 2026-11-21, console: `ConsoleCore/Sources/ConsoleCore/SceneLayoutEdits.swift`
  (`setting(_:to:on:)`, `unsetting`, `changingSettings(of:_:)`: the one place a card's settings change).
- 2026-11-21, console: `ConsoleCore/Sources/ConsoleCore/SceneEditor.swift` (`set`, `useDefault`,
  `commit`, `commitContent`: an unchanged result adds no undo step).
- 2026-11-21, console: `ConsoleCore/Sources/ConsoleCore/JSONValue.swift` (cases `object`,
  `integer`, `decimal`).
- 2026-11-21, console: `AudioVueConsole/Scenes/CardSettings.swift` (`CardSettingsList`, `row`,
  `edit`, `SettingRow`) and `AudioVueConsole/Scenes/SettingControls.swift` (`SettingControl`, its
  exhaustive switch with `.other, .colours`).
- 2026-11-21, console: `SettingGroup.value(of:across:declaredBy:)` and `SettingGroup.unusedReason`
  (the mixed and unused displays the keyed block reuses).
- 2026-11-21, console tests: `SettingGroupTests.swift`, `SchemaFactsTests.swift` (line 217 asserts
  `colours` is `.other`, an array, not an object: unaffected), `Fixtures/schema-trimmed.json`.
- 2026-11-21, audio-vue (uncommitted, working tree): `src/cards/meter/card.py` (`checked_scales`,
  `_span` via `block`), `src/cards/meter/manifest.py` (`SCALE`, `_span`), `src/schema/export.py`
  (`setting`, `_object`, the `block` shape `{"type": "object"}`), via `export.json_schema()`, whose
  output for `card.meter.properties.scales` is the `x-keys` form the handoff describes.
- 2026-11-21, audio-vue specs: `openspec/specs/settings-schema` has no `x-keys` requirement
  (`openspec show settings-schema --type spec --store audio-vue`); `meter-segments`'s spec delta
  names no `x-keys` or block form (`openspec/changes/meter-segments/specs/meter/spec.md`).
- 2026-11-21, console: `tools/refresh-render-bundle.sh` (mirrors audio-vue's working tree; `--check`
  listed five differing files, including `src/schema/declare.py` and `src/cards/meter/card.py`).
- Tasks read and each removal searched: no removal in this change. The only symbol edited is
  `SettingControl`'s switch (adds `.keyed`), `SettingDeclaration.json` (made internal), and
  `SceneLayout`/`SceneEditor` (additions). Searched for `Shape` cases and `.other` in
  `AudioVueConsole/` and `ConsoleCore/` (`CardSettings.swift:208`, `SceneSettingsTab.swift`
  unrelated: its `.other` is a tab).

## Findings

- **F1. The anchor rule: the card checks the product's anchor, the spec says "where set"** (open)
  - Plan: `specs/card-settings` "A keyed block's span is checked" says an anchor is checked "where
    set", and its scenario refuses "0 is outside -50 to -5" for a set anchor.
  - Code: `audio-vue/src/cards/meter/card.py`, `checked_scales`: `anchor = values.get("anchor",
    field.anchor)`, so an unset anchor takes the product's and is checked against the new span:
    `"the anchor {anchor} is outside {lo} to {hi}"`. The export's `x-rules` says "where set". The
    card's words differ from the spec's (`_span`'s "{anchor} is outside {lo} to {hi}" is not what
    `checked_scales` reports for this case).
  - Example: `correlation`, product anchor 0 (range -1 to 1), override lo 0.2, hi 1 with anchor blank:
    the card refuses; the spec as written accepts.
  - Goes to: requirement, the maintainer rules first.
  - Resolution: held. See Q1.

- **F2. The export form is not in any spec** (open)
  - Plan: the console reads `x-keys`, `properties`, `required` and `x-rules` from the schema.
  - Code: the form exists only in audio-vue's uncommitted working tree (`src/schema/export.py`,
    `setting`, `_object`); `settings-schema` and `meter-segments`' delta state no block form.
  - Goes to: audio-vue's spec, a requirement there. Not this repository's to write.
  - Resolution: held. See Q2.

- **F3. The build mirrors audio-vue's uncommitted card code** (open)
  - Plan: "The console mirrors the card code at each build ... This is the routine rebuild."
    (handoff step 3.)
  - Code: `tools/refresh-render-bundle.sh` copies audio-vue's `local/render-bundle/` and its
    working tree's `make render-bundle` output; `--check` lists five differing files, all from the
    uncommitted `meter-segments` work. Every app build runs it (`commands.md`).
  - Goes to: maintainer question. The change does not alter the mirror.
  - Resolution: held. See Q3.

- **F4. Refusal words for an anchor differ between the spec and the card** (resolved with F1)
  - Plan: the spec scenario quotes "0 is outside -50 to -5".
  - Code: `checked_scales` reports "the anchor 0 is outside -50 to -5"; `_span` reports
    "0 is outside -50 to -5" for a set anchor only, and it is not reached when `checked_scales`
    runs the product-anchor check. Both come from the card, so the wording follows whichever F1
    decides.
  - Resolution: the spec scenario is kept as written pending Q1; the words are the card's.

- **F5. The number writer for `lo`, `hi` and `anchor` is not available** (resolved in place)
  - Plan: task 1.2 stores the numbers.
  - Code: `SettingDeclaration.written(_:)` returns nil unless the shape is `.number` or `.integer`
    (`SettingValues.swift`), and `json(_:)` is private.
  - Resolution: tasks 1.2 now names `json(_:)` made internal, with the reason. A design-level
    choice, recorded here; no requirement changes.

- **F6. Mixed blocks and the row draft** (resolved in place)
  - Plan: design decision 4 disables the fields when blocks differ, while the spec says a change on
    a mixed block sets each card's own block (scenario "Two meters with different scales").
  - Code: `SettingGroup.value(of:across:declaredBy:)` gives `.mixed`, and `SettingControl` disables
    edits on `edit == nil`; `SceneLayout.changingSettings` changes each card in `ids`, so a
    per-card transform (`changingSetting`, task 2.1) is the code path that meets the scenario.
  - Resolution: design decision 4 disabled the fields on a mixed selection, which the scenario's
    "setting Low gives both cards that low" contradicts. Design decision 4 changed in place: a
    mixed group shows Mixed, its fields are blank, and a commit edits each card's own block through
    the per-card transform. Tasks 3.1 changed to match.

- **F7. Setting the block as a whole would overwrite other cards' keys** (resolved in design)
  - Plan: design decision 3 (transform, not one value).
  - Code: `SceneEditor.set` writes one `JSONValue` to every id (`SceneEditor.swift`, `set`).
  - Resolution: confirmed; the design takes the transform path.

## Questions for the maintainer

- **Q1 (F1). The anchor rule.** The card checks the anchor it will draw with: the one set, or the
  product's when blank. Recommended: match the card. Change the requirement to say "an anchor, set
  or else the product's, lies between lo and hi", and add the scenario "A blank anchor the new span
  excludes is refused" (correlation at 0.2 to 1). The alternative, matching the spec and not the
  card, would let a scene the card refuses be stored by the console; the host would refuse it on
  write, so the user would see a refusal with no reason in the inspector.
- **Q2 (F2). The export form.** Recommended: ask audio-vue's session to put the block form into its
  `settings-schema` spec (keys in `x-keys`, the settings in `properties`, `required`, `x-rules`)
  before the change is archived, so the console's reading is a requirement and not a code detail.
  Until then the console tests run against a saved export fixture from the uncommitted tree.
- **Q3 (F3). The routine rebuild.** Recommended: proceed. The build mirrors audio-vue's working
  tree on every run, so the app built from this checkout will contain the uncommitted meter card.
  That is the card the handoff wants tested; it should be re-mirrored from a committed audio-vue
  before the change is archived.

## Confirmed

- `SettingGroup.shape(_:)` maps an object to `.other` (`SettingGroup.swift`), so an `x-keys`
  object is currently read-only, as the handoff says.
- `SettingValues.written(_:)` returns nil for a shape with no range; the block's `lo`, `hi`,
  `anchor` need `json(_:)` (F5).
- `SceneLayout.changingSettings(of:_:)` changes each card in `ids` with its own dictionary
  (`SceneLayoutEdits.swift`), so a per-card transform is one edit to that helper's callers.
- `SceneEditor.commitContent` adds no undo step where the result is unchanged, so a transform that
  returns its input adds none (task 2.2's verification holds).
- `JSONValue` has `.object`, `.integer`, `.decimal`, so the block and its numbers are representable.
- `SettingControl`'s switch is exhaustive over `Shape` (`SettingControls.swift`): adding `.keyed`
  is a compile-time change, not a silent one.
- `segments` is an integer with a step and its declared unused case, so the existing controls show
  it disabled when `style` is not `segments` (`SettingRow.unused`, `SettingGroup.unusedReason`).
- `show_value` is a boolean, shown by `Toggle` (`SettingControl`, `.boolean`).
- The export's `scales` keys are the 22 in `x-keys`, with ranges and product anchors (run of
  `export.json_schema()`, 2026-11-21).
