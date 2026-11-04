# Code alignment

## Read

Pass 1, 2026-11-03.

- `proposal.md`, `design.md`, `tasks.md` and both spec deltas, as written this session.
- `audio-vue:scene-grid`, in full: declared grid, 64 × 36 default, placements on the grid, fit at
  aspect, gap.
- `audio-vue:scene-plate`, in full: groups declared and never inferred, a group tiles a rectangle
  (with its scenarios: a stack of four, a two-by-two block, an L shape, an outsider), a shared plate
  with one colour, grouping never resizes.
- audio-vue's open changes (`openspec list --store audio-vue`): `settings-store` only. Its deltas
  touch `control-api`, `control-commands`, `control-service`, `control-state`, `host-store`,
  `panel-service`, `scene-backdrop`, `scene-reload`, `settings-schema` and `settings-store`. None
  touches `scene-grid` or `scene-plate`.
- `AudioVueConsole/Sketches/`:
  - `SketchSceneEditor.swift`: the editor's split, the inspector, and `cardID` as `SketchCard.id`.
  - `SketchCanvas.swift`: `SketchCanvas`, `SketchPlates` and `placed(_:in:)`.
  - `SketchCardLibrary.swift`: `.draggable(kind.card)` as a `String`.
  - `SketchScenesPage.swift`: thumbnails through `SketchPlates`.
  - `SketchData.swift`: `groupBounds`, `SketchCells`, `SketchCard.cells`/`id`, `SketchCardKind.roster`,
    `SketchPanel.fits`.
  - `SketchShell.swift`: `columns` go detail-only while editing.
  - `SketchMetrics.swift`: every constant.
  - `sketch.json`: four scenes, all `builtIn: true`; two panels, 8:3 and 16:9.
- `AudioVueConsole/AudioVueConsoleApp.swift`: the Debug-only `Window("UI Sketch")`.
- Searched the app target for each symbol the tasks remove, and for each `SketchMetrics` constant,
  to find its users.
- `.claude/kb/agent/pitfalls.md` and `open-questions.md` (empty).
- A probe package in the scratchpad: a `@MainActor @Observable` class registering undo with a
  Foundation `UndoManager` (`groupsByEvent` off, explicit grouping, `setActionName`), tested under
  Swift 6 with warnings as errors. It builds, undoes, redoes and names the action.
- Every task, 1.1 through 5.1, against the code as the tasks before it leave it.

## Findings

- **F1. Every stub scene is built-in, so nothing could be edited** (resolved)
  - Plan, before: the canvas edits stub scenes, but built-in scenes are read-only (`product.md`).
  - Code: all four scenes in `sketch.json` are `builtIn: true`.
  - Goes to: proposal, design and task 3.1.
  - Resolution: two user scenes, Workbench (96 × 36) and Desk (64 × 36), are added to the stub data.
    Duplicate stays out of scope.

- **F2. The session store would die with the UI Sketch window** (resolved)
  - Plan, before: "edits last until the app quits", with no owner named.
  - Code: the sketch lives in a `Window` scene that is recreated when closed and reopened, so view
    `@State` in it is lost.
  - Goes to: design and task 3.2.
  - Resolution: the App owns `SceneStore` as `@State` and passes it into the window's environment.

- **F3. Undo would outlive the editor** (resolved)
  - Plan, before: the editor registers undo with the window's manager.
  - Code: the manager belongs to the window and survives leaving the editor, so ⌘Z would reach a
    discarded editor and the store would fall out of step.
  - Goes to: design, and tasks 2.3 and 4.6.
  - Resolution: the editor's `detach()` removes its actions, and the canvas calls it when it
    disappears.

- **F4. The handle hit area is larger than Workbench's cells** (resolved)
  - Plan, before: eight handles with a 16 pt hit area, and a "900 pt canvas, about 9 pt cells".
  - Computed: 1280 − 230 − 260 = 790 pt for the canvas, less 2 × 24 padding and 2 × 10 bezel, gives
    722 pt. That makes Workbench's cells 722 / 96 ≈ 7.5 pt, and Desk's 722 / 64 ≈ 11.3 pt. A 2-column
    card is about 15 pt wide.
  - Goes to: design and task 4.3.
  - Resolution: the numbers are corrected. A card under 48 pt in either direction shows only its
    lower-right handle.

