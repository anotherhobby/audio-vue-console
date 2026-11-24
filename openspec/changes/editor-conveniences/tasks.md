# Tasks

Core tests run with `cd ConsoleCore && xcrun swift test --disable-xctest` (add `--filter <Suite>`).
App changes are verified by building the app in Xcode and trying them in the running app against
the paired panel. The groups are independent and land in order; each is shippable alone.

## 1. Apply from the gallery

- [x] 1.1 Give `SceneRow` an icon-only Apply button in its name line, enabled when the scene has
  cards, is not too wide, has no parked card and no gallery Apply is running, its help saying why
  not as the editor's `applyHelp` does (share the wording rather than copy it)
  (`AudioVueConsole/Scenes/SceneGallery.swift`, design D8). Verify: the app builds; in the running
  app RTA's button is enabled, a scene too wide or with a parked card shows it disabled with the
  reason in its help.
- [x] 1.2 On click, have `ScenesPage` make the draft, a `SceneSession` for the id and call `apply()`;
  on a done switch call `store.applied`; keep the note with the scene's name for a banner over the
  gallery until the next Apply or the page is left; show a failed save in `writeFailureAlert` with
  Save Over It and discard through that session (`ScenesPage.swift`, `SceneGallery.swift`, design D8).
  Verify: a `SceneSessionTests` case applies a draft with no editor attached, saving first where
  unsaved; in the running app, Apply on RTA switches the panel and the gallery says it is on the
  panel; Apply on an unsaved copy stores it and clears its unsaved dot.

## 2. The grid around the panel

- [x] 2.1 Draw the pane grid behind `CanvasStack` in `SceneCanvas.paneView`: one `Canvas` path at the
  region's cell pitch, offset from `pane.region.origin`, hit testing off, colour at
  `CanvasMetrics.paneGridOpacity` (`AudioVueConsole/Canvas/SceneCanvas.swift`, `CanvasMetrics.swift`,
  design D9). Put the line positions in a pure function of `PaneFrame` and the grid, with a
  `GridGeometryTests`-style case that the lines pass through the region's corners and repeat at its
  cell pitch. Verify: that test passes; in the app a parked card's outline lies on the lines, and
  the lines keep their alignment as the window narrows.
- [x] 2.2 Add the Grid toolbar button before the Inspector's, opening a popover with the colour well
  the inspector uses and Use Default, stored as `#RRGGBB` in `@AppStorage`
  (`SceneEditorView.swift`, design D9). Verify: in the app, picking red tints the grid in this and
  another scene's editor and after relaunch; Use Default returns it.

## 3. Copy and paste cards

- [x] 3.1 Add `SceneContent.entries` for cards added in the editor; have `LaidOutScene.entry(for:)`
  fall back to it, `LaidOutScene.copy` take the content, `with(layout:)` and the initialiser carry
  `entries`, and `removing` drop removed cards' entries (`SceneContent.swift`, `LaidOutScene.swift`,
  `SceneContent+Parking.swift`, design D2; alignment F1). Verify: `LaidOutSceneTests` cases: a card
  with an extra entry field added through `entries` is written with it and with its new cells; it
  keeps it after a move; a duplicate keeps it; a removed card's entry is gone.
- [x] 3.2 Add the copied-cards payload: entries of the selected cards (whole groups) written in
  `LaidOutScene`'s entry form, encoded as one JSON array, and read back on a grid into fresh-id
  `LayoutCard`s with their entries (`ConsoleCore`, new `CardClipboard.swift`, design D1). Verify: a
  `CardClipboardTests` round trip keeps kind, cells, group, settings and an unknown field, and gives
  new ids.
- [x] 3.3 Add `SceneContent.pasting(_:within:panelCols:)` with `.noRoomToPaste` and
  `.notPlaceable(name)` refusals and their wording, and a group-name finder over every card of the
  content, parked included (`ConsoleCore`, `LayoutRefusal.swift`, design D3; alignment F3).
  Verify: `PasteTests` cover each `card-clipboard` scenario: copied cells free; nearest free cells
  with the source still there; a group keeps its arrangement under a new group name; a full panel
  parks above; no room above parks below; nowhere refuses; a non-placeable kind refuses; the
  search keeps within the panel's columns on a scene too wide.
