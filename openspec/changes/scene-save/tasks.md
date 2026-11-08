# Tasks

`library-render`, which also changed `SceneStore` and `SceneEditorView`, is archived (2026-11-07).
Read both files as it left them before group 1.
Group 9 waits on audio-vue's answer to `../audio-vue/console-commands-handoff.md`; every other group
can be built first.

## 1. A draft keeps the parse it came from

- [ ] 1.1 Replace `SceneDrafts`'s `layouts: [String: SceneLayout]` with `drafts: [String: Draft]`
  (`ConsoleCore/Sources/ConsoleCore/SceneDrafts.swift`, design D1). `Draft` holds `laidOut:
  LaidOutScene`, `layout: SceneLayout`, `name: String` and `rev: Int?`, with `isUnsaved` being
  `rev == nil || layout != laidOut.layout` and `doc` being `laidOut.doc(for: layout)` with `name`
  set. Add `draft(for: SceneDocument, defaultGrid:)`, which parses once and returns the same draft
  after that, and `keep(_ layout:, for id:)`, which updates it. Make `duplicate` take the source's
  draft, so the copy's doc is built from the draft's own parse, and name the copy "*name* copy",
  then "*name* copy 2" and on, the first no listed scene or copy has. Add `unsaved` (the drafts'
  names in listing order) and `forget()`. Update `SceneDraftsTests`' three existing tests, which call
  `keep`, `layout(for:)` and `duplicate(_:)` with the old shapes, and its doc comment. Verify
  `SceneDraftsTests`: a card's own settings
  survive a kept edit and a duplicate of an edited scene; a draft is the same on a second
  `draft(for:)`; an edit then its undo is not unsaved; a copy is unsaved; names go "RTA copy",
  "RTA copy 2".
- [ ] 1.2 Open the editor, the canvas's `SceneRendering` and the thumbnails from the draft: in
  `SceneEditorView.make()` (`AudioVueConsole/Scenes/SceneEditorView.swift`) use
  `store.drafts.draft(for:defaultGrid:)` for both the `SceneEditor`'s layout and
  `SceneRendering(scene:)`. In `ScenesPage.drawThumbnails` (`AudioVueConsole/Scenes/ScenesPage.swift`)
  pair each scene with its draft's `laidOut` and `layout` where it has one. In `SceneGallery`'s menu
  and the editor's `duplicate()`, pass the draft. Verify the app target builds
  (`mcp__xcode__BuildProject`), and that `SceneRenderingTests` gains a reopen case: a kept layout
  from a draft gives a request whose untouched card keeps its settings.

## 2. The client writes scenes

- [ ] 2.1 Add `rev: Int?` to `SceneDocument` (`ConsoleCore/Sources/ConsoleCore/SceneDocument.swift`)
  and read it in `HostClient.scene(_:at:token:)` (`HostClient+Scenes.swift`). Add to `HostFailure`
  (`HostClient.swift`, design D2) `.stale(currentRev: Int)`, `.invalid([DocumentFailure])`, where
  `DocumentFailure` holds `place` and `message`, and `.conflict(String)`. Verify
  `HostClientScenesTests` reads `rev` 3 for a stored scene and nil for a built-in, and the existing
  tests pass.
- [ ] 2.2 Add `createScene(doc:at:token:) -> (id: String, rev: Int)` (`POST /v1/scenes`),
  `writeScene(_:doc:baseRev:at:token:) -> Int` (`PUT /v1/scenes/{id}`) and
  `deleteScene(_:at:token:)` (`DELETE /v1/scenes/{id}`) to `HostClient+Scenes.swift`, mapping 409
  `Stale` to `.stale`, 422 `Invalid` to `.invalid`, a delete's 409 `Refusal` to `.conflict(detail)`,
  404 to `.notFound`, and 401 to `.tokenRefused` as the other calls do. If the file passes the gate's
  400-line limit, put the writes in `HostClient+SceneWrites.swift`. Verify `HostClientScenesTests`
  over `FakeTransport` covers: the bodies sent (`doc`, `base_rev`) with the Bearer token and no
  `Origin`; each answer above; and a 422 with two failures, one with an empty place.

## 3. Saving, renaming and deleting

