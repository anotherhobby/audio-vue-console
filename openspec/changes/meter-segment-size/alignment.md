# Code alignment

## Read

Pass of 2026-11-24, against `dev` at `d8e67bc` and audio-vue at `46a8c8a`.

- `tools/refresh-contract.sh --check`: the saved contract matches audio-vue's. The schema fixture
  is a version behind the export.
- `ConsoleCore/Sources/ConsoleCore/KeyedBlock.swift`, whole: `Key`, `init?(property:)`, `Span`,
  `span(of:in:)`, `edit`, `SpanRefusal`. The checks, their order, and the clear-row path.
- `ConsoleCore/Sources/ConsoleCore/SettingGroup.swift`: `shape(_:)` (`enum` before `x-keys`),
  `UnusedCase`, `unusedCases`, `choiceLabels`.
- `ConsoleCore/Sources/ConsoleCore/JSONValue.swift`, `init(from:)`: integers decode before decimals.
- `ConsoleCore/Sources/ConsoleCore/SceneShape.swift`: `keywords`, `objectKeywords`, `fitObject`.
- `AudioVueConsole/Scenes/KeyedBlockRows.swift`, whole: `Draft`, `reseed`, `row`, `field`, `commit`.
- `AudioVueConsole/Scenes/CardSettings.swift`: `rowView`, `blockEdit`, and the `.choice` picker in
  the row control.
- `ConsoleCore/Tests/ConsoleCoreTests/KeyedBlockTests.swift`: every `edit` call (lines 46 to 148)
  and the `required` expectation (line 40). `SceneShapeTests`: the keyword test (lines 91 to 99).
- Fixtures: `schema-trimmed.json` is a version behind, and `meter-schema.json` has no `segment`.
- audio-vue `src/cards/meter/manifest.py`: `SEGMENT_SIZES`, `dividing`, `_span`, `_divides`,
  `SCALE`, `SEGMENTS`. `src/cards/meter/card.py`: `checked_scales`, `_scale_refusal`.
  `src/cards/bar_styles.py`: `divides`. `src/schema/export.py`, lines 100 to 115.
- The live export: `card.meter` and `card.meter_vertical` `scales` (22 keys each, each with
  `segment`), the `segments` `x-unused-when`, and `card.rta_bars.segment_db`.
- `audio-vue:meter` and `audio-vue:settings-schema`, read in full. audio-vue's open changes:
  `bar-card-segments` (deltas to `meter`, `card-bar-styles`), `card-minimum` (`meter`: "Labels
  drop before marks" only), `goniometer-steady-title` and `cards-without-text` (no deltas touching
  this).
- Our `card-settings` (the four keyed-block requirements) and `scene-repair` (all requirements).
- KB: `pitfalls.md` "A keyed block's schema nests its settings per key…", `open-questions.md`, and
  `host-contract.md`'s keyed-block line.
- Each task 1.1 to 6.1 was read against the code as the tasks before it leave it. Removal searched:
  `Key.required` (`KeyedBlock.swift:20,52`, `KeyedBlockTests.swift:40`, nothing in the app or KB),
  assigned to 2.1. `SpanRefusal.missingEnd` (`KeyedBlock.swift`, `KeyedBlockTests.swift:47-48`) is
  assigned to 2.2. The old `edit` signature's callers (`KeyedBlockRows.swift:136`,
  `CardSettings.swift:123`, the tests) are assigned to 4.1, 4.2 and 2.2.

## Findings

- **F1. The size rules are in an open audio-vue change** (resolved)
  - Plan: the row's checks follow `audio-vue:meter`.
  - Code: `audio-vue:meter` still says a scale gives a range and an anchor. The size rules and
    "both ends or neither" are deltas in the open `bar-card-segments`, built at `46a8c8a` and not
    yet archived.
  - Goes to: design. The deltas match the built code (`_span`, `_scale_refusal`) and are what the
    hand-off asks for, so the plan follows them. If `bar-card-segments` changes before it is
    archived, audio-vue's session hands that off.
- **F2. audio-vue's change names our `card-settings`** (resolved)
  - Plan: modifies `card-settings`.
  - Code: `bar-card-segments`' Impact names `audio-vue-console:card-settings` and `card-code`.
  - Goes to: none. That session wrote the hand-off this change answers, so it already knows.
- **F3. No audio-vue spec states the keyed block's export form** (resolved)
  - Plan: reads `x-keys` `segment`, the column's `enum`, and `dependentRequired`.
  - Code: `audio-vue:settings-schema` states `x-keyed-by` only. `x-keys`, its `range`, `anchor` and
    `segment`, and `dependentRequired` exist only in `export.py` (lines 100 to 115) and the
    hand-off. `meter-scales-editor` relied on the same unstated form.
  - Goes to: the maintainer's question Q1. It does not change this change's specs or tasks.
  - Resolution: Q1 answered yes (maintainer, 2026-11-24). `../audio-vue/keyed-block-schema-handoff.md`
    asks `settings-schema` to state the form.
- **F4. The repair walk would fail its keyword test** (resolved)
  - Plan, before this review: the proposal named no `scene-repair` change.
  - Code: `SceneShapeTests` holds the fixture to `SceneShape.keywords`, which lacks
    `dependentRequired`. Once `required` is gone, `fitObject` would let a lone `lo` through.
  - Goes to: requirement. Added as the `scene-repair` delta (design D8, task 3.1). It removes the
    entry, matching "A repair removes an entry it cannot make whole". A lone end was already
    refused under `required`, so no stored scene that passed before is newly repaired.
- **F5. One refusal wording for a size that does not divide** (resolved)
  - Plan: the row speaks "in the card's words".
  - Code: the panel gives the block rule's wording ("segment: 2.5 does not divide 48; …") where the
    size and both ends are set, and the card's ("a segment of 2.5 does not divide 48; …") where
    either comes from the product.
  - Goes to: design D3. The row uses the card's wording for both. It names the same sizes.

## Questions for the maintainer

- **Q1 (F3).** Should audio-vue's `settings-schema` state the keyed block's export form (`x-keys`
  with `range`, `anchor` and `segment`, and `dependentRequired`)? Recommended: yes, as one line in
  the next hand-off to audio-vue. Not blocking, since the export and the hand-off agree.

## Confirmed

- `shape(_:)` reads `enum` first, so the bar cards' `segment_db` and `style` are `.choice` and show
  as pickers with their `x-choice-labels`. `segment_db`'s `minimum` and `maximum` beside its `enum`
  change nothing.
- `JSONValue` decodes 1.0 as `.integer(1)` in the export and in a stored scene alike, so a stored
  `segment_db` of 1 matches its choice. The row's picker compares `Double`s through `numberValue`
  (D5), so it does not depend on this.
- The `segments` count's second unused case is keyed on `field`, with 17 field names. It decodes
  through `unusedCases` with no change.
- Every key's properties carry `segment`, count fields included, so `sizes` reads from any key (D1).
- `card.meter_vertical`'s `scales` has the same 22 keys with `segment`, so the vertical meter's rows
  follow with no further work.
- The `pitfalls.md` held item, that the card checks the product's anchor, is kept by D2 step 3,
  which now also uses the product's range.
- Computed: 63 / 1.5 = 42, 20 / 1.5 is not whole, 48 / 2.5 is not whole. The sizes dividing 48 are
  0.5, 1, 1.5, 2 and 3, and those dividing 20 are 0.5, 1, 1.25, 2, 2.5 and 5. 50 / 2 = 25 and
  60 / 2 = 30. All agree with `dividing` run on the panel's code.