- [x] 3.4 Add `SceneEditor.paste`, committing "Paste", selecting the pasted ids, and
  `SceneEditor.cut`, removing the selection through `SceneContent.removing` as "Cut", both refused
  on a read-only scene (`SceneEditor.swift`, design D4). Verify: `SceneEditorTests` cases for the
  pasted selection and Undo Paste; a cut of one group member removing the whole group, parked cards
  included, with Undo Cut; and both refused on a read-only editor, changing nothing.
- [x] 3.5 Declare the private pasteboard type under `UTExportedTypeDeclarations` in
  `AudioVueConsole-Info.plist`, and add `.onCopyCommand`, `.onCutCommand` and
  `.onPasteCommand(of:validator:)` to `SceneCanvas`, passing `reach`, `panelCols` and the placeable names `SceneEditorView` reads from
  `SchemaFacts.placeable` (design D4; alignment F2). Verify: in the app, ⌘C then ⌘V on a
  meter adds a copy beside it with its settings and Edit offers Undo Paste; it pastes into another
  scene; ⌘C in the library's search copies text and Paste is then disabled on the canvas; on a full
  panel the copy parks above; with no room the canvas says so; ⌘X removes a meter and ⌘V puts it
  back in the same cells; ⌘X on RTA is refused and the meter copied before still pastes; ⌘X in the
  search field cuts text.
- [x] 3.6 Record in `.claude/kb/agent/decisions-log.md` that copied cards travel as entries on the
  pasteboard under a private type (design D1), and in `project-map.md` where the clipboard lives.
  Verify: the notes name files that exist.

## 4. Library setup

- [x] 4.1 Add `libraryCard` and `setups` to `SceneEditor` with their methods, clearing `libraryCard`
  on every selection change and the selection on choosing a library card, outside undo and
  `onCommit`; have `drop` add the kind's setup as the card's settings (`SceneEditor.swift`, design
  D5). Verify: `SceneEditorTests` cases: choosing a library card clears the selection and back; a
  drop takes the setup and a later setup change leaves the dropped card alone; setup edits add no
  undo step and leave the content unchanged; setups work on a read-only editor.
- [x] 4.2 Add a set-up tile to `LibraryTiles`: one request at the plain tile's size with the setup on
  its card, keyed `tile-setup:<kind>` in the library lane, drawn again when scene settings change, the
  last drawn shown until replaced (`LibraryTiles.swift`, design D7). Verify: `LibraryTilesTests`
  cases with the scripted queue: a setup sends one request carrying the settings; two quick changes
  send the last; a scene-settings change redraws it; clearing the setup shows the plain tile.
- [x] 4.3 Make `CardTile` selectable by click, marked when selected and when its kind has a setup,
  showing the set-up tile when there is one; keep `.onDrag` as it is (`CardLibrary.swift`; alignment
  F4). Verify: in the app a click selects the tile and clears the canvas's selection; a drag still
  adds the card, after a click and after a refused drop.
- [x] 4.4 Give `CardSettingsList` a target, `.cards` or `.library(kind)`, routing its writes, and have
  `SceneInspector` show a library target under the card's name with its note and Use Defaults
  (`CardSettings.swift`, `KeyedBlockRows.swift`, `SceneInspector.swift`, design D6). Verify: in the
  app, setting the meter tile's style redraws the tile and the scene stays saved; two meters dragged
  in take that style; leaving and reopening the scene clears the setup; on RTA the tile can be set
  up.
- [x] 4.5 Record in `.claude/kb/agent/decisions-log.md` that a library setup lives on the editor,
  outside undo (design D5). Verify: the note names files that exist.

## 5. Set-up tiles sized to fit (revision of 2026-11-24)

- [x] 5.1 Have `LibraryTiles.drawSetup` run the `Ladder` search with the setup on its card, every
  probe keyed `tile-setup:<kind>` in the library lane, keeping the size found with the tile and not
  searching again for the same setup and scene settings (`LibraryTiles+Setup.swift`, design D7).
  Verify: `LibraryTilesSetupTests` cases: a setup the scripted helper reports unfit at the plain
  size is drawn at the first larger size that fits; the same setup again sends nothing; a setup
  that fits nowhere is drawn at the minimum and keeps its unfit name; the last-wins and
  cleared-in-flight cases still pass.
