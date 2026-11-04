# Tasks

## 1. The layout and its rules (ConsoleCore)

- [ ] 1.1 Add `GridSize`, `CellRect` (`intersects`, `contains`, `init(enclosing:)`), `LayoutCard` and
  `SceneLayout` in `ConsoleCore/Sources/ConsoleCore/SceneLayout.swift`, with `LayoutRefusal` and its
  sentences in `LayoutRefusal.swift`; verify `SceneLayoutTests` cover the `scene-layout` scenarios
  for "Every card lies on the scene's grid" and "Cards never overlap"
- [ ] 1.2 Implement `SceneLayout.adding(kind:size:centredOn:)`: centred on a cell, clamped onto the
  grid, refused for taken cells or a card larger than the grid; verify tests for each scenario of
  "A card is added only where its cells are free"
- [ ] 1.3 Implement `moving(_:by:)`: widened to whole groups, offset clamped to the grid, refused on
  any card not moving; verify tests for every scenario of "A move keeps to the grid and refuses
  taken cells" and "A group moves and is removed as one" (moving)
- [ ] 1.4 Implement `resizing(_:edges:to:)`: horizontal edge first, then vertical; stopping at the
  grid, at neighbours, and at 1 × 1; refused for a grouped card; verify tests for "A resize stops at
  a neighbour's edge" and "A grouped card is not resized on its own", plus a corner drag meeting a
  diagonal neighbour
- [ ] 1.5 Implement `grouping(_:)` (two or more cards, not already exactly one group, an exact
  rectangle, no other card inside; replaces earlier groups; names `group-N`), `ungrouping(_:)` and `removing(_:)` (whole groups);
  verify tests for every scenario of "Cards group only when they tile a rectangle", "Ungrouping
  leaves the cards in place" and removing a member

## 2. The editor and geometry (ConsoleCore)

- [ ] 2.1 Add `GridGeometry` (cell at a point, rectangle of a `CellRect`, whole-cell offset for a
  translation, rounded to nearest) in `GridGeometry.swift`; verify `GridGeometryTests` with a
  96 × 36 grid at 960 × 360 pt, including points on cell boundaries and past the edges
- [ ] 2.2 Add the `@MainActor @Observable` `SceneEditor` in `SceneEditor.swift`, holding the
  layout, a selection widened to whole groups (`select`, `toggle`, `select(touching:)` for a
  marquee, `clearSelection`), the current refusal, the read-only reason (`builtIn`, `shape`), the
  preview queries, `groupRefusal`, and the committing edits; verify `SceneEditorTests` cover
  selection, previews committing nothing, a refusal set and cleared at the next selection, and
  every edit refused when read-only
- [ ] 2.3 Register undo through an injected Foundation `UndoManager`: one named group per committed
  edit (Move, Resize, Add Card, Group, Ungroup, Delete), restoring layout and selection, and a
  `detach()` that removes the editor's actions; verify tests with `groupsByEvent` off for undo and
  redo of each edit, the action names, no step for a refused edit, and no actions left after
  `detach()`; confirm the boundary tests still pass

## 3. Stub data and the session store (app)

- [ ] 3.1 Add the user scenes `workbench` ("Workbench", 96 × 36, a few cards and one two-card group
  named `pair`) and `desk` ("Desk", 64 × 36) to `AudioVueConsole/Sketches/sketch.json` with
  `builtIn: false`; verify each tiles nothing twice and lies on its grid by loading them into
  `SceneLayout` in a `#Preview` that renders, and that the gallery shows Workbench as "For this
  panel" on the RTA panel
- [ ] 3.2 Add the app's `SceneStore` (`AudioVueConsole/Canvas/SceneStore.swift`): layouts by scene
  spec, converted from `SketchScene` with new card ids and the same group names. Own it as `@State`
  in `AudioVueConsoleApp` and pass it into the UI Sketch window's environment. Add
  `CanvasMetrics` (`AudioVueConsole/Canvas/CanvasMetrics.swift`), taking `palette`, `color(for:)`,
  `backdrop` and the plate constants from `SketchMetrics`, with `SketchCardLibrary` and
  `SketchScenesPage` switched to it. Add `LayoutPlates`
  (`AudioVueConsole/Canvas/LayoutPlates.swift`), which draws a `SceneLayout`'s plates and group
  plates as the sketch did. Switch the gallery's thumbnails from `SketchPlates` to `LayoutPlates`
  fed by the store; verify the build and that `RenderPreview` of the scenes gallery matches the
  sketch's look

