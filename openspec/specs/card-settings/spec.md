# card-settings Specification

## Purpose

How the editor's inspector reads and changes the settings of the cards selected in a scene,
generated from the host's settings schema, so a card the app has never seen still shows its
settings.

## Requirements

### Requirement: The inspector shows the selected card's settings

With one card selected, the inspector SHALL show a control for each setting the host's schema
declares for that card's kind, in the order the card declares them, each with its label and its
unit, and its help when the pointer rests on it. A card that declares no settings SHALL say it has
none.

Source: `product.md`: the inspector is generated from the settings schema. Decisions (maintainer,
2026-11-08, 2026-11-09): compact rows, help on hover.

#### Scenario: A VU meter

- **WHEN** the user selects a `vu_meter` card
- **THEN** the inspector shows Channel, Alignment, 0 VU at (custom), Lamp hold, Scale and labels
  and Shadow, in that order, each giving its help on hover, then Colours

#### Scenario: A card with no settings

- **WHEN** the user selects a card whose declaration has no settings
- **THEN** the inspector says the card has no settings

#### Scenario: A card new to the app

- **WHEN** the panel declares a card kind no build of the app has seen, and the user selects one
- **THEN** its settings are shown from the schema like any other card's

### Requirement: Each setting's control follows its declared shape

A true-or-false setting SHALL be a switch, a choice a picker of its declared choices, a colour a
colour control giving `#rrggbb`, and a number a field with its unit that keeps to its declared range
and, where the schema gives a step, moves by it. A whole number SHALL be stored as one.

Source: audio-vue `settings-schema`: each setting declares its type and its range or choices.
Decision (maintainer, 2026-11-08): numbers move by the card's own step, exported by audio-vue.

#### Scenario: A number out of range

- **WHEN** the user types 9 into a setting declared from 0.15 to 5 seconds
- **THEN** the setting holds 5, the nearest value in range

#### Scenario: A stepped number

- **WHEN** a line weight declares a step of 1 and the user steps it up from 2
- **THEN** it holds 3

#### Scenario: A whole number

- **WHEN** the user sets an integer setting to 4
- **THEN** the scene stores the integer 4, not 4.0

### Requirement: A colour is picked with the system colour panel

A colour setting SHALL open the system colour panel, offering a wheel, RGB and other sliders, a hex
field, saved palettes and picking from the screen, with no opacity. The colour chosen SHALL be
stored as `#RRGGBB` in sRGB, and a hex value typed in the panel SHALL be stored as typed.

Source: Decision (maintainer, 2026-11-08): colour settings get a full colour picker, with RGB and
hex entry and picking from something. audio-vue `settings-schema`: a colour is `#rrggbb`.

#### Scenario: Typing hex

- **WHEN** the user types 2A3550 into the panel's hex field for a card's line colour
- **THEN** the scene stores `#2A3550`, and the swatch shows that colour

#### Scenario: Picking from the screen

- **WHEN** the user picks a colour from the canvas with the panel's eyedropper
- **THEN** the setting holds that colour as `#RRGGBB`

#### Scenario: No opacity

- **WHEN** the colour panel is open for a card's colour
- **THEN** it offers no opacity control

### Requirement: A setting of an unknown shape is shown, not edited

A setting whose declared shape is none of a switch, a choice, a colour, a number or a keyed block
SHALL show its value as the scene holds it, SHALL offer no change, and SHALL be written back as it
was.

Source: audio-vue `settings-schema`: the declarations, not the app, decide which settings exist.

#### Scenario: A list setting

- **WHEN** a card declares a setting that is a list of colours
- **THEN** the inspector shows its value, offers no control for it, and a save keeps it unchanged

### Requirement: A setting shows the scene's value or the card's default

A setting the card's entry in the scene sets SHALL show that value. A setting it leaves unset SHALL
show the declared default, with no Use Default beside it. An unset colour SHALL show the scene's
colour for the role it takes, as edited, and SHALL name the role; an unset colour of the card's own
SHALL show its own default. An unset shadow SHALL show the scene's.

