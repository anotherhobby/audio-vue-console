# Proposal

## Why

Rearranging a full scene means deleting cards to make room and recreating them afterwards, losing
their settings and the time spent setting them. The canvas pane around the panel is empty space.
If cards could sit there while the scene is rearranged, no card would need to be deleted to make
room for another.

## What Changes

- A card dragged so that any part of it leaves the panel is **parked**: as soon as it starts to
  cross the panel's edge, its outline jumps wholly outside the panel, and releasing leaves it there,
  on the canvas pane beside the panel, at the same cell size. A selection or group parks as one
  block, keeping its shape and its groups.
- A parked card is dragged back onto the panel like any move. It lands only where it lies wholly
  on the panel's grid on free cells, and is refused otherwise as a move is today.
- Parked cards never overlap one another, and stay within the visible canvas pane. If the window
  shrinks, the canvas zooms out until every parked card is in view again, and the panel stays
  centred.
- A parked card can be selected, shift-clicked, caught by a marquee, deleted and have its settings
  changed in the inspector. It shows no resize handles, it cannot be grouped, and arrow keys never
  move a card across the panel's edge.
- Parked cards are drawn as their plates, as the helper drew them, or as boxes where the helper
  cannot draw them. They are left out of the scene the helper, the thumbnail and the panel see.
- While any card is parked, Save, Apply and Duplicate are disabled, saying why, and the canvas
  says how many cards are off the panel. Save All, when you quit or switch panels, saves nothing
  while a scene has parked cards, and says which scenes have them. The gallery notes a scene with
  parked cards and disables its Duplicate.
- Parked cards are part of the scene's unsaved edits: one undo history with the rest, kept while
  the app runs, and discarded by Revert, loading a version, or Discard.
- A nudge still stops at the grid's edge. Only a drag parks a card.

## Capabilities

### New Capabilities

- `card-parking`: holding cards off the panel while a scene is edited. When a move parks a card,
  where a parked card may sit, what may be done to it, how the canvas shows it and keeps it in
  view, and how it returns to the panel.

### Modified Capabilities

- `scene-layout`: a move past the grid's edge stops at the edge for a nudge only. A drag past it
  parks the cards (`card-parking`).
- `scene-saving`: Save is disabled while a card is parked. Save All saves nothing while an unsaved
  scene has parked cards.
- `scene-apply`: Apply is disabled while a card is parked, saying why.
- `scene-gallery`: Duplicate is disabled for a scene with parked cards, and the gallery notes them.
- `scene-rendering`: a parked card's plate is drawn off the panel, and drawn again alone when its
  settings or the scene's change.

## Impact

- `ConsoleCore`: `SceneContent` gains the parked cards. A pure parking edit (the drag across the
  edge, the jump outside, the pane's reach, return to the grid) sits beside `SceneLayoutEdits`, and
  `SceneEditor`'s selection, settings, delete and refusals cover parked cards. `LayoutRefusal` gains
  the parking refusals. `SceneSession.canSave` and `canApply`, `SceneWrites.saveAll`, and
  `SceneDrafts` duplication check for parked cards. `SceneRendering` keeps and redraws parked
  plates. `GridGeometry` maps cells off the grid.
- `AudioVueConsole/Canvas`: `SceneCanvas` places parked cards' targets in the region's cells off
  its grid and reads the marquee across the whole pane. `LayerStack` draws parked plates, and a new
  `CanvasStack` layout shrinks the panel to keep them in view.
  `AudioVueConsole/Scenes`: the toolbar's help text, the gallery's note and the disabled
  Duplicate.
- Tests in `ConsoleCore/Tests/ConsoleCoreTests` for parking, the pane's reach, return, the
  refusals, gating and Save All.
- Relies on `audio-vue:scene-render` (a plate drawn by itself, as library tiles are) and
  `audio-vue:scene-plate` (a group shares one plate). No API route, host contract or stored format
  changes. Parked cards never reach the host.