- [ ] 3.1 Add `save(_ draft: Draft, overRev: Int? = nil)`, `rename(_ id:, to:)` and `delete(_ id:)`
  to `PanelScenes` (`ConsoleCore/Sources/ConsoleCore/PanelScenes.swift`, design D3 to D5). Save
  creates a copy, or writes a stored scene on `overRev ?? draft.rev`. After a create or write, it
  reads the scene again and replaces it in `scenes`, reading the listing again after a create for
  its order. Rename trims the name, refuses an empty one before any request, writes the held
  document with `name` set, and on `.stale` reads the scene again and retries once. Delete removes
  the scene from `scenes`. Each returns the outcome for `SceneDrafts` (saved document, a copy's new
  id, or the failure), and `.tokenRefused` goes through `fail`. Verify `PanelScenesTests` gains: a
  save that writes `base_rev` 3 and holds revision 4 after; a copy's save that creates and lists the
  new id; a stale save that surfaces `.stale(currentRev: 4)` and an `overRev: 4` retry; a rename with
  an unsaved draft that writes the host's document, not the draft's layout; an empty name refused
  with no request; a delete's `.conflict` keeping the scene.
- [ ] 3.2 Teach `SceneDrafts` the outcomes (design D3, D4): `saved(_ document:, was id:)` replaces
  the draft with a fresh one and moves a copy's draft to the new id; `renamed(_ id:, to document:)`
  drops a clean draft and moves an unsaved one's `name` and `rev`; `renameCopy`, `discard(_ id:)` and
  `deleted(_ id:)`. Verify `SceneDraftsTests`: after `saved` the scene is not unsaved and the copy's
  id is gone; after `renamed` with an unsaved layout the layout stays, still unsaved, and `doc`
  carries the new name.
- [ ] 3.3 Move a saved copy's thumbnail to its new id (`SceneThumbnails.move(from:to:)`,
  `ConsoleCore/Sources/ConsoleCore/SceneThumbnails.swift`), and make `SceneStore.forget()`
  (`AudioVueConsole/Canvas/SceneStore.swift`) run only when the paired host's id differs from the one
  its drafts belong to, not on every `ScenesPage.load()` (design D6). Verify `SceneThumbnailsTests`
  covers the move, and the app target builds.

## 4. The controls

- [ ] 4.1 Save in the editor (design D7): a toolbar Save button in `SceneEditorView` and a File ▸
  Save command (`CommandGroup(replacing: .saveItem)` in a new `SceneCommands`, beside
  `ArrangeCommands` in `AudioVueConsoleApp.swift`), reaching the open editor by a `FocusedValue`,
  both enabled only when the scene is editable and its draft unsaved. After a copy's first save,
  `ScenesPage` replaces the last element of `path` with the new id. The editor's subtitle reads
  "Edited" while unsaved, and `SceneRow` puts a dot after an unsaved scene's name.
  `SceneInspector.kept` (`AudioVueConsole/Scenes/SceneInspector.swift`) reads "In this app until
  saved" for a copy, not "until it quits". Verify
  with `mcp__xcode__RenderPreview` on a gallery preview holding an unsaved copy, and the app target
  building.
- [ ] 4.2 Rename: Rename… in `SceneGallery`'s menu, for a stored scene of any shape or a copy and
  never for a built-in, opens a sheet (`RenameSceneSheet.swift`) with the name selected. The editor's
  title is editable (`navigationTitle(Binding)`) on the same path, for a stored scene or a copy and
  not a built-in. Run the app once and note whether macOS sets the binding on each keystroke. If it
  does, commit only when the field ends editing (design D7). An empty name says a scene needs a name.
  Verify the app target builds, a `#Preview` of the sheet renders, and a title rename sends one
  `PUT` (in the agent's log).
- [ ] 4.3 Delete: Delete… in the same menu, on the same scenes, shows a `confirmationDialog` naming
  the scene and saying it cannot be undone. A copy is discarded with no request. If the deleted
  scene is open, the editor is popped first. A refusal shows the host's reason. Verify the app target
  builds.
- [ ] 4.4 Refusals (design D5, D7): one alert per failed write. `.invalid` lists each
  `place: message`, with an empty place shown as "The scene". `.stale` on a save offers Save Over It
  and Discard Mine, the latter dropping the draft and reading the scene again. Anything else names
  the failure. Each keeps the draft. Verify the app target builds, and that a `#Preview` of the
  invalid alert's text renders with two failures.

## 5. Settling unsaved scenes

- [ ] 5.1 Add `UnsavedScenes` (`AudioVueConsole/Scenes/UnsavedScenes.swift`, held by `SceneStore`,
  design D6) with `settle(then:)`: with nothing unsaved it runs the action at once; otherwise it asks
  Save All, Discard or Cancel, naming the scenes. Save All saves in gallery order and stops at the
  first failure, showing it. Route the picker's `choose` closure (`PanelWindow.picker`,
  `AudioVueConsole/PanelWindow.swift`) and `AddPanelSheet`'s `connect` closure through it. Verify the app target builds.