Source: audio-vue `settings-schema` (defaults; a colour's role or own default) and `card-colours`
(a colour resolves by lookup).

#### Scenario: An unset setting

- **WHEN** a `vu_meter`'s entry sets no alignment
- **THEN** Alignment shows SMPTE, with no Use Default beside it

#### Scenario: An unset palette colour

- **WHEN** an `rta_bars` entry sets no minor grid colour and the scene sets no colours
- **THEN** Grid minor colour shows `#6D7485` and says it uses the scene's Grid minor colour

#### Scenario: An unset colour the scene changes

- **WHEN** an `rta_bars` entry sets no minor grid colour and the user sets the scene's Grid minor to
  `#112233`
- **THEN** Grid minor colour shows `#112233`

#### Scenario: A colour of the card's own

- **WHEN** a `dynamics_gauge` entry sets no crest colour
- **THEN** Crest colour shows `#7AA2FF`, the card's own default, and names no role

### Requirement: A changed setting is an edit to the open scene

Changing a setting SHALL change the card's entry in the open scene: the canvas SHALL draw the card
with it, the scene SHALL be marked unsaved, and Save or Apply SHALL store it. Nothing SHALL reach the
panel before then.

Source: `product.md`: saves are explicit; no live preview on the panel; Apply saves and puts the
scene on the panel.

#### Scenario: Changing a floor

- **WHEN** the user sets a meter's floor to -80 dBFS
- **THEN** the canvas draws the meter from -80 dBFS, the scene is marked unsaved, and the panel is
  unchanged

#### Scenario: Saving

- **WHEN** the user saves after changing a setting
- **THEN** the stored scene's card entry holds the new value, and every other key of the entry is
  as the host gave it

### Requirement: Each setting change is one step to undo

Each change to a setting SHALL be one step that Undo and Redo reverse and repeat, named for the
setting by its declared label. A number typed into a field SHALL be one step when committed, and a whole drag of a control
SHALL be one step.

Source: Decision (maintainer, 2026-11-03): undo and redo for every edit.

#### Scenario: Undoing a change

- **WHEN** the user changes Lamp hold and opens the Edit menu
- **THEN** it offers Undo Change Lamp hold, and choosing it restores the value before, and the
  scene's unsaved mark if that was the only edit

### Requirement: Use Default removes a setting from the scene

A setting the card's entry sets SHALL offer Use Default in the inspector, beside the setting, which
SHALL remove the setting from the entry so the card uses its default. A setting left unset SHALL NOT
offer it. It SHALL NOT be named Reset, which is the panel's measurement reset.

Source: Decision (maintainer, 2026-11-08): a setting put back to its default is removed from the
scene; Reset stays the panel's alone.

#### Scenario: Using the default

- **WHEN** a card's entry sets its floor to -80 dBFS and the user chooses Use Default on Floor
- **THEN** the entry no longer sets the floor, Floor shows the default with no Use Default, and
  the panel's measurement is not reset

#### Scenario: A palette colour's default

- **WHEN** the user chooses Use Default on an `rta_bars` card's major grid colour
- **THEN** the entry no longer sets it, and the card's major grid lines are drawn in the scene's
  Grid major colour

### Requirement: Selected cards are edited together where they share a setting

With several cards selected, the inspector SHALL show first each setting every selected card
declares with the same key, type, range, choices, unit, class, standard and role, and no other,
labelled and ordered as the selected card first in the scene declares them.

Source: Decision (maintainer, 2026-11-08): selected cards that share settings are edited as a group.
audio-vue `card-colours`: a card's colour setting is derived from the role it draws, so cards
drawing the same role share it.

#### Scenario: A gauge and a peak meter

- **WHEN** a `dynamics_gauge` and a `peak_rms` card are selected
- **THEN** the shared settings are Numeric readout, the scale setting both declare and the colours
  both draw, and leave out Floor and Scale top, which only one of them declares

#### Scenario: Same key, different range

- **WHEN** a `peak_rms` and an `rta_bars` card are selected
- **THEN** Floor is not among the shared settings, since its range differs between them

#### Scenario: A colour both cards draw

- **WHEN** an `rta_bars` and a `loudness_scope` card are selected
- **THEN** Grid minor colour is among the shared settings, since both draw the minor grid, and Grid
  major colour and the scope's band colours are not, since only one of them draws each

#### Scenario: Nothing shared

- **WHEN** the selected cards share no setting
- **THEN** the inspector shows no shared settings, and still offers Group and Ungroup

### Requirement: Each selected card's own settings are reachable

With several cards selected, the inspector SHALL show, after the shared settings, a section for
each selected card in the scene's order, collapsed until opened, holding all of that card's
settings as a lone selection shows them. A change there SHALL apply to that card alone.

Source: Decision (maintainer, 2026-11-08): clicking a grouped card selects its group, so a grouped
card's own settings are reached in its section, without ungrouping.

#### Scenario: A grouped VU meter

- **WHEN** the user clicks a VU meter grouped with a peak meter, and opens the VU meter's section
- **THEN** it shows Channel, and setting it to right changes the VU meter alone

#### Scenario: Sections start collapsed

- **WHEN** the user selects a group of three cards
- **THEN** the inspector shows the shared settings and three collapsed sections, one per card

### Requirement: A shared setting is changed on every selected card

Where the selected cards' values for a shared setting differ, the inspector SHALL say they are
mixed. A change SHALL set the value on every selected card, and Use Default SHALL remove it from
every one, each as one step.

Source: Decision (maintainer, 2026-11-08): selected cards that share settings are edited as a group.

#### Scenario: Mixed values

- **WHEN** two selected cards hold different values for a shared setting
- **THEN** the setting says its values are mixed, and setting it gives both cards the new value

#### Scenario: Shared settings with different defaults

- **WHEN** two selected cards share a setting whose defaults differ, and the user chooses Use
  Default on it
- **THEN** each card's entry no longer sets it, and each card uses its own default

### Requirement: A measurement setting off its standard is flagged

A measurement setting whose value, set or default, is not one its declared standard defines SHALL be
flagged as off that standard, naming it. A measurement setting no standard governs SHALL NOT be
flagged.

Source: `product.md`: a measurement setting off its standard's values is flagged. audio-vue
`settings-schema`: a measurement setting says which values its standard defines, or that none
governs it.

#### Scenario: A custom alignment

- **WHEN** a VU meter's alignment is set to custom
- **THEN** Alignment is flagged as off ITU-R BS.1726

#### Scenario: A standard alignment

- **WHEN** a VU meter's alignment is EBU
- **THEN** Alignment is not flagged

#### Scenario: No standard governs it

- **WHEN** a peak meter's hold is changed
- **THEN** it is not flagged

### Requirement: A card's chain setting carries no calibration warning

A card's own setting of the chain class SHALL be shown like any other, with no warning that
calibration no longer applies: it picks what part of the calibrated capture the card reads, and
changes neither the capture nor its calibration.

Source: Decision (maintainer, 2026-11-08): no calibration warning on a card's chain setting; the
warning belongs to the capture's own chain settings, edited elsewhere.

#### Scenario: A VU meter's channel

- **WHEN** the user sets a VU meter's Channel to right
- **THEN** no calibration warning is shown

### Requirement: A read-only scene's settings are shown, not changed

On a scene the canvas may not edit, the inspector SHALL show the selected cards' settings and values
and SHALL offer no change and no Use Default.

Source: `scene-canvas`, "A read-only scene can be looked at, not edited".

#### Scenario: A built-in scene

- **WHEN** the user selects a card on a built-in scene
- **THEN** its settings and values are shown, and none of them can be changed

### Requirement: A setting with no effect says why

Where the host's schema declares that a card setting has no effect for the value another of the
card's settings holds, the inspector SHALL show it greyed out with the schema's reason under it,
and SHALL still offer Use Default where the scene sets it.

Source: Decision (maintainer, 2026-11-09): a meter on a field with thresholds offered bar colours
that change nothing. The rule is audio-vue's (`src/cards/fields.py`), declared in its export.

#### Scenario: A crest peak meter

- **WHEN** the user selects a `meter` card showing Crest Peak
- **THEN** Bar body colour and Bar tip colour are greyed out, saying the field is coloured by its
  thresholds

#### Scenario: A plain field

- **WHEN** the user selects a `meter` card showing Crest RMS
- **THEN** Bar body colour and Bar tip colour can be set

### Requirement: A card's colour takes one of the scene's colours or its own

A card's colour setting SHALL offer the scene's roles, each shown in the scene's colour for it as
edited, and a colour through the system colour panel. A colour set to a role SHALL be drawn in the
scene's colour for that role, and SHALL say which. No colour setting SHALL offer a step of a meaning
scale.

Source: audio-vue `card-colours`: every role a card draws can be set on that card, taking the
scene's, another scene role or a colour of its own; the scales are scene-wide.

#### Scenario: Another role

- **WHEN** the user chooses Tick for an `rta_bars` card's Grid minor colour
- **THEN** the entry sets `grid_minor_color` to `tick`, the minor lines are drawn in the scene's Tick
  colour, and the setting says it uses the scene's Tick colour

#### Scenario: A colour of its own

- **WHEN** the user picks `#445566` in the colour panel for Grid minor colour
- **THEN** the entry sets `grid_minor_color` to `#445566`, and the setting names no role

### Requirement: A card's colours are listed together

A card's colour settings SHALL be listed together under Colours, after its other settings, closed
until opened.

Source: Decision (maintainer, 2026-11-09): the inspector must not be one long list. audio-vue
`card-colours`: a card has a colour setting for every role it draws.

#### Scenario: A VU meter's colours

- **WHEN** the user selects a `vu_meter` card and opens Colours
- **THEN** it lists Series colour through Notice colour, and Shadow stays among the other settings

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
