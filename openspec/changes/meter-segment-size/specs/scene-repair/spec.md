# Spec Delta

## MODIFIED Requirements

### Requirement: A scene needs a repair where it fails the schema's shape

A scene SHALL need a repair where it holds a key the schema does not declare, a value of another
type, outside its bounds, not among its choices or not matching its pattern, or an entry missing a
key the schema requires, or a key the entry holds depends on.

Source: audio-vue `settings-schema`, "The declarations export as JSON Schema": a document validation
refuses for its shape fails against the export too. Decision (maintainer, 2026-11-23). audio-vue
`bar-card-segments` (2026-11-24): a meter scale's ends depend on each other (`dependentRequired`).

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
