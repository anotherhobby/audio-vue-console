# Design

## Context

See `proposal.md` for why. The state today, read on 2026-11-08:

- **Params pass through untouched.** `LaidOutScene` keeps each card's scene entry whole in
  `entries`, keyed by the card's id, and `entry(for:)` writes back only `col`, `row`, `colspan`,
  `rowspan` and `group` over it (scene-canvas design D6). `LayoutCard` holds `id`, `kind`, `cells`
  and `group`, nothing else, so `params`, `plate` and `alternate` ride along in `entries`.
- **Everything follows the layout.** `SceneEditor.commit(_:_:)` turns a new `SceneLayout` into one
  undo step and skips an edit that changes nothing (`next == layout`). `Draft.isUnsaved` compares
  `layout` with `laidOut.layout`. `Draft.doc` and `SceneRendering.draw` both build the document
  from `laidOut.doc(for: layout)`. A copy (`LaidOutScene.copy`) rebuilds entries through
  `entry(for:)`.
- **Redraws follow cells.** `PlateChanges.needed(drawn:for:)` compares each plate's `CellRect`
  with the one it was drawn at, so a change that leaves cells alone draws nothing.
- **The schema.** `PanelScenes` fetches `/v1/schema` once per panel and keeps only `SchemaFacts`
  (minimums, placeable, categories, default grid). Each `card.<name>` carries `properties`: per
  setting `type` or `enum`, `minimum`/`maximum`, `pattern` for a colour, `default` (absent for a
  palette colour), and `x-label`, `x-help`, `x-unit`, `x-class`, `x-standard`
  (`{document, values}`, `{null, []}` for none governs it, or null off the measurement class) and
  `x-live`. Across the 13 cards with settings (2026-11-08, audio-vue `json_schema()`): 28 number,
  16 boolean, 10 enum, 2 integer, 2 colour; classes appearance, display range, measurement and chain.
- **Order is lost.** `JSONValue.object` is a `[String: JSONValue]`, so the declared order of a
  card's `properties` is gone once decoded. `Param.step` exists in audio-vue but is not exported.
- **The inspector.** `SceneInspector` (app target) shows place, size and group for one card,
  Group/Ungroup for several, and the scene's facts for none.
- **Undo naming.** `SceneEditor.registerUndo(_:)` sets the action name it is given.

## Goals / Non-Goals

**Goals:**

- A card's settings are part of the layout, so undo, the unsaved mark, copies, Save, Apply and
  rendering need no path of their own.
- Reading declarations, sharing across a selection, effective values and class notes are pure
  `ConsoleCore` code, tested there; the inspector view only lays out controls.
- Nothing in the app names a card or a setting.

**Non-Goals:**

- Live values on the panel before Save or Apply.
- Client-side validation beyond what the controls enforce: the host's validation on Save stays the
  judge, and its failures are shown as `scene-saving` already says.
- A slot's `plate` colour and an alternate's `params`, which stay in `entries`.

## Decisions

### D1. Settings live on `LayoutCard`

`LayoutCard` gains `settings: [String: JSONValue]`, read from the entry's `params` object by
`LaidOutScene.card(_:on:id:)` and written back by `entry(for:)`: the key set when non-empty, and
removed when empty, so a scene whose card never had `params` is written as it was. A new card from
the library starts with none.

Why: undo, `isUnsaved`, the drafts store and the document a save or render sends all compare or
build from `SceneLayout`, so they follow a settings change for free, and undoing the last change
clears the unsaved mark by the equality they already use.
Alternative: a separate settings map beside the layout in `Draft` and `SceneEditor`. Every one of
those paths would need a second source and a second undo, for no gain.

### D2. `SettingGroup` reads a card's declarations

A new `ConsoleCore` type reads `$defs/card.<name>/properties` into ordered `SettingDeclaration`s:
key, label, help, unit, class, standard (none, governed-by-none, or `document` with `values`),
default (or none), and a `Shape`: `.boolean`, `.number(range, step)`, `.integer(range, step)`,
`.choice([JSONValue])`, `.colour`, or `.other` for anything else. `SchemaFacts` keeps them per card
kind, parsed in the same pass as its other facts.

Order comes from the card's `x-settings` (keys in declared order) and step from each setting's
`x-step`, both asked of audio-vue (D7). Until audio-vue answers, the parse is built and tested on the
trimmed fixture with both keywords added, and the inspector is not shipped (`tasks.md`, group 4).

Alternative: an order-preserving decode of the raw schema bytes. That would put a second JSON parser
in the app to recover something the host can simply state.

### D3. Shared settings are an intersection on declaration equality

`SettingGroup.shared(_ kinds:)` returns the declarations every selected kind has under the same key
and with an equal shape, unit, class and standard; label, help and default are left out of the
comparison. The label, help and order shown are those of the selected card first in the layout's
order. A setting's value across the selection is `.same(value, isSet)` or `.mixed`. After the
shared settings, the inspector lists each selected card in layout order, collapsed, each with all its
own declarations: the view's `DisclosureGroup` state, not the core's.

Why: same key with different ranges is real (`floor_db`: 4 cards, 3 ranges; `ceiling_db`: 3 cards,
3 ranges); writing one card's range to another would be refused by the host or clamp wrongly.
Defaults differ for `show_readout`, and Use Default removes the key, so each card falls back to its own.

