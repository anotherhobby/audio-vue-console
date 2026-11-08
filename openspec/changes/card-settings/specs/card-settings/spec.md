# Spec Delta

## Purpose

How the editor's inspector reads and changes the settings of the cards selected in a scene,
generated from the host's settings schema, so a card the app has never seen still shows its
settings.

## ADDED Requirements

### Requirement: The inspector shows the selected card's settings

With one card selected, the inspector SHALL show a control for each setting the host's schema
declares for that card's kind, in the order the card declares them, each with its label, its help
and its unit. A card that declares no settings SHALL say it has none.

Source: `product.md`: each card's inspector is generated from the settings schema. Decision
(maintainer, 2026-11-08): read and set a card's settings in the editor.

#### Scenario: A VU meter

- **WHEN** the user selects a `vu_meter` card
- **THEN** the inspector shows Channel, Alignment, 0 VU at (custom), Lamp hold and Scale and labels,
  in that order, each with its help

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

A setting whose declared shape is none of a switch, a choice, a colour or a number SHALL show its
value as the scene holds it, SHALL offer no change, and SHALL be written back as it was.

Source: audio-vue `settings-schema`: the declarations, not the app, decide which settings exist.

#### Scenario: A list setting

- **WHEN** a card declares a setting that is a list of colours
- **THEN** the inspector shows its value, offers no control for it, and a save keeps it unchanged

### Requirement: A setting shows the scene's value or the card's default

A setting the card's entry in the scene sets SHALL show that value. A setting it leaves unset SHALL
show the declared default, marked as the default. An unset colour with no declared default SHALL say
it uses the palette's colour.

Source: audio-vue `settings-schema`: every setting declares its default; a colour left out of
`rta_bars` is the palette's grid line (its manifest).

#### Scenario: An unset setting

- **WHEN** a `vu_meter`'s entry sets no alignment
- **THEN** Alignment shows SMPTE, marked as the default

#### Scenario: An unset palette colour

- **WHEN** an `rta_bars` entry sets no major line colour
- **THEN** Major line colour says it uses the palette

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
- **THEN** the entry no longer sets the floor, Floor shows the default, marked as the default, and
  the panel's measurement is not reset

#### Scenario: A palette colour's default

- **WHEN** the user chooses Use Default on an `rta_bars` card's major line colour
- **THEN** the entry no longer sets it, and the card is drawn in the palette's grid colour

### Requirement: Selected cards are edited together where they share a setting

With several cards selected, the inspector SHALL show first each setting every selected card
declares with the same key, type, range, choices, unit, class and standard, and no other, labelled
and ordered as the selected card first in the scene declares them.

Source: Decision (maintainer, 2026-11-08): selected cards that share settings are edited as a group.

#### Scenario: A gauge and a peak meter

- **WHEN** a `dynamics_gauge` and a `peak_rms` card are selected
- **THEN** the shared settings are Numeric readout and the scale setting both declare, and leave
  out Floor and Scale top, which only one of them declares

#### Scenario: Same key, different range

- **WHEN** a `peak_rms` and an `rta_bars` card are selected
- **THEN** Floor is not among the shared settings, since its range differs between them

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
