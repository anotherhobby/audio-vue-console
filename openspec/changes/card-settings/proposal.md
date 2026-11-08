# Proposal

## Why

The editor places, moves, resizes and groups cards, but a card's own settings (a meter's floor, a
VU's alignment, a line colour) can only be changed by editing a scene file on the host. The product
promises every scene setting through the app (`product.md`, "The decision"), and each card's
inspector is to be generated from the host's settings schema. The schema already declares every
card setting with its label, help, unit, default, range or choices, class and standard
(`GET /v1/schema`), so the inspector can be built now.

## What Changes

- **The inspector shows a selected card's settings** (maintainer, 2026-11-08), generated from the
  schema's declaration for that card: one control per setting by its shape (a switch, a number with
  its unit and range, a choice, a colour), each with its label and help, in the order the card
  declares them. A card with no settings says so.
- **Colours use the system colour panel** (maintainer, 2026-11-08): wheel, RGB and other sliders,
  hex entry, saved palettes and an eyedropper, with no opacity, stored as `#RRGGBB` in sRGB.
- **Values are read from the scene.** A setting the scene sets shows its value; one it leaves unset
  shows the card's default, marked as the default. A colour with no default that is left unset uses
  the palette, and the inspector says so.
- **Changes are scene edits.** A change is kept in the open scene like a move: it is drawn on the
  canvas at once, marks the scene unsaved, is one step for Undo and Redo, and is stored by Save or
  Apply. Nothing reaches the panel until then.
- **Use Default puts a setting back to its default by removing it from the scene** (maintainer,
  2026-11-08), so the scene follows the card's default and only settings the user chose are stored.
  It is a button beside the setting in the inspector, not named Reset, which stays the panel's
  measurement reset.
- **Several selected cards are edited together where they share a setting** (maintainer,
  2026-11-08). A setting is shared when every selected card declares the same key with the same
  shape: type, range, choices, unit, class and standard. Defaults may differ, since Use Default
  returns each card to its own. Values that differ show as mixed, and a change writes one value to
  every selected card. The Group and Ungroup controls stay.
- **Each selected card keeps a section of its own** (maintainer, 2026-11-08). After the shared
  settings, a collapsed section per selected card holds all its settings, so a card in a group,
  which a click never selects alone, is edited without ungrouping.
- **A setting's class changes what the inspector says** (Ruled, `product.md`): a measurement setting
  off its standard's values is flagged with the standard's name. A card's own chain setting
  (`vu_meter`'s Channel) carries no calibration warning (maintainer, 2026-11-08): it picks what part
  of the calibrated capture the card reads.
- **A read-only scene shows its settings without letting them change**, as the canvas already does
  for its layout.
- **audio-vue is asked for each setting's step and each card's setting order** (maintainer,
  2026-11-08). The schema leaves out `Param.step`, which number controls need to move in the card's
  own increments, and JSON objects carry no order. A handoff asks audio-vue to export both.

Out of scope: the card's information page (later, separately, maintainer 2026-11-08), a slot's plate
colour, an alternate card's settings (kept as the host gave them), and scene-level and install
settings.

## Capabilities

### New Capabilities

- `card-settings`: the inspector's view of the selected cards' settings, generated from the host's
  schema: reading, changing, resetting and group-editing them, and what a setting's class makes it
  say.

### Modified Capabilities

- `scene-canvas`: "Edits are kept until saved or discarded" keeps the settings the user changed,
  not only the cells and group, with every other part of a card's entry as the host gave it.
- `scene-rendering`: "An edit draws again only what it changed" also draws a plate again when one of
  its cards' settings changed.

## Impact

- **Code:** `LayoutCard` carries its card's settings, read from and written back to the scene
  entry's `params`, so undo, the unsaved mark, copies, Save and the renderer all follow them.
  `ConsoleCore` reads each card's setting declarations from the schema, works out the settings
  several cards share, and decides what each class says, all tested there. `SceneEditor` gains the
  setting and reset edits. In the app target, `SceneInspector` shows the settings for one card or
  several. `PlateChanges` counts a settings change as a change to that plate. The trimmed schema
  fixture gains cards with settings of every shape.
- **Sequencing:** The inspector's order and number steps wait on audio-vue's answer to the handoff
  and on audio-vue being deployed to the panel and the render bundle refreshed. Everything else can
  be built first.
- **Host:** One ask to audio-vue, the handoff above. Referenced specs relied on:
  `audio-vue:settings-schema` (every setting declared once with its type, default, label, help,
  class and standard; nothing undeclared accepted; a measurement setting says which values its
  standard defines or that none governs it; one validation reports every failure; the export as
  JSON Schema), `audio-vue:settings-store` (a scene is written whole, on its base revision, and
  writing it never changes the screen), and `audio-vue:scene-render` (the console draws a scene's
  plates from the document it sends, its cards' params included).