### D4. Edits are `SceneLayout` operations through `commit`

`SceneLayout` gains `setting(_ key:, to value:, on ids:)` and `unsetting(_ key:, on ids:)`,
returning a new layout and never refusing, since settings do not touch cells. `SceneEditor` gains
`set(_:to:label:on:)` and `useDefault(_:label:on:)`, given the whole selection from the shared
settings or one card's id from its section, through `commit` with the name "Change <label>" or
"Use Default for <label>", the label as declared. Nothing in the code or the menus says reset, which
is the panel's measurement reset (`SceneEditorView`'s toolbar). An edit equal to the current layout
adds no step, as today.

A number field commits on Return or losing focus; a slider or stepper commits on release, so a
drag is one step and draws once, as a move does. The control shows its value while dragging.

The value written is the form the app's own decoding gives it, so a saved scene read back compares
equal and is not marked unsaved: a whole number as `.integer`, a number setting's included (the
app already reads `-80.0` as `.integer(-80)` and writes it back as `-80`, and audio-vue's check takes
an int for a float setting, `src/schema/check.py`), a fractional one as `.decimal`, `.bool`, the
choice's own `JSONValue`, and `#rrggbb` upper-cased for a colour. A typed number is clamped to the
range and, where a step is declared, rounded to it from the minimum and then to the step's decimal
places, so 0.15 plus three steps of 0.05 is 0.3, not 0.30000000000000004.

### D5. Effective value and class notes are computed, not drawn

`SettingGroup` gives each setting's effective value (set, or default, or "palette" for an unset
colour without a default) and its note:

- `.offStandard(document)` where the class is measurement, the standard has a document, and the
  effective value is not among its `values`.
- none otherwise. A card's chain-class setting carries no note (maintainer, 2026-11-08): the
  calibration warning belongs to the capture's own chain settings, edited elsewhere.

The inspector renders the off-standard note as an orange caption under the control. Help is a
secondary caption under the label. A setting the scene sets shows a Use Default button; one at its
default shows "Default" in place of it.

### D6. Plates redraw on a settings change

`PlateChanges.needed(drawn:for:)` compares a plate's drawn state as its cells plus its cards'
settings, not cells alone: a new `PlateChanges.drawn(of:)` gives `[Set<UUID>: PlateState]`, where
`PlateState` holds the `CellRect` and each member's settings by id. `cells(of:)` stays for what
reads cells alone. `SceneRendering.PlacedLayer` gains the settings it was drawn with beside `cells`,
filled in `take(_:drawnFor:cardIDs:)` from the layout it drew; `LayerStack` (app target) keeps
reading `placed.cells` for a move's slide.

Alternative: redraw the whole scene on any settings change. Simpler, but the spec draws only what
changed, and a full redraw is a visible flash on large scenes.

### D7. The handoff to audio-vue

`card-settings-handoff.md` in audio-vue's root asks for two keywords in `/v1/schema`'s export:
`x-step` on each setting (`Param.step`, null where none), and `x-settings` on each `card.<name>`
and `block.<name>` (its setting keys in declared order; the blocks serve `scene-settings`). It names why (D2), the two cards that show the need
(`vu_meter`'s order, `peak_rms`'s 10 dB floor step), and that the contract's `/v1/schema` body is
free-form, so the saved contract does not change.

### D8. Colours go through `NSColorPanel` in sRGB

SwiftUI's `ColorPicker(_:selection:supportsOpacity: false)` opens the shared `NSColorPanel`, which
has the wheel, the RGB, HSB, CMYK and grey sliders (RGB with its Hex Color # field), colour lists,
crayons, an image palette and the screen eyedropper, so no picker is built. `supportsOpacity: false`
hides the opacity slider, since audio-vue takes `#rrggbb` only.

The panel can work in Display P3 or a generic space, so the hex the panel shows and the hex stored
could differ. `ConsoleCore` owns the conversion, testable without AppKit: `HexColour` parses
`#rrggbb` into sRGB components and formats components back, each rounded to the nearest of 255
steps. The view converts a chosen `Color` with `NSColor(color).usingColorSpace(.sRGB)` before
handing components to it, and builds the swatch with `Color(.sRGB, red:green:blue:)`. A colour
read, shown and written back unchanged is the same hex.

The panel stays open while the user works and sends a change for every movement of the wheel. The
view commits only when the colour's hex differs from the stored one and coalesces a run of changes
into one undo step, closed when the panel's colour has rested for half a second or the selection
changes, so a drag around the wheel is one step and one redraw (D4).

Alternative: a picker of our own (hex field, sliders, swatches) in the inspector. More code for
less: no eyedropper, no saved palettes shared with every other app.

## Risks / Trade-offs

- [A setting's value read back after a save in another form than written] → D4 writes the form the
  decoder produces (alignment F1); the live run checks a saved scene re-reads as not unsaved.
- [Settings make `LayoutCard` heavier, and it is compared on every drag step] → a card has at most
  about ten settings; equality is cheap next to a render.
- [The shared colour panel outlives the selection] → when the selection or the scene changes, the
  panel is left showing the last colour but is no longer bound to it; `ColorPicker` rebinds on the
  next open. Checked in the live run.
- [The inspector waits on audio-vue for order and step] → core work and tests go first; the view is
  the last group.
