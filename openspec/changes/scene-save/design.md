# Design

## Context

See `proposal.md` for why. The state today, read on 2026-11-07:

- **Drafts.** `SceneDrafts` (`ConsoleCore`, held by the app's `SceneStore`) keeps a `SceneLayout`
  per scene id and the copies Duplicate made, as `SceneDocument`s with ids `copy-<UUID>`. `forget()`
  drops both, and `ScenesPage.load()` calls it through `SceneStore.forget()` whenever its `PanelKey`
  (address, `isPaired`) changes. A reconnect to the same panel passes through `isPaired == nil`, so it
  drops every draft today.
- **The identity bug.** `LaidOutScene.init` gives each card a fresh `UUID`, and `doc(for:)` finds a
  card's entry by that id. `ScenesPage.laidOut` parses again on every call. So a kept layout paired
  with another parse finds no entries, and each card is written back as `card` and its cells alone.
  This happens on three paths: `SceneEditorView.make` on a reopen, where `SceneRendering` is built
  from a new parse and shown the kept layout; `ScenesPage.drawThumbnails`; and
  `SceneDrafts.duplicate`, which is handed the gallery's parse. A card with no settings of its own
  looks the same, which is why the bug has not shown.
- **Documents.** `SceneDocument` has `id`, `name`, `builtIn`, `fixed` and `doc`, but no revision.
  `PanelScenes.load()` lists the scenes, then reads each in full. Its `scenes` is `private(set)`.
- **Client.** `HostClient+Scenes` reads only. `HostFailure` has no case for a stale base (409
  `Stale`, `current_rev`), an invalid document (422 `Invalid`, `failures` of `place` and
  `message`), or a refused delete (409 `Refusal`). Create answers 201, write 200 and delete 204.
- **Editor.** `SceneEditorView` makes a `SceneEditor` whose `onCommit` keeps each layout in the
  drafts, and its own `UndoManager` comes from the environment. The title is `document.name`. The
  toolbar has Duplicate and Inspector.
- **Quitting and switching.** `AppDelegate` only keeps the app alive with its window closed.
  `PanelWindow.picker` hands `PanelPicker` a `choose` closure calling `HostConnection.connect(to:)`
  for a found panel, and `AddPanelSheet` calls `connect()` for a typed address.
- **Undo.** `SceneEditor.commit(_:_:)` registers each edit with the window's `UndoManager` by name,
  and `detach()` removes every action it registered. Nothing outside the editor can set its layout.
- **Commands.** `HostClient` calls no command. `POST /v1/commands/switch` takes `{"scene": id}` and
  answers an `Outcome`: 200 done, 409 refused, 503 no panel, 504 expired or unknown, with `reason`
  where not done. A done answer also carries `scene`, `capture` (`kept` or `rebuilt`) and `why`
  (audio-vue `Command.reply()` and `src/scene.py`), which the contract does not declare. There is no
  reset command (audio-vue `src/control_commands.py`), though `Analyzer.reset()` exists for one.
- **The scene on screen.** `PanelWindow` makes the `LiveState` and hands it only to `PanelPage`.
  `PanelState` keeps the on-screen scene's `name`. The contract's `Scene` section also declares
  `spec`, its id, which `PanelState` drops.
- **Revisions.** `GET /v1/scenes/{id}/revisions` gives a stored scene's kept earlier revisions,
  newest first, each with `rev`, `saved_at` and its whole `doc`. A built-in keeps none.

## Goals / Non-Goals

**Goals:**

- One place in `ConsoleCore` that owns what is unsaved, and tests that hold it without the app.
- A draft can never be written with entries from another parse.

**Non-Goals:**

- The host's revert route. Loading a version and saving it writes the same revision, and keeps one
  save path (D9).
- What a reset restarts. That is audio-vue's to state, by its standards (the handoff). The app calls
  the command and reports the outcome.
- Knowing which revision the panel loaded after the app relaunches. The panel-behind note lasts for
  the session (D10).
- Telling the user in advance which scene the panel boots on. The app cannot read the boot record,
  so a refused delete names it.
- Saving the scene settings. The inspector edits none yet. When it does, the draft's document
  carries them the same way.

## Decisions

### D1. A draft is the parse it came from, its layout and its base revision

`SceneDrafts` keeps, by scene id, a `Draft`: the `LaidOutScene` the editor was opened on, the
current `SceneLayout`, and its base: the name and revision a save is written with (`rev` nil for a
copy never saved). Every path that
turns a layout back into a document (the canvas's rendering, the thumbnail, Duplicate, Save) goes
through the draft's own `laidOut`. The editor opens on `drafts.draft(for: document)`, which makes one
from a single parse the first time and returns the same one after that. `SceneRendering` is built
from the draft's `laidOut`, and so are the thumbnails.

*Unsaved* is `layout != laidOut.layout`, or the draft's parse being of an earlier version than its
base (D9). It is exact because both layouts carry the same card ids, so undoing back clears it at no
cost. A copy never saved is always unsaved.

*Alternative:* deterministic card ids, such as an index in `cards`. Rejected because an insert or a
delete would shift every later card's id and pair it with the wrong entry. Comparing documents
instead of layouts was also rejected: `doc(for:)` writes explicit spans and positions that the
host's document may leave out, so a scene would read as unsaved before any edit.

### D2. The client gains create, write and delete, and three failures

`HostClient+Scenes` adds `createScene(doc:)` → `(id, rev)`, `writeScene(id, doc:, baseRev:)` →
`rev`, and `deleteScene(id)`. `scene(_:)` and `SceneDocument` carry `rev`. `HostFailure` gains
`.stale(currentRev: Int)`, `.invalid([DocumentFailure])` (with `place` and `message`), and
`.conflict(String)` for a 409 refusal, which carries the host's own reason. The `Refusal` detail is
worded for people, as `host-contract.md` says, so the app shows it as given. A 404 on a write or a
delete stays `.notFound`.

*Alternative:* a separate `SceneWriteFailure` type. Rejected because every other call shares
`HostFailure`, and `.tokenRefused` has to reach `PanelScenes.fail` for any call.

### D3. `PanelScenes` does the writes and keeps its scenes current

`PanelScenes` gains `save(_ draft:)`, `rename(_ id:, to:)` and `delete(_ id:)`. After a create or
a write, it reads the scene again with `GET /v1/scenes/{id}` and replaces its entry, so the app
holds the host's document and revision, not what it sent. The read costs one request per save and
keeps any normalising the host does out of the app. The host lists stored scenes by name, so a
created scene is put where the host's order puts it, by reading the listing again.

`SceneDrafts` is told the outcome. A save replaces the draft with a fresh parse of the stored
document, so the scene is no longer unsaved. A copy's first save moves its draft and its thumbnail
from `copy-…` to the new id. The editor, whose navigation path holds the copy's id, is sent to the
new id (`ScenesPage` replaces the last path element) and reopens on the saved draft. Undo history
does not carry across that reopen. This is acceptable once, at a copy's first save.

### D4. A rename writes the host's document, not the draft

Rename takes the scene's document as `PanelScenes` holds it (the host's), sets `name`, and writes
it on the held revision. A clean draft is dropped, so the next open parses the renamed document. An
unsaved draft keeps its parse and layout, since its card ids must still match. Only its base moves
to the new revision and name. Save writes `laidOut.doc(for: layout)` with `name` set to the base's,
so a later Save sends the new name and does not go stale. For a copy never saved, the
rename changes only the copy's document in `SceneDrafts`. Names are trimmed, and an empty name is
refused in the sheet before any write.

### D5. A stale base offers Save Over It or Discard Mine

On `.stale(currentRev:)`, the editor shows an alert. Save Over It writes again with
`baseRev: currentRev`, still from the draft's document. That overwrites any other change in the
newer revision, which the alert's text says. Discard Mine reads the scene again and drops its draft.
A rename that goes stale reads the scene again and retries once on the new revision. The rename
only changes the name, so nothing else is lost, and the user is never asked about a rename.

### D6. Settling unsaved scenes before a quit or a switch

`SceneDrafts` lists unsaved scenes by name. A small `UnsavedScenes` coordinator in the app target
(`@MainActor`, held by `SceneStore`) shows one alert, with Save All, Discard and Cancel, and runs an
action after Save All or Discard.

- **Quit:** `AppDelegate.applicationShouldTerminate` returns `.terminateLater` when anything is
  unsaved, asks, and replies with `reply(toApplicationShouldTerminate:)`: true after Discard or a
  Save All that fully succeeds, false after Cancel or any failed save, which stays shown.
- **Switch:** the picker's `choose` closure in `PanelWindow.picker` and `AddPanelSheet`'s `connect`
  closure go through `UnsavedScenes.settle { connect… }`.
- **Same panel:** `SceneStore.forget()` moves out of `ScenesPage.load()`'s every run. `SceneStore`
  remembers the host id its drafts belong to (`HostConnection.host?.id`), and forgets only when a
  paired host's id differs.
  A reconnect to the same host keeps the drafts and their bases. A draft that is out of date is
  caught by D5 at its next save.

Save All saves in gallery order and stops at the first failure.

### D7. Where the controls go

- **Save:** a toolbar button in `SceneEditorView` and a File ▸ Save command
  (`CommandGroup(replacing: .saveItem)`), reaching the open editor through a `FocusedValue`. Both
  are disabled unless the scene is editable and unsaved.
- **Unsaved mark:** a dot after the name in `SceneRow`, and the editor's subtitle
  (`navigationSubtitle`) reads "Edited". The title cannot carry the mark, since it is bound to the
  name.
- **Rename:** the gallery's context menu Rename… opens a sheet with a text field. The editor's
  title is an editable navigation title (`navigationTitle(_ title: Binding<String>)`). SwiftUI puts
  Rename in the title's menu on macOS, and the binding's setter commits through the same path as the
  sheet. Apple's documentation says the binding follows the field "as the user types" (stated for
  iOS). If macOS sets it on each keystroke too, the setter keeps a local title and commits only when
  the field ends editing, so a rename is one write (alignment F3).
