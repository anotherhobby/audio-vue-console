# Design

## Context

See proposal.md for why. The code as it stands:

- **Edits.** `SceneEditor` (ConsoleCore) holds a `SceneContent`, the selection and the last refusal,
  and commits each edit as one undo step through `commitContent`, previewing first so a read-only
  scene refuses. `SceneContent+Parking` holds the moves on and off the grid; `reach` is the canvas
  pane in cells from the grid's top-left, which the canvas computes from `PaneFrame`.
- **Card entries.** `LayoutCard` models kind, cells, group and `settings` (the entry's `params`).
  `LaidOutScene` keeps each card's whole entry by id from its parse and writes it back with those
  four replaced. A card added in the editor has no kept entry, so it is written with those alone.
- **Drops.** `CardLibrary`'s tile names its kind in `SceneStore.draggedKind` on `.onDrag`;
  `CanvasDropDelegate` calls `SceneEditor.drop(kind:size:at:)`, which adds a card with no settings.
- **Tiles.** `LibraryTiles` keeps one `TileSet` per scene-settings `Key`, drawing each card's plate
  at the smallest ladder size that shows its reading, in the library lane of the `RenderQueue`, whose
  `submit(_:lane:key:)` replaces a waiting request with the same key.
- **Inspector.** `SceneInspector` shows the scene's settings, one card's or several. `CardSettingsList`
  and its rows write through `SceneEditor.set`, `useDefault` and `editSetting`, on card ids, and
  offer no change where `editor.readOnly` is set.
- **Apply.** `SceneSession.apply()` calls `SceneWrites.apply(id)`, which saves an unsaved draft and
  switches, and needs no editor attached; only save, revert and versions do. `canApply` is
  `hasCards && !isTooWide && !hasParked`. The editor's banner words an `EditorNote` through
  `EditorBannerText`. `SceneStore.applied(_:)` clears the panel-behind note.
- **Pane.** `SceneCanvas.paneView` stacks a marquee surface under `CanvasStack` (title, the bezelled
  display, footer). `PaneFrame` records the pane's size and the region's frame in pane space.

## Goals / Non-Goals

**Goals:**
- Every rule of where a paste lands lives in ConsoleCore and is unit-tested, as parking's are.
- A pasted card is written with every field its source entry had, not just the four the layout models.
- A tile's setup costs one request per change, coalesced while a control is dragged.

**Non-Goals:**
- A shared clipboard model for other editors (styles, scene settings). Cards only.
- Finding a new ladder size for a set-up tile.

## Decisions

### D1. Copied cards go on the system pasteboard as a private type of entries

Copy writes one JSON array to `NSPasteboard.general` under a private exported type declared in
`AudioVueConsole-Info.plist`: each card's whole entry as the source scene would write it
(`LaidOutScene` entry form: `card`, `col`, `row`, spans, `group`, `params` and any other field).
Paste reads it back through the same reader the scene parse uses, on the open panel's grid.

The macOS pasteboard gives "lasts until something else is copied", cross-scene reach, and Edit-menu
behaviour for free. Entries are the format the app already reads and writes, so nothing new is
defined and unknown fields survive.

Alternatives:
- An in-memory clipboard on `SceneStore`: ⌘C would not replace what the user last copied elsewhere,
  which is not how a Mac app's Copy behaves, and Paste's enablement would need a hand-rolled menu.
- `LayoutCard` values encoded with `Codable`: loses entry fields the layout does not model.

### D2. Added cards carry their entries in `SceneContent`

`SceneContent` gains `entries: [UUID: JSONValue]`, the source entries of cards added in the editor by
a paste. `LaidOutScene.entry(for:)` starts from the parse's entry, else this one, else `card` alone,
then replaces cells, group and `params` as now. `LaidOutScene.copy` (Duplicate) takes the content so
a pasted, unsaved card keeps its fields in the copy. Removing a card drops its entry. Undo, drafts and
thumbnails already carry `SceneContent` whole, so they need nothing more.

Alternative: an `extras` field on `LayoutCard`. Every layout check and equality would carry fields it
never reads, and the parse's own cards would hold their entries twice.

### D3. Paste placement is `SceneContent.pasting(_:within:panelCols:)`

It takes the copied cards (fresh ids, groups renamed), the pane's `reach`, and the panel's columns,
and throws `LayoutRefusal`:

1. **On the panel.** For every offset that keeps the block within the grid's first `panelCols`
   columns, check each pasted card's cells against the cards on the grid (cards, not the block's
   bounding box, so a non-tiling selection fits around others). Take the offset nearest the copied
   cells by squared distance, the top-most then left-most on a tie.
2. **Off the panel.** Where none fits, try the sides in order above, below, left, right: offsets
   that leave the block's bounding box wholly off that side of the grid, within `reach`, covering no
   parked card. The first side with any takes its nearest offset. The cards are parked as a drag
   parks them.
