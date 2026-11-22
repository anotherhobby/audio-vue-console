# Design

## Context

See proposal.md, "Why". The schema export for the meter card's `scales` (audio-vue's open change
`meter-segments`, uncommitted) gives, for the block: `x-keys` (each key's name, label, unit, range
and product anchor, in order), `properties` (`lo`, `hi`, `anchor`, each a number with its label
and help), `required` (`lo`, `hi`) and `x-rules` as text. The `x-rules` strings are prose, not a
machine rule, so the span check cannot be generated from them.

Today `SettingGroup.shape` maps any object to `.other`, shown read-only. `SettingEdit` writes a
whole value for every selected card (`SceneEditor.set`), and `SceneLayout.changingSettings` is the
one place a card's settings change.

## Goals / Non-Goals

**Goals:**
- The keyed block is read from the export, with its keys, settings and required ends, not copied.
- A row's span is checked in `ConsoleCore`, so `swift test` covers the rules.
- Each card's block is edited as its own value, so mixed cards keep their own other keys.

**Non-Goals:**
- No change to the host, the scene document format or the render path.
- No new control for `segments` or `value`: they reuse the integer and switch controls, and
  `segments` is disabled by the existing unused case.
- No validation of other keyed blocks beyond what this change's span rules cover; a future keyed
  block with other rules gets its own check.

## Decisions

**1. A new shape, `keyed`, carrying its keys and each key's settings.** `SettingDeclaration.Shape`
gains `.keyed(KeyedBlock)`. `KeyedBlock` holds one `BlockKey` per entry of `x-keys` (`name`,
`label`, `unit`, `range`, `anchor`), in that order. Each `BlockKey` takes its settings from
`properties[name]`, a nested object with its own `properties` (`lo`, `hi`, `anchor`), `x-settings`
order and `required` (`lo`, `hi`) and `x-rules`: the schema declares the settings per key, not once
for the block. An object with `x-keys` takes this shape; any other object stays `.other`. Alternative: a generic `.object` shape with the raw JSON, rejected because every
view would re-parse the export.

**2. The span check is a pure function of the block's required keys and the scale rules.**
`KeyedBlock.edit(_ block: JSONValue?, key: String, lo: Double?, hi: Double?, anchor: Double?)`
returns `.success(JSONValue?)` where nil means the key is removed (both ends cleared) and the
caller stores the block as unset when it is empty, or `.failure(SpanRefusal)`. The refusals are
the card's three: a missing end, `hi` not above `lo`, an `anchor` outside `lo...hi`. The `x-rules`
text is not parsed; the three checks are written here and named in the spec. Alternative: parse
`x-rules`, rejected as fragile prose. Risk: the console's check and the card's can drift, so the
host's refusal on write stays the final word; see Risks.

**3. Per-card edits through a transform, not one value.** `SceneLayout` gains
`changingSetting(_ key: String, on ids: Set<UUID>, _ transform: (JSONValue?) -> JSONValue?)`,
built on `changingSettings`, and `SceneEditor` gets a matching step named by the label. A row
change applies the transform to each selected card's own block, so cards whose blocks differ keep
their other keys. This meets "set on every selected card as one step" without writing the same
block to every card. Alternative: read the first card's block and `set` it everywhere, rejected
because it overwrites the other cards' other keys.

**4. Row state is a draft in the view, committed on a valid span.** Each row keeps its three text
fields as local state, seeded from the card's block. A commit (Return or leaving the row) runs the
check: a valid span is stored, a refused one leaves the card's value as it was and shows the
refusal beside the row. A refusal never reaches the editor, so undo holds only accepted steps. An
empty row with both ends blank is a removal, which is also one step. Where the selected cards'
blocks differ, the group shows Mixed, each row's fields show blank, and a commit edits each card's
own block through the per-card transform (decision 3), so the scenario "Two meters with different
scales" holds and no field is disabled.

**5. Rows come from the export, in its order, with the product range as a hint.** The view lists
`KeyedBlock.keys` in order; a key with no entry shows blank fields and its range text. The product
anchor shows as the anchor hint, blank meaning the product's. Nothing is hard-coded per field.

**6. Collapsed until opened, set keys first.** The Scales group is a `DisclosureGroup`, collapsed
by default; within it, rows whose key is set are listed before the rest. This keeps 22 rows out of
the inspector until asked for, as the handoff's "shown only when set or on request" intends.

## Risks / Trade-offs

- [The console's span check drifts from the card's] → the three rules are named in the spec and
  tested with cases matching audio-vue's `tests/test_meter_overrides.py` (checked by hand, since
  that file is in another repository); the host's
  refusal on write remains the final check, and the console shows its words if one comes back.
- [`x-keys` is not in audio-vue's `settings-schema` spec yet] → the export form is owned by the
  open `meter-segments` change there; the console tests use a saved export fixture, so the change
  can be tested before audio-vue archives, and the proposal names the dependency.
- [Card code is mirrored at build, so until the rebuild meter cards draw as plain boxes] → the
  routine `render-runtime` rebuild runs on the next app build; nothing here adds to it.
- [Mixed blocks disable editing] → the user can select one card to edit its block; this is a
  deliberate limit of the row draft, not a missing control.

## Migration Plan

None. The shape is new, the stored block is already a card setting, and nothing is persisted in a
new form. Rollback is removing the shape, which leaves the block read-only as today.

## Open Questions

- Whether the Scales group should show all 22 keys once opened, or only set keys with an "Add"
  row. Deferrable: the spec says "one row for each key", so the first reading is what is built;
  changing it later does not change the stored data.
