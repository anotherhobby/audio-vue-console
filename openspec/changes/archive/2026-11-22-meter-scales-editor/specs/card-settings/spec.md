# Spec Delta

## ADDED Requirements

### Requirement: A keyed block shows the rows of the keys its cards pick

A keyed block SHALL show one row for each key a selected card picks by its picking setting
(`x-keyed-by`), in the block's order, or that setting's default where unset. A key no selected card
picks SHALL have no row.

Source: audio-vue `settings-schema` (`x-keyed-by`); maintainer, 2026-11-21. Open questions at their
defaults, as the scenarios show.

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
- **THEN** that row shows -50 in Low and -5 in High, and Anchor shows blank

### Requirement: A keyed block's span is checked before it is stored

A keyed block's row SHALL be checked against the span rules the schema gives for the block before
any value is stored: both ends are needed, `hi` is above `lo`, and the anchor, set or else the
product's, lies between them. A row that fails SHALL NOT be stored, SHALL keep the value the card
held before, and SHALL say why beside the row in the card's words.

Source: audio-vue `meter` scale overrides, checked as the card checks them. Maintainer ruling
(2026-11-21, alignment F1): match the card.

#### Scenario: A missing end

- **WHEN** the user types -50 in Low and leaves High blank
- **THEN** the row says "a scale needs both a low and a high end", the card keeps the scale it
  held, and nothing is stored for the key

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

#### Scenario: A span that is accepted

- **WHEN** the user completes a valid span on a row
- **THEN** the block stores the key with its `lo`, `hi` and any `anchor` set, and the canvas draws
  the field on that scale

### Requirement: A cleared row removes its key and an empty block is unset

Clearing both ends of a row SHALL remove that key from the card's block, so the card uses the
product's scale for that field. A block left with no keys SHALL be stored as unset, as if the
setting were never set.

Source: Decision (maintainer, 2026-11-21, `meter-segments-handoff.md`): a cleared row removes the
key; an empty block is stored as unset.

#### Scenario: Clearing a row

- **WHEN** a meter card's block sets Program Loudness and Peak to Loudness, and the user clears
  both ends of Program Loudness
- **THEN** the block keeps Peak to Loudness only, and Program Loudness draws on its product scale

#### Scenario: Clearing the last row

- **WHEN** the block sets one key and the user clears its ends
- **THEN** the card's entry no longer sets Scales, and the setting shows as unset

### Requirement: A keyed block is edited on every selected card as one step

With several cards selected, a keyed block where their blocks differ SHALL be shown as mixed, and a
change to a row SHALL set the block on every selected card as one step, named for the setting by
its label, and undoable as one.

Source: `card-settings`, "A shared setting is changed on every selected card", applied to a keyed
block.

#### Scenario: Two meters with different scales

- **WHEN** two `meter` cards are selected and their Scales differ
- **THEN** Scales says its values are mixed, and setting Low on Program Loudness gives both cards
  that low, as one undoable change

## MODIFIED Requirements

### Requirement: A setting of an unknown shape is shown, not edited

A setting whose declared shape is none of a switch, a choice, a colour, a number or a keyed block
SHALL show its value as the scene holds it, SHALL offer no change, and SHALL be written back as it
was.

Source: audio-vue `settings-schema`: the declarations, not the app, decide which settings exist.

#### Scenario: A list setting

- **WHEN** a card declares a setting that is a list of colours
- **THEN** the inspector shows its value, offers no control for it, and a save keeps it unchanged