## 4. The canvas (app)

- [ ] 4.1 Add `SceneCanvas` (`AudioVueConsole/Canvas/SceneCanvas.swift`) and put it in place of
  `SketchCanvas` in `SketchSceneEditor`, building a `SceneEditor` from the store and the panel,
  read-only for a built-in or mismatched scene. It draws the scene region in the panel's outline,
  plates, selection outlines and the footer's refusal or read-only message. Click selects,
  shift-click toggles, and a click elsewhere in the pane clears. The inspector shows a card, a
  multi-selection with Group and Ungroup and the reason Group is refused, or the scene's settings.
  Delete `SketchCanvas.swift`, which holds `SketchPlates` and the `placed(_:in:)` extension. Also
  delete what only they used: `SketchScene.groupBounds`, `SketchCard.cells`, `SketchCells`,
  `SketchCard.id`, and the `SketchMetrics` constants `groupStrokeOpacity`, `selectionLineWidth`,
  `labelPadding`, `plateInset`, `thumbnailInset`, `bezelWidth`, `bezelCornerRadius` and
  `thumbnailCornerRadius`. Verify the build, `RenderPreview` of the editor with a card selected
  and with two cards selected, and a search showing no reference to any removed name
- [ ] 4.2 Move by drag: a `DragGesture` on each plate, a live preview from `previewMove` (accent
  colour, or red when refused), committed on release; verify the build and record in this task
  whether SwiftUI carried it or the AppKit fallback was needed
- [ ] 4.3 Resize by handles: eight handles (8 pt drawn, 16 pt hit area) on a lone ungrouped card in
  an editable scene, or only the lower-right one on a card under 48 pt either way, above the
  plate's gesture, previewed through `previewResize`; verify the build and record whether the
  handle wins over the plate's drag in SwiftUI
- [ ] 4.4 Marquee: a `DragGesture` on the empty region drawing the rectangle and calling
  `select(touching:)` (adding with shift), a zero-length drag still clearing; verify the build and
  record whether it competes with plate drags
- [ ] 4.5 Library drop: `onDrop(of:delegate:)` with a `DropDelegate` previewing through
  `previewDrop` from `dropUpdated`, the kind's size known while hovering (design, "Risks"), adding
  and selecting on `performDrop`; verify the build and record how the kind's size reached the
  preview
- [ ] 4.6 Keyboard and menu: `onDeleteCommand`, `onKeyPress` for arrows (shift for 4 cells), an
  Arrange `CommandMenu` with Group (⌘G) and Ungroup (⇧⌘G) in `AudioVueConsoleApp.commands`, under
  `#if DEBUG` like the sketch window, reaching the editor through `focusedSceneValue`. The window's
  `UndoManager` comes from the environment and is given to the editor, which removes its actions
  when the canvas disappears; verify the build, that the menu items appear disabled with nothing
  selected, and that Undo is unavailable after leaving the editor
- [ ] 4.7 Record the spike's findings: each AppKit fallback, or that none was needed, in
  `decisions-log.md`; gesture pitfalls in `pitfalls.md`; the `Canvas/` folder and `SceneStore` in
  `project-map.md`; and the canvas rulings marked built in `working-notes.md`; verify each note
  names the file it describes

## 5. The manual run

- [ ] 5.1 Checkpoint: the maintainer runs the app on Workbench and Glass check and works through
  every `scene-canvas` scenario: drop, move, resize, marquee, group and ungroup, Delete, nudges,
  undo and redo with the Edit menu's names, a refusal message, and a built-in scene refusing.
  Verify each scenario passes or becomes a finding with a fix before this box is ticked

## Workflow follow-up

- Run `openspec validate canvas-spike` before review.
- Archive the change once the maintainer has reviewed it and the manual run has passed.