- **F5. The kept canvas would depend on throwaway metrics** (resolved)
  - Plan, before: unsaid.
  - Code: the plate palette, `color(for:)` and `backdrop` are in `SketchMetrics`, and the library
    and gallery use them.
  - Goes to: design and task 3.2.
  - Resolution: they move to the kept `CanvasMetrics`, and the sketch uses them from there.

- **F6. Removing `SketchCanvas` strands helpers** (resolved)
  - Code: these are used only by `SketchCanvas.swift`: `groupBounds`, `SketchCells`,
    `SketchCard.cells`, `placed(_:in:)`, and the constants `groupStrokeOpacity`,
    `selectionLineWidth`, `labelPadding`, `plateInset`, `thumbnailInset`, `bezelWidth`,
    `bezelCornerRadius` and `thumbnailCornerRadius`. `SketchCard.id` is used only by the editor's
    `cardID`, which the canvas replaces.
  - Goes to: task 4.1.
  - Resolution: task 4.1 removes each, and verifies with a search.

- **F7. The Arrange menu would show in Release with nothing behind it** (resolved)
  - Code: the canvas is reachable only from the Debug-only UI Sketch window.
  - Goes to: task 4.6.
  - Resolution: the `CommandMenu` sits under `#if DEBUG` with the window.

- **F8. Resizing a grouped card was an inference** (resolved, Q1)
  - Plan: "A grouped card is not resized on its own", sourced as inferred.
  - Goes to: requirement.
  - Resolution: ruled by the maintainer (ungroup first), and the Source updated.

- **F9. Regrouping an existing group was unsaid** (resolved, Q2)
  - Plan, before: grouping a selection that is already exactly one group would just rename it.
  - Goes to: requirement, design and task 1.5.
  - Resolution: ruled by the maintainer as refused ("already a group"). Added to the requirement,
    with a scenario, the refusal cases and task 1.5.

- **F10. A group's plate colour** (deferred)
  - Plan: plates are stub colours by kind, and a group draws one plate.
  - Code: `audio-vue:scene-plate` refuses a group whose members declare different `plate:` colours.
    The app sets no `plate:` today.
  - Goes to: the change that saves scenes to a host.
  - Resolution: deferred. Nothing is saved here, and the saving change must give a new group's
    members one colour, or refuse.

## Questions for the maintainer

Both were asked and answered on 2026-11-03, each with the recommended position.

- **Q1 (F8).** Can a card in a group be resized on its own?
  - Ruled: no. Ungroup first.
- **Q2 (F9).** Does ⌘G on a selection that is already exactly one group do anything?
  - Ruled: it is refused, with the inspector saying the cards are already a group.

## Confirmed

- The `scene-layout` rules match `audio-vue:scene-grid` (placements on the grid) and
  `audio-vue:scene-plate` (groups declared, tiling a rectangle exactly with no outsider). The
  spec's scenarios agree with scene-plate's own: an L shape and an outsider are both refused.
- No open audio-vue change has a delta to `scene-grid` or `scene-plate`.
- The design's numbers:
  - A 4-cell shifted nudge is a sixteenth of 64 columns.
  - The spec's scenarios compute as stated: column 56 + 8 = 64; 2 columns from the edge moved 5
    stops after 2; a 4-wide card shrunk by 6 from the left stops at 1, keeping its right edge.
- `SketchPanel.fits` and `SketchShape.matches` exist, and give the read-only-by-shape test the
  design names.
- The editor already hides the sidebar while editing (`SketchShell`'s `columns`), so the canvas
  width computed in F4 is the default.
- The library's tiles are `.draggable(String)`, which `onDrop(of:delegate:)` can take as plain text.
- The `UndoManager` pattern in the design builds and works under the package's settings (probe).
- `app-boundaries` holds:
  - The core gains Foundation and Observation only (`UndoManager`, `CGPoint`, `CGSize`).
  - The canvas does no networking.
- Held items:
  - `pitfalls.md`, "Identify scenes by spec": the store is keyed by spec.
  - "A SwiftUI List crashed": the canvas and inspector use no `List`.
  - The rest do not touch this change.
- `open-questions.md` holds nothing.