3. **Nowhere.** Throw a new `.noRoomToPaste`, worded "There's no room to paste the copied cards."

Pasted groups take fresh `group-N` names, unused on the grid or among parked cards, one per source
group. A copied kind the schema does not mark placeable throws a new `.notPlaceable(name)` before
any search. `SceneEditor.paste(_:within:panelCols:placeable:)` commits it as "Paste" and selects the
pasted ids. A 96 × 36 grid is about 3,500 offsets times a few cards: no index is needed.

Alternative: reuse `adding(kind:size:centredOn:)` card by card. It cannot keep a block's arrangement
and has no off-panel fallback.

### D4. The canvas handles ⌘C, ⌘X and ⌘V while it has focus

`SceneCanvas` adds `CanvasClipboard`: `.onCommand` on the standard `copy:` and `cut:` selectors,
which write `NSPasteboard` themselves, and `.onPasteCommand(of:validator:perform:)` for the private
type. Cut copies, then calls `SceneEditor.cut()`, which removes the selection through
`SceneContent.removing` as one step named "Cut"; on a read-only scene it records the refusal and
never touches the pasteboard. `SceneEditor.paste` reads the copied entries afresh at each paste, so
two pastes never share ids, and an unreadable entry is a refusal like any other.

Chosen over `.onCopyCommand` and `.onCutCommand` during the build (2026-11-24): those write whatever
items they return, so a refused Cut could clear what was copied before. SwiftUI routes the Edit menu's Copy and Paste to the focused view, so text fields keep theirs,
and the validator enables Paste only when the pasteboard holds cards. The canvas already focuses
itself on a click, so a card clicked then ⌘C works. Paste needs `reach` and the panel's columns,
which only the canvas knows.

### D5. The library's selection and setup live on `SceneEditor`, outside undo

`SceneEditor` gains `libraryCard: String?`, the selected tile, and `setups: [String: [String:
JSONValue]]`, each card kind's setup, with `chooseLibraryCard`, `setSetup`, `unsetSetup`,
`editSetup` and `clearSetup`. `setSelection` and `clearSelection` clear `libraryCard`, and choosing
a library card clears the selection, so one rule keeps the two exclusive. `drop` adds the card with
`setups[kind]` as its settings. None of these register undo or call `onCommit`.

The editor is made when its view appears and dropped when it leaves (`SceneEditorView.make`), which
is exactly "until the scene is exited". Setup edits are allowed on a read-only scene.

Alternative: a separate `LibrarySetup` object in the view. The two selections would need syncing
across the canvas, the library and the inspector by hand.

### D6. `CardSettingsList` writes to a target: cards, or a library kind

`CardSettingsList` takes a target, `.cards(Set<UUID>)` or `.library(String)`, in place of reading ids
from its cards, and routes set, Use Default and keyed-block edits to the editor's card methods or its
setup methods. A library target is shown with one `LayoutCard` built from the kind, at its minimum,
with the setup as its settings, so every row, colour and keyed block reads as for a lone card. The
read-only check applies to the cards target only. `SceneInspector` shows a library target under the
card's name, with a line saying the settings apply to cards dropped from the library, and "Use
Defaults" where the setup is not empty.

### D7. A set-up tile searches the plain tiles' ladder with its setup

`LibraryTiles` keeps, per `TileSet`, set-up tiles by kind with the settings they were drawn for.
`drawSetup(_:settings:for:from:)` runs the same ladder search as a plain tile (`Ladder`), with the
setup on its one card, every probe in the library lane keyed `tile-setup:<kind>`, so a dragged
control replaces the probes still waiting. The size found is kept with the tile, so the same setup
in the same scene settings is not searched again. A set-up tile is kept only while its settings are
still the ones wanted, so a late answer never brings back a cleared or changed setup. The library
shows a set-up tile in place of the plain one while the kind has a setup. A change of scene
settings draws the set-up tiles again with the plain ones. A setup that fits at no size is drawn at
the declared minimum and says so, as a plain tile does.

A set-up card is dropped at its set-up tile's size (`library-setup`, "A dropped card takes its
library setup"): the canvas's `sizeOf` gives that size where the kind has a drawn set-up tile, else
the declared minimum.

Revised 2026-11-24 (maintainer): the first build drew a set-up tile at the plain tile's size, so a
meter with its value on the right said it was too small, and a dropped card landed too small for
its setup.

The ladder's fit test reads `unfit` alone. A card that sheds detail to fit, such as the meter's
ticks and scale labels, reports nothing until past its last step, so a setup that asks for ticks
can still be drawn without them. Sizing for that waits on audio-vue reporting shed steps
(`handoff-shed-detail.md`).

