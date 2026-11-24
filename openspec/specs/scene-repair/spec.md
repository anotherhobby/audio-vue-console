# scene-repair Specification

## Purpose

Lets the console find what a scene holds that the host's settings schema no longer takes, and
offer, before changing anything, the smallest edit that makes the scene pass it.

## Requirements

### Requirement: A scene needs a repair where it fails the schema's shape

A scene SHALL need a repair where it holds a key the schema does not declare, a value of another
type, outside its bounds, not among its choices or not matching its pattern, or an entry missing a
key the schema requires, or a key the entry holds depends on.

Source: audio-vue `settings-schema`, "The declarations export as JSON Schema": a document validation
refuses for its shape fails against the export too. Decision (maintainer, 2026-11-23). audio-vue
`bar-card-segments` (2026-11-24).

#### Scenario: A key moved off the scene

- **WHEN** a stored scene's `analysis:` block holds `rta_weighting`, which the schema's analysis
  block does not declare
- **THEN** the scene needs a repair

#### Scenario: A scale with one end

- **WHEN** a stored meter card's `scales` gives Program Loudness a `lo` and no `hi`
- **THEN** the scene needs a repair

#### Scenario: A scene that passes

- **WHEN** a stored scene holds only declared keys, each with a value its declaration takes
- **THEN** the scene needs no repair

### Requirement: Scenes are checked against the host's schema, not its messages

The app SHALL check each scene it holds, other than a built-in, against the host's settings schema as
read from the host, and SHALL NOT judge a scene from a failure message.

Source: Decision (maintainer, 2026-11-23): a failure's wording is the host's to change.

#### Scenario: A built-in scene

- **WHEN** the host lists a built-in scene
- **THEN** it is not checked and is never offered a repair

#### Scenario: A reworded failure

- **WHEN** the host words its failure for an undeclared key differently
- **THEN** the scene needs the same repair

### Requirement: A repair removes what is undeclared

A repair SHALL remove every key the schema does not declare where it is found: at the scene's root,
in a block, in a card's settings, in a card's entry, or in an alternate.

Source: audio-vue `settings-schema`, "Nothing is accepted that is not declared".

#### Scenario: Three removed analysis keys

- **WHEN** the repair is made for a scene whose `analysis:` holds `capture_rate`, `rta_weighting`,
  `rta_hold_s` and `rta_peak_fall_db_s`
- **THEN** its `analysis:` holds `capture_rate` alone

#### Scenario: A grid size

- **WHEN** the repair is made for a scene whose `grid:` holds `cols`, `rows` and `gap`
- **THEN** its `grid:` holds `gap` alone

### Requirement: A repair brings a number back to the bound it crossed

A repair SHALL set a number above its declared maximum to that maximum, and one below its declared
minimum to that minimum. It SHALL NOT round a number to a step.

Source: Decision (maintainer, 2026-11-23): the smallest edit keeps a value as near the one chosen as
the host takes. audio-vue `settings-schema`: a step is never a constraint.

#### Scenario: A hold too long

- **WHEN** the repair is made for an RTA card whose `hold_s` is 20, where the schema declares a
  maximum of 10
- **THEN** its `hold_s` is 10

### Requirement: A repair unsets any other value that does not fit

A repair SHALL remove a value that is of the wrong type, not among its declared choices, or not
matching its declared pattern, so that it takes its default.

Source: Decision (maintainer, 2026-11-23): unset rather than the default written in, so the setting
follows the host's default from then on.

#### Scenario: A choice no longer offered

- **WHEN** the repair is made for a card whose `release` is `hold`, where the schema offers `drop`
  and `fall`
- **THEN** the card holds no `release`, and it is drawn with `drop`

### Requirement: A repair removes an entry it cannot make whole

Where a repair would remove a key the schema requires of its entry, or leaves a key without one it
depends on, it SHALL remove the entry instead: a card of a kind the host does not have, an alternate
with no `when`, or a meter scale with one end.

Source: audio-vue `settings-schema`: `cards` items require `card`, and an alternate requires `card`
and `when`. Decision (maintainer, 2026-11-23). audio-vue `bar-card-segments` (2026-11-24): a scale's
`lo` and `hi` depend on each other.

#### Scenario: A card the host no longer has

- **WHEN** the repair is made for a scene holding a `spectrum_old` card and an `rta_bars` card
- **THEN** the scene holds the `rta_bars` card alone

#### Scenario: A scale with one end

- **WHEN** the repair is made for a meter card whose `scales` gives Program Loudness a `lo` of -50
  and no `hi`, and Peak to Loudness a whole span
- **THEN** the card's `scales` holds Peak to Loudness alone

### Requirement: A scene with no card left cannot be repaired

Where a repair would leave the scene with no card, the app SHALL offer no repair and SHALL say that
the scene holds no card the host has.

Source: audio-vue `settings-schema`: a scene's `cards` holds at least one.

#### Scenario: Every card unknown

- **WHEN** a stored scene's only card is of a kind the host does not have
- **THEN** the canvas says the scene holds no card the host has, and offers no Repair

### Requirement: The canvas offers the repair before making it

On a scene that needs a repair and that the canvas may edit, the canvas SHALL list every change the
repair would make, each by where it is and what becomes of it, and SHALL offer Repair. Nothing
SHALL change until the user chooses Repair.

Source: Decision (maintainer, 2026-11-23): ask before repairing.

#### Scenario: Opening Primary

- **WHEN** the user opens a stored scene whose `analysis:` holds `rta_hold_s`, `rta_peak_fall_db_s`
  and `rta_weighting`
- **THEN** the canvas lists the three keys as removed from Analysis and offers Repair, and the scene
  is not marked unsaved

### Requirement: Repair makes the listed changes as one unsaved edit

Choosing Repair SHALL make every listed change at once, SHALL mark the scene unsaved, and SHALL draw
it again. Save and Apply SHALL store it as any edit is stored, and Revert to Saved SHALL put the scene
back as the host holds it.

Source: `scene-saving`: a scene's edits are stored by Save or Apply, and Revert to Saved puts it back.

#### Scenario: Repairing and saving

- **WHEN** the user chooses Repair on Primary and then Save
- **THEN** the document sent holds no `rta_hold_s`, `rta_peak_fall_db_s` or `rta_weighting`, and the
  host stores it

#### Scenario: Repairing and reverting

- **WHEN** the user chooses Repair and then Revert to Saved
- **THEN** the scene is as the host holds it, and the canvas offers Repair again

### Requirement: A moved setting is not carried over

A repair SHALL NOT set a key the scene did not hold. A key the host moved elsewhere SHALL be removed,
and the setting it moved to SHALL keep whatever the scene holds there, else its default.

Source: Decision (maintainer, 2026-11-23): the schema says a key is gone, not where it went.

#### Scenario: The RTA's hold

- **WHEN** the repair is made for a scene whose `analysis:` holds `rta_hold_s` of 1 and whose RTA card
  sets no `hold_s`
- **THEN** the repaired scene holds no `rta_hold_s`, and the card still sets no `hold_s`

### Requirement: What the schema cannot judge is left to the helper's refusal

A repair SHALL change nothing the schema's shape does not judge. Where the repaired scene is still
refused, the canvas SHALL show the helper's refusal as it shows any refusal.

Source: audio-vue `scene-render`, "A request carries a scene and its display": a scene the panel
would refuse is refused with the panel's own failures.

#### Scenario: Repaired but too wide

- **WHEN** the user repairs a scene that also places a card past the panel's last column
- **THEN** the undeclared keys are removed, the card stays where it is, and the scene is shown too
  wide for the panel
