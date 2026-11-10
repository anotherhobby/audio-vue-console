# Spec Delta

## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: The inspector shows the selected card's settings

With one card selected, the inspector SHALL show a control for each setting the host's schema
declares for that card's kind, in the order the card declares them, each with its label and its
unit, and its help when the pointer rests on it. A card that declares no settings SHALL say it has
none.

Source: `product.md`: each card's inspector is generated from the settings schema. Decision
(maintainer, 2026-11-08): read and set a card's settings in the editor. Decision (maintainer,
2026-11-09): compact rows, help on hover, for card and scene settings alike.

#### Scenario: A VU meter

- **WHEN** the user selects a `vu_meter` card
- **THEN** the inspector shows Channel, Alignment, 0 VU at (custom), Lamp hold and Scale and labels,
  in that order, each giving its help on hover

#### Scenario: A card with no settings

- **WHEN** the user selects a card whose declaration has no settings
- **THEN** the inspector says the card has no settings

#### Scenario: A card new to the app

- **WHEN** the panel declares a card kind no build of the app has seen, and the user selects one
- **THEN** its settings are shown from the schema like any other card's

### Requirement: A setting shows the scene's value or the card's default

A setting the card's entry in the scene sets SHALL show that value. A setting it leaves unset SHALL
show the declared default, with no Use Default beside it. An unset colour that overrides an element SHALL
show the colour the scene draws that element in, and SHALL name the element and its swatch: the
swatch the scene's `elements:` block points the element at, else the element's default swatch, in
the colour the scene's palette gives that swatch, else the swatch's default.

Source: audio-vue `settings-schema`: every setting declares its default, and a colour setting says
what it overrides. audio-vue `card-colours`, "A colour resolves by lookup".

#### Scenario: An unset setting

- **WHEN** a `vu_meter`'s entry sets no alignment
- **THEN** Alignment shows SMPTE, with no Use Default beside it

#### Scenario: An unset palette colour

- **WHEN** an `rta_bars` entry sets no minor line colour and the scene sets no palette or elements
- **THEN** Minor line colour shows `#6D7485` and says it uses Grid minor, in Line

#### Scenario: An unset colour the scene repoints

- **WHEN** an `rta_bars` entry sets no minor line colour and the scene points `grid_minor` at
  `accent`
- **THEN** Minor line colour shows the scene's Accent colour and says it uses Grid minor, in Accent

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

- **WHEN** the user chooses Use Default on an `rta_bars` card's major line colour
- **THEN** the entry no longer sets it, and the card's major grid lines are drawn in the scene's
  Grid major colour

### Requirement: Selected cards are edited together where they share a setting

With several cards selected, the inspector SHALL show first each setting every selected card
declares with the same key, type, range, choices, unit, class, standard and element, and no other,
labelled and ordered as the selected card first in the scene declares them.

Source: Decision (maintainer, 2026-11-08): selected cards that share settings are edited as a group.
audio-vue `card-colours`: a card's colour setting names the element it overrides, so one key can
override different elements on different cards.

#### Scenario: A gauge and a peak meter

- **WHEN** a `dynamics_gauge` and a `peak_rms` card are selected
- **THEN** the shared settings are Numeric readout and the scale setting both declare, and leave
  out Floor and Scale top, which only one of them declares

#### Scenario: Same key, different range

- **WHEN** a `peak_rms` and an `rta_bars` card are selected
- **THEN** Floor is not among the shared settings, since its range differs between them

#### Scenario: Same key, different element

- **WHEN** an `rta_bars` and a `loudness_scope` card are selected
- **THEN** Major line colour is not among the shared settings, since one overrides Grid major and
  the other Outline, and Minor line colour is, since both override Grid minor

#### Scenario: Nothing shared

- **WHEN** the selected cards share no setting
- **THEN** the inspector shows no shared settings, and still offers Group and Ungroup