- [ ] 5.2 In `AppDelegate` (`AudioVueConsoleApp.swift`), `applicationShouldTerminate` returns
  `.terminateLater` while anything is unsaved, and replies through
  `reply(toApplicationShouldTerminate:)` after `settle`: as an `NSAlert` when no window is open, and
  as a sheet on the panel window when one is. Verify the app target builds.

## 6. Revert and Versions

- [ ] 6.1 Add `SceneEditor.revert(to:)`, committed as an undoable edit named Revert, and
  `SceneEditor.replace(with:)`, which removes the editor's undo actions (as `detach()` does) and sets
  the layout without registering one (`ConsoleCore/Sources/ConsoleCore/SceneEditor.swift`, design
  D9). Verify `SceneEditorUndoTests` gains: Revert then undo restores the edited layout and the Edit
  menu names Undo Revert; after `replace(with:)` the undo manager has no action from the editor.
- [ ] 6.2 Give `Draft` the revision its parse came from (`source`), with `isUnsaved` also true when
  `source != rev`, and add `SceneDrafts.load(_ revision:, for id:)`, which replaces the draft's
  `laidOut` with a parse of the revision's document, `name` set to the draft's, keeping `rev`, and
  `revert(_ id:)`, which returns the draft to a parse of the base document and says whether the parse
  changed (`SceneDrafts.swift`, design D9). Verify `SceneDraftsTests`: a loaded version is unsaved
  with an unchanged layout; its `doc` carries the old layout and the current name; saving writes on
  the base revision; `revert` after a load reports a change of parse, and after a plain edit does not.
- [ ] 6.3 Add `HostClient.sceneRevisions(_:at:token:)` (`GET /v1/scenes/{id}/revisions`, returning
  each `rev`, `saved_at` as a `Date` and `doc`, newest first) and `PanelScenes.revisions(_:)`. Verify
  `HostClientScenesTests` reads two revisions in order with their dates, and a built-in's empty list.
- [ ] 6.4 In `SceneEditorView`, a Revert to Saved toolbar button and File ▸ Revert to Saved
  (`SceneCommands`, `CommandGroup(after: .saveItem)`), enabled while the draft is unsaved and has a
  base revision, calling `editor.revert(to:)` on the same parse or `editor.replace(with:)` when the
  parse changes. A Versions toolbar `Menu` reading `PanelScenes.revisions` when opened, listing the
  current version first and each revision by local date and time, disabled for a built-in, a copy and
  a scene of another shape; choosing one calls `SceneDrafts.load` and `editor.replace(with:)`, and
  choosing the current version reverts. Verify the app target builds and a `#Preview` of the Versions
  menu's rows renders with three dated entries.

## 7. Apply