- [x] 5.2 Drop a set-up card at its set-up tile's size: `LibraryTiles` answers a set-up tile's size,
  and the canvas's `sizeOf` gives it where the kind has one, else the declared minimum
  (`SceneEditorView.swift`, `EditorTiles.swift`, design D7). Verify: a `LibraryTilesSetupTests`
  case for the size answered; in the app, a meter set to value-right drags in at its tile's size.
- [x] 5.3 Make the Grid popover a plain stack, not a `Form`, after it crashed in a layout loop, and
  record the pitfall (`PaneGrid.swift`, `pitfalls.md`). Verify: the app builds; in the app the Grid
  button opens its popover.

## 6. Library drops off the panel (added 2026-11-24)

- [x] 6.1 Add `GridGeometry.cellOnOrOff(at:)`, and `SceneContent.droppingOff(_:centredOn:within:)`
  parking a new card centred on a cell off the grid, pushed off by `pushedOff` where it crosses the
  edge, refused on a parked card or with no room (`GridGeometry.swift`,
  `SceneContent+Parking.swift`, design D10). Verify: `LibraryDropTests` cases for each `card-parking`
  "A library card dropped off the panel is parked" scenario; a `GridGeometryTests` case for a cell
  off the grid.
- [x] 6.2 Have `SceneEditor.drop` and `previewDrop` take `reach`, landing on the grid where the cell
  is on it and parked where it is off, selecting the new card, with its setup (`SceneEditor.swift`).
  Verify: `SceneEditorLibraryTests` cases: a drop off the grid parks the card with its setup and
  selects it, as one step named Add Card; a drop over the panel near its edge stays on the grid; a
  read-only scene refuses both.
- [x] 6.3 Move the canvas's drop target to the whole pane with the pane's geometry, previewing and
  outlining a parked drop (`SceneCanvas.swift`, `CanvasDropDelegate.swift`, design D10). Verify:
  the app builds; in the app a meter dragged from the library onto the grid below the panel is
  parked there, and one dropped on the panel lands as before.

## 7. Parked cards as editable as cards on the panel (added 2026-11-24)

- [x] 7.1 Generalise `CellRect.resizedAcross` to bounds as a range, and add
  `SceneContent.resizingParked`, within `reach`, avoiding other parked cards and the grid, at the
  declared minimum (`SceneLayoutEdits.swift`, `SceneContent+Parking.swift`, design D11). Verify:
  the existing resize tests pass unchanged; `ParkedEditTests` cases for each "A parked card resizes
  within the pane" scenario.
- [x] 7.2 Add `SceneContent.groupingParked` and `.acrossPanelEdge`, replacing `.parkedCannotGroup`;
  have `SceneEditor.resize`, `previewResize`, `resizableCard`, `group` and `groupRefusal` take parked
  cards (`SceneEditor.swift`, `LayoutRefusal.swift`, design D11). Verify: `ParkedEditTests` cases:
  grouping two parked cards that tile; a hole refused; a mixed selection refused with the new
  wording; a lone parked card is resizable and a grouped one is not; a parked resize is one step
  named Resize; the existing grouping tests pass.
- [x] 7.3 Draw a parked plate again when its size changes, and name parked cards too small to show
  their reading (`ParkedPlates.swift`, `SceneRendering.swift`, design D11). Verify:
  `ParkedPlatesRenderingTests` cases (the parked-plate tests, moved out of `SceneRenderingTests`):
  a parked resize draws that plate alone; a parked plate reported unfit is named in `messages`.
- [x] 7.4 Show handles on a parked card and preview its resize on the canvas (`SceneCanvas.swift`,
  `CanvasHandles.swift`). Verify: the app builds; in the app a parked card resizes by its handles
  and stops at the panel's edge; two parked cards group with ⌘G.

## Workflow follow-up

- Sent to audio-vue as `../audio-vue/console-shed-detail-handoff.md` (2026-11-24): the render answer
  reports each card's shed drop steps, so a set-up tile can be sized until nothing its setup asks for
  is shed. Build the console side once audio-vue states the field in `scene-render`, then archive.

- Archive with `openspec-archive-change` once every task is done and the maintainer has tried the
  four features on the panel.