- **Delete:** the gallery's context menu Delete… shows a `confirmationDialog`, its destructive
  button named Delete. If the deleted scene is open, the editor is popped first.
- **Revert to Saved:** a toolbar button and File ▸ Revert to Saved (`CommandGroup(after:
  .saveItem)`), enabled while the draft is unsaved and has a base revision.
- **Versions:** a toolbar `Menu` listing the current version and each kept revision by
  `saved_at`, read when the menu opens (D9).
- **Apply** and **Reset:** toolbar buttons beside Save (D8, D11). Reset also sits in the Panel page's
  Status section.
- **Banner:** one line under the editor's toolbar holding the last Apply or Reset result, or the
  panel-behind note (D10), replaced by the next and cleared on the next edit.
- **Errors:** one alert per write. An invalid answer lists each `place: message`, with an empty
  place shown as "The scene".

### D8. Apply is a save, then always a switch

Apply calls D3's save when the draft is unsaved, including a copy's create, and on success calls
`HostClient.switchScene(id)` with the scene's id. A switch to a stored scene's id puts up its current
revision whether or not it is already on screen (audio-vue `control-commands`, "A switch names a
scene on the roster"; `scene.py` builds the scene on every switch, read 2026-11-07). So the app never
uses `reload`, and needs no on-screen state to choose between them. A stale live state cannot send
a reload to the wrong scene.

`switchScene` returns a `CommandOutcome`: `.done`, `.refused(reason)`, `.noPanel`,
`.expired(reason)` or `.unknown(reason)`, from the status. audio-vue answered ask 1 on 2026-11-07,
decided but not yet built in its change `command-results-and-reset`. `switch` and `reload` get answer
models of their own (planned as `SwitchOutcome` and `SceneOutcome`, names to be read from the
contract), and other commands keep plain `Outcome`. A done switch carries `scene` (the spec),
`capture` (`kept` or `rebuilt`), `why` (text for a person, null when kept) and `recorded` (whether it
became the panel's next start). The plan uses only switch, so it decodes only the switch model, as
`.done(capture:why:recorded:)`. The banner names the rebuild's reason as given, without parsing it,
and mentions `recorded` only when it is false (maintainer, 2026-11-07). Until the refreshed contract
declares the model, the task that reads it waits, and `.done` reports only that the scene is on the
panel. Apply is enabled for any
scene of the panel's shape, read-only built-ins included, since their editor is read-only but they
can still be put up.

*Alternative:* reload when the scene is on screen, switch otherwise. Rejected because it needs the
live state's `spec` to be current at the moment of the click, and the switch already does both.

### D9. Versions load into the draft as a new parse, and Revert is an editor edit

`PanelScenes.revisions(id)` reads `GET /v1/scenes/{id}/revisions` when the menu opens. Choosing one
replaces the draft's `laidOut` with a parse of that revision's document, `name` set to the draft's
current name, and records the revision it came from. The draft keeps its base revision, the
current one, so a later Save writes on the current revision and is not refused as stale.

A layout means something only with the parse it came from (D1). `SceneEditor`'s undo stores bare
layouts, so an undo across a change of parse would pair one version's cards with another version's
document. So a change of parse goes through a new `SceneEditor.replace(with:)`, which removes the
editor's undo actions and sets the layout without registering one. Choosing a version and reverting
from a version both use it. A plain Revert, on the same parse, is `SceneEditor.revert(to:)`,
committed as an undoable edit named Revert. Choosing the current version is that Revert.

*Alternative:* carry the parse with each undo step. Rejected for now because `SceneEditor` knows
only layouts, and making it carry documents is a larger change than one menu justifies.

### D10. The panel-behind note follows the on-screen scene's id

`PanelState` gains `sceneSpec` from the state's `Scene.spec`, and `PanelWindow` hands its
`LiveState` to `ScenesPage`, which hands it to the editor. When a save of scene `id` succeeds while
`sceneSpec == id`, `SceneStore` marks `id` as behind on the panel. The mark is cleared by a done
Apply of `id`, and whenever `sceneSpec` changes to something else. It lives in `SceneStore`, so it
lasts while the app runs, and is gone after a relaunch.

### D11. Reset calls audio-vue's reset command

`HostClient.resetPanel()` calls the route audio-vue adds (handoff ask 2) and returns a
`CommandOutcome`, shown in the editor's banner or beside the Panel page's Reset button. It asks
nothing first. Until the route is in the saved contract, the task that adds it waits. The button is
not shown before that, so it never answers that the host has no such command.

## Risks / Trade-offs

- [A thumbnail drawn from a new parse after D1 lands differs from before the fix for scenes with
  card settings] → It is now right. The old picture was wrong.
- [`applicationShouldTerminate` with `.terminateLater` and a SwiftUI alert: the alert needs a window,
  and the panel window may be closed] → Show the alert as an `NSAlert` run modally from the delegate
  when no window is open, and as a sheet when one is. The task's manual check covers both.
- [Save Over It overwrites a newer revision's other edits] → The host keeps 20 revisions, so
  Versions can restore the overwritten one. The alert's text says the other change is replaced.
- [The editor reopens on a copy's first save, losing undo] → Once per copy. Carrying the
  `UndoManager` across a navigation change is not worth the plumbing.
- [Two clients rename the same scene] → The retry in D5 means the last rename wins, which is the
  host's own rule for a write on the current revision.
- [Apply saves and then the switch is refused] → The save stands, and the banner says the panel was
  not switched, with the reason. A second Apply has nothing to save and only switches.
- [An expired or unknown outcome] → The panel may have switched. The banner says so, and the live
  state shows the scene on screen within its next message.
- [Apply's report and Reset wait on audio-vue] → Every other task builds first. If audio-vue's
  answer changes what a reset is, D11 and its task change with it.
- [Choosing a version drops the undo history] → Revert to Saved still goes back to the current
  version in one click, and the spec says so.
