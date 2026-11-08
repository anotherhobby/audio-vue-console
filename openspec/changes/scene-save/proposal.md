# Proposal

## Why

The canvas edits scenes and Duplicate makes copies, but nothing reaches the panel: every edit and
copy is gone when the app quits (`scene-canvas`, "Edits last until the app quits"). The host has
stored scenes with revisions since `settings-store`, so the app can now save what the user makes,
name it, and delete what they no longer want. Without this, the scene editor cannot be used for
real work.

## What Changes

- **Save writes the open scene to the host.** Save (⌘S, and a toolbar button) stores the open
  scene's layout as its next revision, or, for a copy, creates the scene on the host. Only scenes
  the canvas may edit can be saved: never a built-in, and never a scene shaped for another panel.
  Writing a scene leaves the panel's screen as it is.
- **A copy stays in the app until its first Save** (maintainer, 2026-11-07). Duplicate makes an
  unsaved copy, as it does today. Saving it creates the scene on the host, which gives it its id. An
  abandoned copy leaves nothing on the panel's SD card.
- **Unsaved scenes are marked.** The gallery and the editor's title mark a scene with unsaved
  edits, and every copy not yet saved. Undoing back to the saved layout clears the mark.
- **Rename writes at once** (maintainer, 2026-11-07). Rename… in the gallery's menu and the editor's
  title rename a stored scene by storing a new revision whose `name:` is the new name. Unsaved
  layout edits stay unsaved. Renaming a copy that has never been saved only renames the copy. A name
  cannot be empty. Duplicate names the copy "*name* copy", then "*name* copy 2" and so on where the
  first is taken.
- **Delete removes a stored scene** after asking, since its kept revisions go with it and it cannot
  be undone. Deleting a copy that has never been saved only discards it. Built-in scenes offer
  neither Rename nor Delete. The host refuses to delete the scene on screen and the one the panel
  starts on, and the app shows the host's reason.
- **Losing unsaved scenes is asked about first** (maintainer, 2026-11-07). Quitting the app, or
  switching to another panel, while scenes are unsaved asks Save All, Discard or Cancel, naming
  them. Connecting to the same panel again keeps them.
- **A refused write says why.** An invalid scene shows each failure the host names. A scene that
  was saved elsewhere since it was read says so, offering to save over it or to discard this
  edit and read the host's. Any other failure keeps the edits unsaved and names the failure.
- **Edits keep every card's settings.** Today a kept layout is matched to its cards' entries from
  a fresh read of the scene. That read gives the cards new identities, so reopening an edited
  scene, its thumbnail and Duplicate each lose every card setting but its cells. Each edit now
  stays with the read it was made from. This must be fixed before a save can write the entries.

## Capabilities

### New Capabilities

- `scene-saving`: How the app writes a panel's scenes to its host: Save, Rename and Delete, how
  unsaved scenes are marked, how a refused write is shown, and the prompt before unsaved scenes are
  lost.

### Modified Capabilities

- `scene-canvas`: "Edits last until the app quits" becomes "Edits are kept until saved or
  discarded", and a kept edit keeps each card's entry from the document it came from.
- `scene-gallery`: Duplicate's copy is kept in the app until its first Save rather than until the
  app quits, and is named so it differs from every other scene's name. The gallery marks unsaved
  scenes and offers Rename… and Delete… on stored scenes and copies.
- `panel-window`: Adding a panel or choosing a found one first settles any unsaved scenes, as
  `scene-saving` says, before replacing the panel held.

## Impact

- **Code:** In `ConsoleCore`, `HostClient+Scenes` gains create, write and delete, and reads each
  scene's revision. `SceneDocument` carries `rev`. `SceneDrafts` keeps each draft with the
  `LaidOutScene` it was read from, knows which are unsaved, and names copies. `PanelScenes` gains
  save, rename and delete, which update its scenes from the host's answer. In the app target,
  `SceneEditorView` gains Save and an editable title, `SceneGallery` gains Rename… and Delete…, a
  Save command joins the File menu, `AppDelegate` asks before quitting, and the panel picker and Add
  Panel ask before switching. `SceneStore` moves a saved copy's thumbnail to the scene's new id.
- **Sequencing:** `library-render` is being built and also changes `SceneStore` and
  `SceneEditorView`. Build this change after it is archived.
- **Host and audio-vue:** none. Create, write, delete and their refusals are in the saved
  contract.
- **Referenced specs:** `audio-vue:settings-store` (a stored scene's host-assigned id that never
  changes, its `name:` as a label that may repeat a built-in's, built-ins refused for writes and
  deletes, one revision per document with a stale base refused with the current revision, a write
  leaving the screen unchanged, a delete refused for the scene on screen and the boot scene, a fixed
  key refused in a stored scene, a write validated whole and refused with every failure),
  `audio-vue:control-api` (scenes have create, write and delete routes in the published contract).
  The status codes and bodies (201, 200, 204, 409 `Stale` with `current_rev`, 422 `Invalid` with
  `failures` of `place` and `message`, 409 `Refusal`, 404) are stated only by the saved contract,
  which stands level with audio-vue's specs as a source (`host-contract.md`).
