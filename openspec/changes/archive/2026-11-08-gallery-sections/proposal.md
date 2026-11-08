# Proposal

## Why

The Scenes gallery groups scenes by shape: "For this panel, 8:3" holds this shape's scenes, built-in
and the user's together, and "Other shapes" holds the rest, dimmed as if they could not be used. The
user's own scenes are mixed with the read-only built-ins, and the dimming says a scene of another
shape cannot go on the panel, though the panel shows one fitted at its own aspect with backdrop
either side (audio-vue `scene-grid`). Beside the canvas, the card library is one flat list sorted by
name, which grows with every card; the panel now groups its cards (audio-vue `card-categories`).

## What Changes

- **Three sections** (maintainer, 2026-11-07). "My Scenes" lists the scenes of the panel's shape
  that are not built in: stored scenes and copies not yet saved. "Built-in Scenes" lists the
  built-ins of the panel's shape. "Other Shapes" comes last and lists every scene of another shape,
  built-in or stored. "My Scenes" and "Built-in Scenes", when empty, keep their heading and say
  what goes there; "Other Shapes" is left out when empty.
- **Nothing is dimmed** (maintainer, 2026-11-07). A scene of another shape is shown like any other.
- **Apply works on a scene of another shape** (maintainer, 2026-11-07). It switches the panel to it,
  as for a built-in, and the panel shows it fitted with backdrop either side. `scene-save` left
  Apply disabled for another shape; this change turns that off.
- **Unchanged:** the canvas still refuses edits to a scene of another shape. Rename and Delete stay
  offered for a stored scene of any shape, and Save and Versions stay off for another shape, as
  `scene-saving` says. The disabled Duplicate for This Panel stays.
- **The card library is grouped by the panel's categories** (maintainer, 2026-11-08). The editor's
  library lists its placeable cards under audio-vue's card categories, headed by their labels, with
  the categories and the cards in each in the order the panel's schema gives. A category with no
  placeable card is left out, and a search leaves out a category with no match. audio-vue's
  `card-categories` (archived 2026-11-08) exports them, the card order included after
  `card-order-handoff.md` asked for it.

The gallery and Apply build on what `scene-save` left (archived 2026-11-08). The library waits on
`card-categories`' archive and its answer to the handoff.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `scene-gallery`: "This panel's shape comes first" becomes "My scenes, then the built-ins, then
  other shapes", with none dimmed.
- `scene-apply`: "Apply works on any scene of the panel's shape" becomes
  "Apply works on any scene", another shape included.
- `scene-canvas`: "The library offers the host's placeable cards" groups them by the host's
  categories, in the host's order.

## Impact

- **Code:** The split into sections moves into `ConsoleCore` as a pure, tested function of each
  scene's grid and `builtIn`. In the app target, `SceneGallery` shows the three sections and drops
  `Item.fits`'s dimming; `SceneMetrics.mismatchOpacity` goes. Apply's shape condition in
  `SceneEditorView` goes, with its help text. `SchemaFacts` reads the ordered categories,
  each with its cards in order, and gives the placeable cards grouped and in order; `CardLibrary` shows
  them under headings. The trimmed schema fixture gains the new keywords.
- **Sequencing:** The library waits on `card-categories`' archive, with the card order the handoff asks for, and on
  audio-vue being deployed to the panel and the render bundle refreshed, since every card's manifest
  changes.
- **Host:** None. Referenced specs relied on: `audio-vue:settings-store` (every repository scene is
  listed marked built in; a fixed one is marked fixed), `audio-vue:scene-grid` (a scene with no grid
  is laid out on 64 by 36; a scene is fitted to the display at its own aspect),
  `audio-vue:control-commands` (a switch is refused during a calibration or for a scene that will
  not load, not for its shape), `audio-vue:card-layout` (each card's minimum and whether it is
  placeable), and `audio-vue:card-categories` (the categories in order, each with its label and its
  cards in order).
