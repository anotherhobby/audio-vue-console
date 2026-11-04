# Design

## Context

The scene editor exists only in the UI sketch (`AudioVueConsole/Sketches/`):
- **Layout:** `SketchSceneEditor` is an `HSplitView` of `SketchCardLibrary` and `SketchCanvas`,
  with an `.inspector` that shows the selected card or `SketchSceneSettings`.
- **Canvas:** `SketchCanvas` draws `SketchPlates` inside the panel's bezel, selects one card by tap,
  and deselects on a tap anywhere in its pane. Its `.dropDestination` lights up and refuses every
  drop.
- **Library:** each `SketchCardTile` is `.draggable(kind.card)`, a `String`.
- **Data:** `sketch.json` holds two panels (8:3 and 16:9) and four scenes, all built-in.

`ConsoleCore` holds the walking skeleton's connection model. It imports no UI framework
(`app-boundaries`). The gate type-checks only the package, so logic belongs there.

## Goals / Non-Goals

**Goals:**

- **Rules in the core:** every layout rule lives in `ConsoleCore` as pure value operations, tested
  without a window.
- **Thin canvas:** the canvas only turns pointer and key events into those operations, and draws
  their results.
- **An answer for the canvas spike:** whether SwiftUI alone can carry snapping, resizing, marquee and
  a library drop with a live preview, and where it cannot.

**Non-Goals:**

- A UI package. Views stay in the app target, as decided in the walking skeleton.
- Card tiles rendered by the host. Plates stay coloured rectangles, as in the sketch.
- Accessibility actions for the canvas beyond what SwiftUI gives. A later change owns them.

## Decisions

### The layout is a value; edits return a new one or a refusal

