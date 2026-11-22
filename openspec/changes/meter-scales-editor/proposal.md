# Proposal

## Why

The meter card's `scales` setting is a block keyed by field name, one `lo`, `hi` and optional
`anchor` per field (audio-vue `meter-segments`, uncommitted there). The inspector shows a block
it does not know as read-only, so a scale override can be seen but not set. The host now declares
the block's keys, its settings and its span rules in the schema (`x-keys`, `properties`,
`required`, `x-rules`), so the inspector can edit it from the export without a copy of the field
list.

## What Changes

- The inspector edits a keyed block: one row per key the schema lists in `x-keys`, in that order,
  each with its label, its unit and the product's range as a hint, and `lo`, `hi` and `anchor`
  fields.
- A row's span is checked before it is stored, with the card's own rules: both ends are needed,
  `hi` must be above `lo`, and a set `anchor` must lie between them. A refused span is not stored;
  the inspector says why beside the row, in the card's words.
- Clearing both ends of a row removes that key from the block. A block left with no keys is
  stored as unset, so the card uses the product's scales.
- A keyed block is edited per card like any other setting: several selected cards show it as
  mixed where their blocks differ, and a change sets the block on every selected card as one step.
- `segments` and `value` need no new control: `segments` is an integer setting and
  `value` a switch, and `segments` is disabled through the schema's declared unused case.
  Nothing is added for them.
- The console's card code is rebuilt by the normal build (`render-runtime`); no change to that
  capability is proposed.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `card-settings`: the shape a setting takes gains the keyed block, edited row by row and checked
  against the schema's span rules. The requirement that a setting of an unknown shape is shown and
  not edited stays for every other shape.

## Impact

- `ConsoleCore/Sources/ConsoleCore/SettingGroup.swift`: the shape for an object with `x-keys`,
  read from the export with its keys, their settings and the span rules.
- A pure span check and block edit in `ConsoleCore` (no SwiftUI), so the rules are tested in
  `swift test`.
- `AudioVueConsole/Scenes/CardSettings.swift` and `SettingControls.swift`: the rows for a keyed
  block, with a disclosure of the scale keys.
- Tests in `ConsoleCore/Tests/ConsoleCoreTests` for the shape, the span checks, the block edit and
  the cleared-key and empty-block cases.
- Depends on audio-vue `settings-schema` for the export's form. The `x-keys` form is not yet in
  that spec: it is in audio-vue's open change `meter-segments`, uncommitted. Reference:
  `audio-vue:settings-schema`.
- No API route, host contract or stored format changes: the block is a card setting already sent
  in the scene document.