- [ ] 7.1 Add `CommandOutcome` (`.done`, `.refused(String)`, `.noPanel`, `.expired(String)`,
  `.unknown(String)`) and `HostClient.switchScene(_:at:token:)` (`POST /v1/commands/switch`, mapping
  200, 409, 503 and 504 by the `Outcome`'s `status`) in a new
  `ConsoleCore/Sources/ConsoleCore/HostClient+Commands.swift` (design D8). Verify
  `HostClientCommandsTests` (new) over `FakeTransport`: the body `{"scene": id}` with the token and no
  `Origin`, and each status to its case with its reason.
- [ ] 7.2 Add `PanelScenes.apply(_ draft:)`: save when unsaved (a copy created first), stop on a
  failed save returning it, then `switchScene` by the scene's id and return the outcome. Verify
  `PanelScenesTests`: an unsaved draft is written then switched, in that order; a clean draft is only
  switched; a refused save sends no switch; a refused switch keeps the save.
- [ ] 7.3 In `SceneEditorView`, an Apply toolbar button, enabled for any scene of the panel's shape and
  disabled with a help tag for another shape, and the banner under the toolbar (design D7) showing the
  outcome: done, the panel's reason, no panel answered, or that the panel may have switched. After a
  copy's first save through Apply, the path is replaced as for Save (task 4.1). Verify the app target
  builds and a `#Preview` of the banner renders each outcome.

## 8. The panel-behind note

- [ ] 8.1 Add `sceneSpec` to `PanelState` from the state's `Scene.spec`
  (`ConsoleCore/Sources/ConsoleCore/PanelState.swift`). Verify `PanelStateTests` reads it, and nil
  where the scene section is missing.
- [ ] 8.2 Hand `PanelWindow`'s `live` to `ScenesPage` and on to `SceneEditorView`
  (`AudioVueConsole/PanelWindow.swift`, `ScenesPage.swift`). In `SceneStore`, hold the ids saved while
  on screen (design D10): add an id when its save succeeds while `live.state?.sceneSpec == id`, remove
  it on a done Apply of that id, and drop every id other than the current `sceneSpec` when it changes.
  The banner shows the note for a held id. Verify the app target builds and a `#Preview` of the
  banner shows the note.

## 9. Waiting on audio-vue

Start once audio-vue's change `command-results-and-reset` is archived and `tools/refresh-contract.sh`
has brought in the switch's own done model and the reset route. Before starting, recheck that change's
deltas against the specs this plan relies on (alignment F14).

- [ ] 9.1 Decode the switch's own done model (planned as `SwitchOutcome`; take the name from the
  refreshed contract) into `CommandOutcome.done(capture:why:recorded:)`, and have the banner say the
  scene is on the panel and capture was kept, or rebuilt with history restarted and `why` as given,
  adding that the panel will not start on it only when `recorded` is false (design D8). Verify
  `HostClientCommandsTests` decodes a kept and a rebuilt answer and one with `recorded` false, and the
  banner's `#Preview` shows a rebuild with its reason and an unrecorded switch.
- [ ] 9.2 Add `HostClient.resetPanel(at:token:)` on audio-vue's reset route, returning a
  `CommandOutcome`, and a Reset button in the editor's toolbar and in `PanelPage`'s Status section
  (`AudioVueConsole/PanelPage.swift`), asking nothing first, its outcome in the editor's banner or
  beside the Panel page's button (design D11). Verify `HostClientCommandsTests` covers the route's
  answers, and the app target builds.

## 10. Run against the panel

- [ ] 10.1 With the proving host paired, the maintainer runs: duplicate RTA, move a card, ⌘S, and see
  the host list "RTA copy" (`GET /v1/scenes`) with the card moved and its settings kept; rename it
  with an unsaved edit and see the host's name change while the edit stays marked; save again; open
  a second client's write (`curl` a PUT on the same base) and choose Save Over It; try to delete the
  scene on screen and read the host's refusal; delete the copy; quit with an unsaved scene, once
  with the window open and once closed, and choose Cancel, then Save All; switch panels with an
  unsaved scene and choose Discard. Then: Revert two moves and undo the Revert; open Versions,
  choose an earlier version and save it, and see its layout under the current name; Apply an edit
  and see the panel switch and the banner; save the scene on screen and see the note, then Apply and
  see it clear; Apply during a calibration and read the refusal; once group 9 is built, Apply a scene
  with deeper history and read the rebuild's reason, and press Reset in the editor and on the Panel
  page. A screenshot of the gallery with an unsaved mark, and of the banner after an Apply.
- [ ] 10.2 Record in `project-map.md` the drafts, `UnsavedScenes`, the scene writes, the commands
  and the banner, and in `host-contract.md` the switch outcome's fields and the reset route as
  audio-vue built them. Record in
  `pitfalls.md` that a `LaidOutScene`'s card ids are per parse, so a layout is turned back into a
  document only through the parse it came from. Remove the drafts line from `working-notes.md`'s
  canvas notes if it says edits are never saved. Verify each changed entry is dated and names its
  files.

## Workflow follow-up

- Verify the change against its specs (`openspec-verify-change`), then archive it after the
  maintainer's run.