### D8. The gallery's Apply makes a session for the one Apply

`SceneGallery` gains an Apply button in `SceneRow`'s name line. Its enablement reads what the row
already computes: not too wide, has cards, no parked card, and no gallery Apply running; the help
says why, as `applyHelp` does in the editor. On click, `ScenesPage` makes the scene's draft
(`ScenesPage.draft`), a `SceneSession` for its id, and calls `apply()`. On a done switch it calls
`store.applied`, and keeps the note and scene name for a banner over the gallery (`EditorBanner`
with `EditorBannerText`). A failed save goes to the gallery's `writeFailureAlert`, with Save Over It
and discard through the same session. The gallery stays shown; a copy's new id is listed in place
of the copy, as after a save in the editor.

### D9. The grid around the panel is one `Canvas` path behind the panel

`paneView` draws, under `CanvasStack` and above the marquee surface with hit testing off, a SwiftUI
`Canvas` stroking one path of lines at the region's column and row pitch (`pane.region.width /
grid.cols`, `height / grid.rows`), offset from `pane.region.origin`, across the whole pane. The
bezelled display covers it, so no line falls on the panel. Lines are one point wide, in the chosen
colour at a fixed `CanvasMetrics.paneGridOpacity`, so any colour stays light.

The colour is `@AppStorage` holding `#RRGGBB` (`HexColour`), nil for the default, the secondary label
colour. The Grid button is a `ToolbarItem(placement: .primaryAction)` placed before the Inspector's,
opening a popover with the colour well the inspector already uses and Use Default.

### D10. The pane takes library drops; the pointer decides on or off the panel

Added 2026-11-24 (maintainer). The drop delegate moves from the region to the whole pane, with the
pane's geometry (`pane.geometry(grid)`) and a cell under the pointer that is not clamped to the grid
(`GridGeometry.cellOnOrOff(at:)`). A pointer cell on the grid drops as before, through
`SceneLayout.adding`. A pointer cell off it goes to `SceneContent.droppingOff(_:centredOn:within:)`:
the card's block centred there, kept within `reach`, pushed wholly off the grid by parking's rule
(`pushedOff`, opened to the module) where it crosses the edge, refused on a parked card. The
editor's `drop` and `previewDrop` take `reach` and answer content, so the canvas shows and outlines
a parked drop as it does a drag. The new card is selected.

Alternative: a second drop delegate on the pane beside the region's. Two delegates hand off as the
pointer crosses the bezel, and the preview flickers between them.

### D11. A parked card is edited by the grid's own rules, bounded by the pane

Added 2026-11-24 (maintainer: a parked card as editable as one on the panel).

- **Resize.** `CellRect.resizedAcross` takes its bounds as a range of cells (`0...grid.cols` on the
  grid, as today) rather than a width. `SceneContent.resizingParked(_:edges:by:minimum:within:)`
  runs it within `reach`'s columns and rows, avoiding the other parked cards and the grid itself,
  so a resize stops at the panel's edge. `SceneEditor.resize` and `previewResize` go to the layout
  or to it by where the card is, and answer content; `resizableCard` drops its on-the-grid
  condition.
- **Group.** `SceneContent.groupingParked(_:)` applies the grid's tiling check
  (`SceneLayout.tilingRefusal`, opened to the module) to the parked cards, naming the group by
  every card of the scene. `groupRefusal` refuses only a selection holding both kinds, as a new
  `.acrossPanelEdge`, replacing `.parkedCannotGroup`.
- **Drawing.** `ParkedPlates.sort` also draws a plate again where its size differs from the cells
  its layer was drawn for, and `SceneRendering.unfit` reads the parked layers too.

Alternative: lay the pane out as a second `SceneLayout`. Its coordinates start below zero and it
would hold no panel edge, so every rule would need the same bounds threaded through anyway.

## Risks / Trade-offs

- [The pasteboard type is not declared] → `onPasteCommand` matches nothing. Declare it under
  `UTExportedTypeDeclarations` in `AudioVueConsole-Info.plist` and test a round trip in the app.
- [A refused Cut clearing the pasteboard] → settled by D4's `.onCommand`, which never writes on a
  refusal. Still verified in the app.
- [Focus is on the library or inspector when the user presses ⌘V] → Paste does nothing there. The
  canvas focuses on any click on it; that is the same rule Delete and the arrow keys follow today.
- [The grid behind the title and footer text] → light lines under text. A fixed low opacity keeps it
  legible; if not, give the title and footer the pane's background.
- [A set-up tile at the plain tile's size reads as unfit] → it says so, as a plain tile does. The
  card dropped is at its declared minimum either way.
- [Every gallery row gains a button] → the name line crowds on narrow tiles. The button is icon-only
  with its help, as the toolbar's are with names hidden.
