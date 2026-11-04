# Proposal

## Why

Arranging cards by drag and drop on the grid is the heart of the app, and the riskiest UI in it:
SwiftUI's gestures are expected to need custom work for snapping, resizing and groups (`product.md`).
This spike proves that interaction on stub data before pairing and the panel client are built under
it, and keeps the result. The layout rules become specs and tests, and the canvas becomes the real
one.

## What Changes

- `ConsoleCore` gains the scene layout model and its rules:
  - **Placing:** a card is placed on the scene's grid and never overlaps another.
  - **Move and resize:** cards move and resize in whole cells. A move or drop onto taken cells is
    refused, and a resize stops at the neighbour's edge.
  - **Groups:** cards group only when they tile a rectangle, and a group moves and is removed as
    one.
  - **Undo:** every edit is one undoable step.
  - **Tests:** all of these are tested with `swift test`.
- The app gains the scene canvas, built to keep. It replaces the sketch's canvas inside the sketch's
  scene editor and supports:
  - dragging a card in from the library;
  - moving by drag, and resizing by handles;
  - selecting by click, shift-click and marquee;
  - grouping with ⌘G and ungrouping with ⇧⌘G, with the reason shown when grouping is refused;
  - removing with Delete, and nudging with the arrow keys;
  - undo and redo with ⌘Z and ⇧⌘Z.
- The sketch's stub data gains two editable user scenes, one for each panel shape. Every stub scene
  today is built-in, and built-in scenes are read-only (`product.md`).
- The canvas is read-only for a built-in scene, or for a scene whose shape is not the panel's, and
  says so.
- Edits live in memory until the app quits. Nothing is saved, since this change has no host. Saving
  comes with audio-vue's settings documents.
- The canvas starts in SwiftUI. Where a gesture cannot be done well there, that part of the canvas
  drops to an AppKit view, and the reason is recorded.

Out of scope:

- saving, Apply and revisions;
- duplicating a scene, or duplicating it for a panel;
- tiles rendered by the host;
- card minimum sizes from the host;
- card settings in the inspector;
- the rest of the sketch, which stays throwaway.

## Capabilities

### New Capabilities

- `scene-layout`: the rules of a scene's layout as the app edits it. Covers placement on the grid,
  no overlap, moving, resizing, grouping and ungrouping, removal, and undo.
- `scene-canvas`: how the user edits a layout on the canvas. Covers adding from the library, drag,
  handles, selection, the keyboard and menu commands, read-only scenes, and what a refusal shows.

### Modified Capabilities

None. `app-boundaries` holds as it is: the layout model goes in `ConsoleCore`, which imports no UI
framework, and the canvas does no networking.

## Impact

- New code in `ConsoleCore/Sources/ConsoleCore/`: the layout model and the editor that applies and
  undoes edits. New tests to match.
- New app code in `AudioVueConsole/Canvas/`. The sketch's scene editor, gallery thumbnails and
  `sketch.json` change to use it. `SketchCanvas` and `SketchPlates` are removed.
- The host is unchanged and not contacted. The layout rules follow these audio-vue specs, so that a
  layout the app makes is one the panel will load:
  - `audio-vue:scene-grid`: placements stay on the declared grid, and a grid defaults to 64 × 36.
  - `audio-vue:scene-plate`: groups are declared and never inferred, and a group tiles a rectangle
    with no other card inside it.
