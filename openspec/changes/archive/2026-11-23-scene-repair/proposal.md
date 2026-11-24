# Proposal

## Why

When audio-vue changes what a scene may hold, a stored scene written before the change can stop
passing validation. `rta-card-settings` moved the RTA's weighting and hold from the scene's
`analysis:` block onto the card, and the stored scene Primary still sets `rta_weighting`,
`rta_hold_s` and `rta_peak_fall_db_s` there. The panel refuses such a scene, and the render helper
refuses to draw it. Today the only fix is editing the stored document by hand. The console holds
the host's settings schema, so it can see what a scene holds that the host no longer takes, and offer
to remove it.

## What Changes

- **The console finds what the host would refuse a stored scene for by its shape.** It checks each
  scene it holds against the host's settings schema, the one it already reads for the inspector:
  - a key the schema does not declare, at any depth;
  - a value of the wrong type, outside its range, not among its choices or not matching its pattern;
  - a card of a kind the host does not have.

  It reads none of this from the host's or the helper's failure messages.
- **A repair is the smallest edit that passes the schema** (proposed):
  - It removes an undeclared key.
  - It brings a number back to the bound it crossed.
  - It unsets any other value that does not fit, so it takes its default, and the default stays the
    host's from then on.
  - Where removing a required key would leave its object invalid, it removes that object: a card
    with no kind it knows, or an alternate with no `when`.
  - A scene left with no card cannot be repaired.
- **The console asks before repairing** (maintainer, 2026-11-23). The canvas lists every change the
  repair makes, and one button, Repair, applies them all. The scene is then unsaved, and Save or
  Apply stores it as any edit is stored. Built-in scenes are never offered a repair: the host ships
  them valid.
- **The gallery marks every scene that needs a repair.** The panel refuses such a scene as well, so
  the console marks each one in the gallery, not only the scene that is open.
- **What the schema cannot judge is shown as the helper says it.** That covers:
  - a scene too wide for the panel;
  - an image the host does not hold;
  - a look category set twice;
  - a keyed table's own rules.

  The canvas keeps showing the helper's refusal, which names these, and the repair leaves them
  alone.
- **A moved setting is not carried over.** The schema says a key is gone, not where it went. A repair
  removes `analysis.rta_hold_s`, and each RTA card's hold then takes its default.
- **The grid's `cols` and `rows` become one case of this.** They are undeclared keys of `grid:`, and
  a stored scene holding them is repaired like any other. That replaces opening such a scene marked
  unsaved with them already removed (`scene-saving`, "A saved scene declares no grid size").

Not doing:
- Repairing stored styles. The app writes no style until the `styles` change gives it the style
  routes, and that change should repair a style the same way.
- Repairing a scene on the host without the console.
- A Repair All action in the gallery.

## Capabilities

### New Capabilities

- `scene-repair`: what makes a scene need a repair, what a repair changes, how it is offered and
  applied, and what it leaves to the helper's refusal.

### Modified Capabilities

- `scene-saving`: a stored scene that holds a grid size needs a repair. It no longer opens marked
  unsaved with the size already removed. The app still writes no grid size.
- `scene-gallery`: a scene that needs a repair is marked in the gallery.

## Impact

- **Code:**
  - `ConsoleCore` gains the repair: a walk of a scene document against the schema's `$defs/scene`,
    `placement`, `alternate`, and each `block.<name>` and `card.<name>`. It yields the repaired
    document and the list of changes.
  - `Draft` and `SceneDrafts` apply a repair as a new parse of the repaired document.
  - `LaidOutScene.declaresGridSize` and `dropGridSize` give way to the repair.
  - In the app target, a note on the canvas with Repair, and a note on the gallery's cards.
- **Sequencing:** independent of `styles`. That change should take up repairing styles once it adds
  their write routes.
- **Host:** nothing is asked of audio-vue.
- **Referenced specs relied on:**
  - `audio-vue:settings-schema`: nothing undeclared is accepted; the export carries every type,
    bound, choice and pattern and is closed; one validation; the panel loads only what passes.
  - `audio-vue:scene-render`: a request the panel would refuse is refused with its failures.
  - `audio-vue:settings-store`: a write is validated whole; a stale write is refused.
  - `audio-vue:scene-grid`: `grid:` holds the layout grid and nothing else.
