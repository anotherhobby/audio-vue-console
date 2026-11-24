# Tasks

## 1. Fixtures

- [x] 1.1 Refresh `ConsoleCore/Tests/ConsoleCoreTests/Fixtures/schema-trimmed.json` from audio-vue's `json_schema()` as `commands.md` (2026-11-23) records: whole, its `x-categories` replaced by the fixture's own, `json.dumps(indent=2)` plus a newline. Write `Fixtures/meter-schema.json` as the export's `$defs["card.meter"]` in the file's existing form (`indent=1`, sorted keys, matching its current layout). Verify: `scales.x-keys` in both files carries `segment` (2.5 on `program_loudness`, null on `correlation`), and each key's properties hold `segment` with eight `enum` values and `dependentRequired` in place of `required`. The suite is run in 2.4 and 3.2, once the code reads the new shape.

## 2. The keyed block's check (`ConsoleCore`)

- [x] 2.1 In `KeyedBlock.swift`, give `Key` `segment: Double?` from the `x-keys` entry and the block `sizes: [Double]`, the `.choice` values of the first key's `segment` setting (design D1). Remove `Key.required`, which the export no longer fills; its only other reference is `KeyedBlockTests.theScalesBlockIsKeyedInTheExportsOrder`. Verify in that test: 22 keys, `program_loudness.segment == 2.5`, `correlation.segment == nil`, `sizes == [0.5, 1, 1.25, 1.5, 2, 2.5, 3, 5]`, and correlation's settings `lo, hi, anchor, segment`.
- [x] 2.2 Add `segment` to `Span` and `span(of:in:)`. Replace `edit(_:key:lo:hi:anchor:)` with `edit(_:key:span:)`, running design D2's five checks in order against the effective range and size, and storing `segment` where set. A row with no field set removes the key. Rename `SpanRefusal.missingEnd` to `.oneEnd` and add `.countField` and `.notDividing(size:span:dividing:)`, with the texts of D2 to D4, numbers in `:g` form. Verify with `KeyedBlockTests`: every scenario of the delta's "A keyed block's span is checked before it is stored" and "A cleared row removes its key and an empty block is unset". That means one end (new text), an anchor alone accepted at 0.5 and refused at 2 on correlation, a size alone stored on `true_peak_max` (1.5, 63 / 1.5 = 42), 1.5 refused on `loudness_range` with "0.5, 1, 1.25, 2, 2.5 and 5", -45 to 3 refused on `program_loudness` with "0.5, 1, 1.5, 2 and 3", a size refused on correlation, and clearing ends keeping `segment` 2 alone. Update the existing calls at lines 46 to 148 to the new signature.
- [x] 2.3 A `dividing` helper on `KeyedBlock` lists the block's `sizes` that divide a span, joined as D4 says, or "no segment size divides it". Verify in `KeyedBlockTests`: 48 gives "0.5, 1, 1.5, 2 and 3 divide it", 20 gives "0.5, 1, 1.25, 2, 2.5 and 5 divide it", and 0.7 gives "no segment size divides it".
- [x] 2.4 Run `cd ConsoleCore && xcrun swift test --disable-xctest --filter KeyedBlockTests` and verify it passes.

## 3. The repair walk

- [x] 3.1 In `SceneShape.swift`, add `dependentRequired` to `SceneShape.keywords` and `ShapeWalk.objectKeywords`. In `fitObject`, an object where a kept key's dependents are not all kept answers nil, like a missing required key (design D8). Verify in `SceneShapeTests`: the keyword test passes on the refreshed fixture, a meter card whose `scales` gives `program_loudness` only `lo: -50` beside a whole `peak_to_loudness` span needs a repair, and the repair leaves `peak_to_loudness` alone in `scales`.
- [x] 3.2 Run `cd ConsoleCore && xcrun swift test --disable-xctest` and verify the whole suite passes.

## 4. The row (`AudioVueConsole`)

- [x] 4.1 In `KeyedBlockRows.swift`, add `segment: Double?` to `Draft`, seeded from the stored span. Add a Segment `Picker` after Anchor (design D5): an empty choice labelled with the key's product size, then the block's sizes with the `segment` setting's `x-choice-labels`. It commits the row on change. On a key whose `segment` is nil it is disabled, shows "Count", and its help says the field's segments are a count, set by Segments (D6). Low and High take `key.range` as placeholders (D7). `commit` builds a `Span` with `segment` and calls `edit(nil, key:span:)`. Verify the app builds with the Xcode MCP `BuildProject`.
- [x] 4.2 In `CardSettings.swift`, `blockEdit` passes the whole `Span` to `edit(_:key:span:)`. Verify the app builds, and update its doc comment's design reference to this change.
- [x] 4.3 Run the quality gate by hand on every Swift file changed by a script (`commands.md`, 2026-11-22) and verify each reports `clean`, or raise its finding as `.claude/CLAUDE.md`, "Quality Gate", says.

## 5. On the panel

- [x] 5.1 Maintainer's run on the proving panel, once audio-vue's `bar-card-segments` is deployed to it and the app rebuilt (the renderer's card code then matches, Status shows Ready). Check five things. A meter on Program Loudness shows Low -60, High 0 and Segment 2.5 as placeholders. Picking 1.5 on True-peak Max alone draws 42 segments. -45 to 3 on Program Loudness is refused with the five sizes named. Correlation's Segment is disabled. An RTA's, Peak & RMS's and Dynamics' `style` and `segment_db` show as pickers with `segment_db` disabled in the fill and tick styles.

## 6. Records

- [x] 6.1 Update `.claude/kb/agent/host-contract.md` so keyed-block rows carry a per-key product `segment` beside `range` and `anchor`, a row takes both ends or neither (`dependentRequired`), and the sizes come from the column's `enum`. Update `working-notes.md` with this change's state, and remind the maintainer to delete `meter-segment-size-handoff.md`. Verify by reading the notes against the export.

## Workflow follow-up

- Verify and archive the change after the maintainer's run.
