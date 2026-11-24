# Proposal

## Why

audio-vue's `bar-card-segments` cuts a meter's decibel-unit level field into segments of a size in
the field's unit, and gives the meter's `scales` block a `segment` column, a per-key product size in
`x-keys`, and rules the inspector does not yet check (`meter-segment-size-handoff.md`). A row may
now also give neither end, keeping the product's range. Today the inspector refuses a row with no
ends, has no control for the size, and would let through a size the panel refuses.

## What Changes

- Each Scales row gains a Segment picker of the column's choices. Empty means the product's size,
  which the picker shows as its placeholder. On a field segmented by count, which the product gives
  no size, the picker is disabled and says why.
- Low and High left blank show the field's product range as their placeholders.
- A row may give both ends or neither. A row with neither keeps the product's range, so a row may
  set only a segment size or only an anchor. One end alone is still refused, in the panel's new
  words.
- The row's check gains the panel's two size rules. The size, set or else the product's, must
  divide the span, set or else the product's, and a refusal names the sizes that would. A field
  segmented by count takes no size.
- Clearing every field of a row removes its key. Clearing only the ends keeps a size or anchor set
  alone.
- The scene repair treats a key that needs another, as the export now declares with
  `dependentRequired`, like a required key: an entry missing it cannot be made whole.
- The schema fixtures are refreshed from audio-vue's export. The four bar cards' new `style` and
  `segment_db` are choices the inspector already shows, so nothing is added for them.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `card-settings`: a keyed block's row shows a segment size and the product's range and size as
  placeholders. Its check takes both ends or neither and the two size rules, and a cleared row is
  one with no field set.
- `scene-repair`: a key another key depends on counts as required where that key is held.

## Impact

- `ConsoleCore/Sources/ConsoleCore/KeyedBlock.swift`: `Key` reads the product's `segment` and the
  column's sizes, `Span` and `edit` carry `segment`, and `SpanRefusal` gains the new cases and
  wording.
- `AudioVueConsole/Scenes/KeyedBlockRows.swift` and `CardSettings.swift`: the Segment picker, the
  placeholders, and the span written with its size.
- `ConsoleCore/Sources/ConsoleCore/SceneShape.swift`: `dependentRequired` judged in the object walk
  and listed in its keywords.
- Fixtures `schema-trimmed.json` and `meter-schema.json`, and `KeyedBlockTests` and
  `SceneShapeTests`.
- The bar cards' code changed on the panel, so the renderer's card code matches the panel's only
  once audio-vue is deployed to it and the app is rebuilt (`card-code`, unchanged).
- Referenced specs relied on: `audio-vue:meter` (its open change `bar-card-segments` carries the
  size rules), `audio-vue:settings-schema`.
