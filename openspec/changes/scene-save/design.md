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
  `PanelPicker` calls `HostConnection.connect(to:)` for a found panel, and `AddPanelSheet` calls
  `connect()` for a typed address.

## Goals / Non-Goals

**Goals:**

- One place in `ConsoleCore` that owns what is unsaved, and tests that hold it without the app.
- A draft can never be written with entries from another parse.

**Non-Goals:**

- Apply (save, then `reload`). It is the next step for scenes, and needs the screen's state.
- Revisions and revert. The host keeps 20, but this change shows none.
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

*Unsaved* is `layout != laidOut.layout`. It is exact because both carry the same card ids, so undoing
back clears it at no cost. A copy never saved is always unsaved.

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
- **Errors:** one alert per write. An invalid answer lists each `place: message`, with an empty
  place shown as "The scene".

## Risks / Trade-offs

- [A thumbnail drawn from a new parse after D1 lands differs from before the fix for scenes with
  card settings] → It is now right. The old picture was wrong.
- [`applicationShouldTerminate` with `.terminateLater` and a SwiftUI alert: the alert needs a window,
  and the panel window may be closed] → Show the alert as an `NSAlert` run modally from the delegate
  when no window is open, and as a sheet when one is. The task's manual check covers both.
- [Save Over It overwrites a newer revision's other edits] → The host keeps 20 revisions, so a revert
  can still recover it once revert is built. The alert's text says the other change is replaced.
- [The editor reopens on a copy's first save, losing undo] → Once per copy. Carrying the
  `UndoManager` across a navigation change is not worth the plumbing.
- [Two clients rename the same scene] → The retry in D5 means the last rename wins, which is the
  host's own rule for a write on the current revision.
