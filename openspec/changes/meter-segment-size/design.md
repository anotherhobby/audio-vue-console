# Design

## Context

`KeyedBlock` (`ConsoleCore/Sources/ConsoleCore/KeyedBlock.swift`) reads the meter's `scales` from
the export: each `x-keys` entry gives a `Key` (name, label, unit, range, anchor), with the key's own
`SettingGroup` and `required` from `properties[name]`. `edit(_:key:lo:hi:anchor:)` checks a row and
returns the next block. It refuses a row without both ends, so an anchor alone is refused today.
`KeyedBlockRows` (`AudioVueConsole/Scenes/KeyedBlockRows.swift`) draws three text fields per row and
commits on submit. `CardSettingsList.blockEdit` (`CardSettings.swift`) applies the span to each
selected card's block.

The export now gives each `x-keys` entry a `segment` (a number, or null for a field segmented by
count) and each key's properties a `segment` setting with an `enum` of eight sizes. It drops
`required` for `dependentRequired: {lo: [hi], hi: [lo]}`. The scene repair walk
(`SceneShape.swift`, `ShapeWalk.fitObject`) judges `required` and lists every keyword it knows in
`SceneShape.keywords`, which `SceneShapeTests` holds the fixture to.

## Goals / Non-Goals

**Goals:**
- Check a row as the panel's `_span` and `_scale_refusal` do, from the export alone.
- Read the sizes and the product's size from the schema, with no literal in production code.

**Non-Goals:**
- Any control for the bar cards' `style` and `segment_db`. They are `enum` settings the inspector
  already shows as pickers.
- Checking a stored scene's scales against the new size rules when it opens. A stored span the
  product's size does not divide is refused by the helper, shown as any refusal (`scene-repair`,
  "What the schema cannot judge is left to the helper's refusal"). The user fixes it in the row.

## Decisions

**D1. `Key` gains `segment: Double?` and the block's `sizes: [Double]`.** `segment` is the entry's
product size, nil for a count field. `sizes` is the column's choices, read from the `segment`
setting's `.choice` shape in a key's `SettingGroup`, so `dividing` lists them in the schema's order.
The alternative was a Swift copy of `SEGMENT_SIZES`. That is a literal of the host's, which the
project rules out.

**D2. `Span` gains `segment`, and `edit` takes a `Span`.** `edit(_:key:span:)` replaces the
four-number signature, since `Span` already names the row's parts. Its checks run in the panel's
order, the first failing one returned:
1. One end alone: `.oneEnd`, "a scale needs both a low and a high end, or neither".
2. `hi` not above `lo`: `.notAbove`, as now.
3. The effective range is the row's ends, or else the key's `range`. The anchor, set or else the
   product's, must lie in it: `.anchorOutside`, as now.
4. A size on a key whose `segment` is nil: `.countField`, "its segments are a count, so it takes no
   segment size".
5. The size, set or else the key's, must divide the effective span, with the panel's tolerance
   (`math.isclose(count, round(count), abs_tol=1e-9)`): `.notDividing(size:span:dividing:)`, "a
   segment of 2.5 does not divide 48; 0.5, 1, 1.5, 2 and 3 divide it".

A row with no field set removes the key, as now, extended to `segment`. `.missingEnd` is renamed
`.oneEnd` for its new meaning.

**D3. One wording for a size that does not divide.** The panel refuses a set size on set ends with
its block rule ("segment: 2.5 does not divide 48; …") before its card check could ("a segment of 2.5
does not divide 48; …"). The row shows the card's wording for both, since it names the size whether
or not the size was set. Both name the same sizes.

**D4. Numbers in the new refusals follow Python's `:g`.** "48", "2.5", "1.25", never "48.0". The
existing refusals keep Python's `str(float)` ("-5.0"), which they match today. The list joins with
", " and " and " before the last, and reads "no segment size divides it" when empty, as `dividing`
does.

**D5. The Segment picker commits at once.** A `Picker` over `key.settings`' `segment` choices with
the `x-choice-labels`, plus an empty choice labelled with the product's size ("2.5, the product's").
A change commits the row at once, with the text fields' drafts as typed. A text field still commits
on submit. A refused pick stays in the row as a draft beside its refusal, as a refused typed end
does, and nothing is stored.

**D6. A count field's picker is disabled, not hidden.** It keeps every row's columns aligned.
Disabled, it shows "Count" and its help says the field's segments are a count, set by Segments. The
hand-off left this choice to the console.

**D7. Blank ends show the product's range.** Low and High take `key.range` as placeholders, in the
row's number format, and Anchor keeps the product's anchor or "Product".

**D8. The repair walk judges `dependentRequired` like `required`.** In `fitObject`, an object holding
a key whose dependents are not all kept answers nil, so the parent removes it, recorded as for a
missing required key. `dependentRequired` joins `SceneShape.keywords` and `objectKeywords`. The
alternative, unsetting the lone end, would keep a partial entry the user never wrote as a whole. An
entry missing a required key is already removed, so removing matches.

## Risks / Trade-offs

- [A picker commit carries unsubmitted text] → The drafts are part of the row the user sees. A
  refused draft refuses the pick too, shown beside the row, so nothing is stored silently.
- [Floating-point division] → Sizes and ends are decimal halves and quarters, and the tolerance is
  the panel's. A test covers 63 / 1.5 and 20 / 1.25.