`ConsoleCore` gains these types:
- `GridSize` (cols, rows);
- `CellRect` (col, row, cols, rows), with intersection, containment and union;
- `LayoutCard` (an id, the card's kind name, its `CellRect`, and an optional group name);
- `SceneLayout` (the grid and its cards).

Each edit is a method that returns a new `SceneLayout` or throws a typed `LayoutRefusal`:
`adding`, `moving`, `resizing`, `grouping`, `ungrouping` and `removing`. The refusal cases are:
- space taken;
- larger than the grid;
- card is grouped;
- too few cards;
- already a group;
- not a rectangle;
- another card in the way;
- read-only, carrying its reason.

Each refusal case maps to a sentence the canvas shows.

- **Card identity:** cards have UUIDs because a scene file gives none. Two `rta_bars` cards are
  told apart only by placement, and placement changes as the user edits.
- **Group names:** a group is named, as in the scene format (`group: meters`). A new group is
  named `group-N`, with the lowest N not already in use.
- **Undo:** value semantics make undo a matter of keeping the previous value.
- *Alternative:* a mutable model with diffs. More code, and undo would need inverse operations for
  each edit.

### Resizing moves only the dragged edges, horizontal first

A resize names the edges being dragged and where the pointer asks them to go:
1. The horizontal edge moves first, as far as the grid and any card on the card's current rows allow.
2. Then the vertical edge, checked against the columns the card now spans.
3. Each edge also stops at the opposite edge less one cell, since a card is at least 1 × 1.

Doing one axis at a time makes the stopping point predictable for a corner drag that meets a
diagonal neighbour.
- *Alternative:* try the whole proposed rectangle and shrink it until it fits. That has no single
  answer when shrinking either axis would work.

### Moves clamp to the grid; overlaps refuse

- **Grid edge:** a move's offset is clamped so every moved card stays on the grid. A drag past the
  edge therefore stops at the edge rather than failing.
- **Other cards:** landing on any card not being moved is refused.
- **Groups:** moving any card moves its whole group.
- **Library drops:** these use the same rule as moves. The new card is centred on the pointer's
  cell, clamped onto the grid, and refused where its cells are taken.

### The editor in the core owns selection, refusal and undo

A `@MainActor @Observable` `SceneEditor` in `ConsoleCore` holds:
- the layout;
- the selection, a set of card ids always widened to whole groups;
- the current refusal;
- whether the scene is read-only, and why.

It exposes the edits and preview queries. `previewMove`, `previewResize` and `previewDrop` return
the layout an edit would give, or the refusal, without committing anything, so the canvas can
draw a drag's outcome live.

**Undo:**
- The editor registers undo with a Foundation `UndoManager` it is given. That is not a UI
  framework, so the boundary holds.
- Each committed edit is bracketed in its own undo group and named (Move, Resize, Add Card, Group,
  Ungroup, Delete). Undo restores the layout and selection from before it.
- A drag commits once, at release, so it is one step.
- Tests use an `UndoManager` with `groupsByEvent` off, since a test has no run loop to close
  groups. A probe package confirmed that this pattern builds with warnings as errors and undoes and
  redoes (alignment, 2026-11-03).
- When the editor goes away (the user leaves the scene), it removes its actions from the window's
  manager with `removeAllActions(withTarget:)`. Otherwise ⌘Z would reach an editor no longer on
  screen and leave the store out of step.

The `UndoManager` integration is the planned approach. If it proves awkward, the fallback is an
undo stack of snapshots inside the editor, with menu items in the app.

### Pointer geometry is plain arithmetic in the core

`GridGeometry` converts between points in the scene region and cells. It covers:
- the cell at a point;
- the rectangle of a `CellRect`;
- the whole-cell offset for a drag translation, rounded to the nearest cell.

It uses `CGPoint` and `CGSize` from Foundation, so it is tested in the core and the canvas does no
cell maths itself.

### The canvas is SwiftUI, with AppKit only where a gesture fights back

The canvas lives in `AudioVueConsole/Canvas/`. It draws the parts below in a `ZStack`, sized by the
same aspect-fit as the sketch: the scene's region, centred in the panel's outline:
- the backdrop;
- the plates;
- selection outlines;
- resize handles for a lone ungrouped card;
- the drag or drop preview, outlined in the accent colour, or red where refused;
- the marquee.

| Input | Handled by |
|---|---|
| Move a card | A `DragGesture` on each plate |
| Resize | A `DragGesture` on each handle, layered above the plate so it wins the hit test |
| Marquee | A `DragGesture` on the empty region, with a zero-length tap clearing the selection |
| Library drop | `onDrop(of:delegate:)`; its `DropDelegate` gives `dropUpdated` the pointer location for the live preview. `dropDestination` gives no location while hovering |
| Delete | `onDeleteCommand` on the focused canvas |
| Arrow keys | `onKeyPress` for the four arrows, reading shift |
| Group and Ungroup | An Arrange menu (`CommandMenu`), reaching the editor through `focusedSceneValue` |

The fallback is an `NSViewRepresentable` canvas layer, for any of these that SwiftUI cannot do
cleanly. That means a handle that loses to the card's drag, a marquee that steals card drags, or a
drop with no live location. The rules in the core are unchanged by it. Each fallback is recorded in
`decisions-log.md`, with what failed.

### Edits are kept in a session store

An app-target `@Observable` `SceneStore` holds a `SceneLayout` per scene, keyed by its spec,
converted from `sketch.json` at launch. The App owns it as `@State` and hands it to the UI Sketch
window through the environment, so closing and reopening that window keeps the edits:
- **Ids:** conversion gives each card a new id.
- **Groups:** conversion keeps the scene's group names.
- **Editor:** the scene editor builds a `SceneEditor` on the store's layout, and writes the layout
  back on each commit.
- **Thumbnails:** gallery thumbnails draw from the store.

### The inspector says why Group is disabled

The inspector has three states:

| Selection | Inspector shows |
|---|---|
| None | The scene's settings, as now |
| One card | Its position and size, live |
| More than one card | How many are selected, Group and Ungroup buttons, and when Group is disabled, the reason from `SceneEditor.groupRefusal` |

### Stub data gains editable user scenes

`sketch.json` gains two user scenes (`builtIn: false`):
- **Workbench:** 96 × 36, editable on the 8:3 panel. It holds a few cards and one two-card group,
  so moving and ungrouping a group can be tried at once.
- **Desk:** 64 × 36, editable on the 16:9 panel.

A scene is read-only when it is built-in, or when its grid's aspect is not the panel's
(`SketchShape.matches`).

### Numbers

- **Nudge:** an arrow nudges 1 cell, and a shifted arrow 4 cells. That is a sixteenth of the
  narrowest grid's width, and enough to cross a small card in one press.
- **Card size:** a card is at least 1 × 1. Minimum sizes per card kind come from the host later.
- **Handles:** each is an 8 pt square, with a 16 pt hit area so they stay easy to grab at small
  cell sizes.
- **Cell size on screen:** at the default 1280 pt window, the library (230 pt) and inspector
  (260 pt) leave the canvas about 790 pt. After 24 pt padding and the 10 pt bezel on each side,
  the panel's outline is about 722 pt wide. So Workbench (96 × 36 on the 8:3 panel) has cells of
  about 7.5 pt, and Desk (64 × 36 on the 16:9 panel) about 11.3 pt.
- **Crowded handles:** a 2-column Workbench card is about 15 pt wide, too small for eight 16 pt hit
  areas. A card under 48 pt (three hit areas) in either direction therefore shows only its
  lower-right handle.

### One palette for the canvas and the library

The plate palette, `color(for:)` and the backdrop gradient move from `SketchMetrics` to the kept
`CanvasMetrics` (`AudioVueConsole/Canvas/`). The sketch's library and gallery use them from there,
so a card's library tile and its plate stay one colour, and the kept canvas depends on nothing
throwaway.

## Risks / Trade-offs

- [A card's drag gesture and a handle's drag compete for the same touch] → The handle is drawn
  above the card, with `highPriorityGesture`. If that still fails, the AppKit fallback takes the
  handles.
- [`DropDelegate` cannot read the dragged `String` until the drop] → The preview needs the kind's
  size while hovering. The library sets a "dragging kind" in the store as the drag starts, through
  `draggable`'s preview closure or `onDrag`. If neither runs reliably, the preview shows a 1-cell
  marker until the drop.
- [The window's `UndoManager` is not the one the Edit menu uses] → The editor takes the manager
  from `@Environment(\.undoManager)` in the canvas's window. The manual run checks the Edit menu's
  titles.
- [Gestures cannot be tested by `swift test`] → Every rule is tested in the core. The canvas is
  checked in a manual run against a list (task 6.1).
- [The canvas lives in the app target, which the gate does not type-check] → It holds no rules,
  and Xcode's build checks it.

## Migration Plan

None. Nothing ships, and nothing is saved. Removing the change means restoring the sketch's
canvas.
