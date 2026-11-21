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
- **THEN** the inspector shows Channel, Alignment, 0 VU at (custom), Lamp hold, Scale and labels
  and Shadow, in that order, each giving its help on hover, then Colours

#### Scenario: A card with no settings

- **WHEN** the user selects a card whose declaration has no settings
- **THEN** the inspector says the card has no settings

#### Scenario: A card new to the app

- **WHEN** the panel declares a card kind no build of the app has seen, and the user selects one
- **THEN** its settings are shown from the schema like any other card's

### Requirement: A setting shows the scene's value or the card's default

A setting the card's entry in the scene sets SHALL show that value. A setting it leaves unset SHALL
show the declared default, with no Use Default beside it. An unset colour SHALL show the scene's
colour for the role it takes, as edited, and SHALL name the role; an unset colour of the card's own
SHALL show its own default. An unset shadow SHALL show the scene's.

Source: audio-vue `settings-schema`: every setting declares its default, and a colour setting names
its role or its own default. audio-vue `card-colours`: a colour resolves by lookup.

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
