# Spec Delta

## MODIFIED Requirements

### Requirement: A keyed block shows the rows of the keys its cards pick

A keyed block SHALL show one row for each key a selected card picks by its picking setting
(`x-keyed-by`), in the block's order, or that setting's default where unset. A key no selected card
picks SHALL have no row. A blank field SHALL show the key's product value as its placeholder,
where the block's keys give one.

Source: audio-vue `settings-schema` (`x-keyed-by`, `x-keys`); maintainer, 2026-11-21. audio-vue
`bar-card-segments` (2026-11-24).

#### Scenario: A scales block

- **WHEN** the user selects a `meter` card whose `field` is Program Loudness
- **THEN** the inspector shows Scales as a group with one row, Program Loudness, with its label, its
  unit and its product range, and no field filled

#### Scenario: Two cards picking different fields

- **WHEN** a `meter` card on Correlation and one on Program Loudness are selected
- **THEN** Scales shows a row for each, in the block's order, and a change to a row applies to each
  card's own scale for that field

#### Scenario: An unset field

- **WHEN** a `meter` card leaves its field unset
- **THEN** Scales shows the row for the field's default, Program Loudness

#### Scenario: A row with a scale

- **WHEN** a meter card's entry sets Program Loudness to a low of -50 and a high of -5
- **THEN** that row shows -50 in Low and -5 in High, and Anchor and Segment show blank

#### Scenario: A blank row's placeholders

- **WHEN** a meter card on Program Loudness sets no scale for it
- **THEN** Low shows -60, High shows 0 and Segment shows 2.5 as placeholders, and none is stored

#### Scenario: A field segmented by count

- **WHEN** a meter card on Correlation is selected
- **THEN** its row's Segment picker is disabled and says Correlation's segments are a count

### Requirement: A keyed block's span is checked before it is stored

A keyed block's row SHALL be checked against the block's span rules before any value is stored:
both ends or neither, `hi` above `lo`, and the anchor and segment size, set or else the product's,
judged on the span, set or else the product's range. A refused row SHALL NOT be stored, SHALL keep
the card's previous value, and SHALL say why beside the row in the card's words.

Source: audio-vue `meter` and `bar-card-segments` (2026-11-24); maintainer, 2026-11-21: match the
card.

#### Scenario: A missing end

- **WHEN** the user types -50 in Low and leaves High blank
- **THEN** the row says "a scale needs both a low and a high end, or neither", the card keeps the
  scale it held, and nothing is stored for the key

#### Scenario: High not above low

- **WHEN** the user types -5 in Low and -50 in High
- **THEN** the row says "must be above the low end -5.0", and nothing is stored for the key

#### Scenario: An anchor outside the span

- **WHEN** the user types 0 in Anchor on a span of -50.0 to -5.0
- **THEN** the row says "the anchor 0.0 is outside -50.0 to -5.0", and nothing is stored for the key

#### Scenario: A blank anchor the new span excludes

- **WHEN** the user sets Correlation to a low of 0.2 and a high of 1 with Anchor blank, where the
  product's anchor is 0
- **THEN** the row says "the anchor 0.0 is outside 0.2 to 1.0", and nothing is stored for the key

#### Scenario: An anchor alone

- **WHEN** the user types 2 in Correlation's Anchor and leaves Low and High blank
- **THEN** the row says "the anchor 2.0 is outside -1.0 to 1.0", and nothing is stored for the key

#### Scenario: A size alone

- **WHEN** the user picks 1.5 for True-peak Max's Segment and leaves Low and High blank
- **THEN** the block stores the key with `segment` 1.5 and no ends, and the canvas draws −60 to +3
  dBTP in 42 segments

#### Scenario: A size alone that does not divide the product's range

- **WHEN** the user picks 1.5 for Loudness Range's Segment and leaves Low and High blank
- **THEN** the row says "a segment of 1.5 does not divide 20; 0.5, 1, 1.25, 2, 2.5 and 5 divide it",
  and nothing is stored for the key

#### Scenario: A span the product's size does not divide

- **WHEN** the user sets Program Loudness to a low of -45 and a high of 3 with Segment blank
- **THEN** the row says "a segment of 2.5 does not divide 48; 0.5, 1, 1.5, 2 and 3 divide it", and
  nothing is stored for the key

#### Scenario: A size on a field segmented by count

- **WHEN** a block reaching the check gives Correlation a segment size
- **THEN** the row says "its segments are a count, so it takes no segment size", and nothing is
  stored for the key

#### Scenario: A span that is accepted

- **WHEN** the user completes a valid span on a row
- **THEN** the block stores the key with its `lo`, `hi` and any `anchor` and `segment` set, and the
  canvas draws the field on that scale

### Requirement: A cleared row removes its key and an empty block is unset

Clearing every field of a row SHALL remove that key from the card's block, so the card uses the
product's scale for that field. Clearing only its ends SHALL keep an anchor or segment size the row
still sets. A block left with no keys SHALL be stored as unset, as if the setting were never set.

Source: Decision (maintainer, 2026-11-21, `meter-segments-handoff.md`). audio-vue
`bar-card-segments` (2026-11-24): a row may give neither end.

#### Scenario: Clearing a row

- **WHEN** a meter card's block sets Program Loudness and Peak to Loudness, and the user clears
  both ends of Program Loudness, which sets nothing else
- **THEN** the block keeps Peak to Loudness only, and Program Loudness draws on its product scale

#### Scenario: Clearing the ends of a sized row

- **WHEN** a meter card's block sets Program Loudness to -50 to 0 at a segment of 2, and the user
  clears both ends
- **THEN** the block keeps Program Loudness with `segment` 2 alone, drawn on −60 to 0 LUFS

#### Scenario: Clearing the last row

- **WHEN** the block sets one key and the user clears its fields
- **THEN** the card's entry no longer sets Scales, and the setting shows as unset
