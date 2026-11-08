# Proposal

## Why

The canvas edits scenes and Duplicate makes copies, but nothing reaches the panel: every edit and
copy is gone when the app quits (`scene-canvas`, "Edits last until the app quits"). The host has
stored scenes with revisions since `settings-store`, so the app can now save what the user makes,
name it, delete what they no longer want, go back to an earlier version, and put a scene on the
panel to see it running. The meter's measurement can also be restarted from the app, as a meter's
reset button does. Without this, the scene editor cannot be used for real work.

## What Changes

- **Save writes the open scene to the host.** Save (⌘S, and a toolbar button) stores the open
  scene's layout as its next revision, or, for a copy, creates the scene on the host. Only scenes
  the canvas may edit can be saved: never a built-in, and never a scene shaped for another panel.
  Writing a scene leaves the panel's screen as it is.
- **A copy stays in the app until its first Save** (maintainer, 2026-11-07). Duplicate makes an
  unsaved copy, as it does today. Saving it creates the scene on the host, which gives it its id. An
  abandoned copy leaves nothing on the panel's SD card.
- **Unsaved scenes are marked.** The gallery and the editor mark a scene with unsaved edits, and
  every copy not yet saved. Undoing back to the saved layout clears the mark.
- **Revert discards unsaved edits** (maintainer, 2026-11-07). Revert to Saved puts the open scene
  back as the host holds it, and can itself be undone. It is unavailable when nothing is unsaved,
  and for a copy never saved. It never writes to the host or touches the panel.
- **Versions restores an earlier revision** (maintainer, 2026-11-07). A Versions menu in the editor
  lists the scene's current version and the revisions the host keeps, by date and time. Choosing one
  loads it on the canvas as an unsaved edit, keeping the scene's current name. Save stores it as a
  new revision on top, so no revision is lost, and Revert goes back to the current version.
- **Rename writes at once** (maintainer, 2026-11-07). Rename… in the gallery's menu and the editor's
  title rename a stored scene by storing a new revision whose `name:` is the new name. Unsaved
  layout edits stay unsaved. Renaming a copy that has never been saved only renames the copy. A name
  cannot be empty. Duplicate names the copy "*name* copy", then "*name* copy 2" and so on where the
  first is taken.
- **Delete removes a stored scene** after asking, since its kept revisions go with it and it cannot
  be undone. Deleting a copy that has never been saved only discards it. Built-in scenes offer
  neither Rename nor Delete. The host refuses to delete the scene on screen and the one the panel
  starts on, and the app shows the host's reason.
- **Apply saves the scene and puts it on the panel** (maintainer, 2026-11-07). Apply saves the open
  scene if it has unsaved edits, creating a copy first if need be, then switches the panel to it.
  It works on any scene of the panel's shape, built-ins included, and is disabled for another
  shape. It asks nothing first. Afterwards it says whether capture was kept or rebuilt, and when
  rebuilt, that history restarted and why. An applied scene becomes the one the panel starts on.
- **Saving the scene on screen says the panel is behind** (maintainer, 2026-11-07). Save never
  changes the panel. When the saved scene is the one on screen, the editor says the panel shows an
  earlier version until Apply, or until the panel shows another scene.
- **Reset restarts the meter's measurement** (maintainer, 2026-11-07). A Reset button in the
  editor's toolbar and in the Panel page's Status section restarts the panel's measurement through
  a reset command audio-vue is asked to add. It does not ask first, as a meter's reset button does
  not.
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

- `scene-saving`: How the app writes a panel's scenes to its host: Save, Rename and Delete, Revert
  and Versions, how unsaved scenes are marked, how a refused write is shown, and the prompt before
  unsaved scenes are lost.
- `scene-apply`: How the app puts a scene on the panel and restarts its measurement: Apply, what it
  reports and when it is refused, the note that the panel shows an earlier version, and Reset.

### Modified Capabilities

- `scene-canvas`: "Edits last until the app quits" becomes "Edits are kept until saved or
  discarded", and a kept edit keeps each card's entry from the document it came from.
- `scene-gallery`: Duplicate's copy is kept in the app until its first Save rather than until the
  app quits, and is named so it differs from every other scene's name. The gallery marks unsaved
  scenes and offers Rename… and Delete… on stored scenes and copies.
- `panel-window`: Adding a panel or choosing a found one first settles any unsaved scenes, as
  `scene-saving` says, before replacing the panel held. The Status section gains Reset.

## Impact

- **Code:** In `ConsoleCore`, `HostClient+Scenes` gains create, write, delete and the revisions
  read, and reads each scene's revision. `HostClient` gains the switch and reset commands with their
  outcome. `SceneDocument` carries `rev`. `PanelState` carries the scene on screen by its id
  (`spec`). `SceneDrafts` keeps each draft with the `LaidOutScene` it was read from, knows which are
  unsaved, reverts, loads a version, and names copies. `PanelScenes` gains save, rename, delete,
  apply and the revisions, which update its scenes from the host's answer. In the app target,
  `SceneEditorView` gains Save, Apply, Revert, Versions, Reset, an editable title and a banner,
  `SceneGallery` gains Rename… and Delete…, Save and Revert join the File menu, `AppDelegate` asks
  before quitting, the panel picker and Add Panel ask before switching, the Panel page's Status
  gains Reset, and the live state reaches the Scenes page. `SceneStore` moves a saved copy's
  thumbnail to the scene's new id.
- **Sequencing:** `library-render`, which also changed `SceneStore` and `SceneEditorView`, is
  archived (2026-11-07), so this change builds on it.
- **Host and audio-vue:** two asks, sent as a handoff on 2026-11-07. audio-vue gives a done switch
  an answer model of its own with `scene`, `capture`, `why` and `recorded` (decided 2026-11-07, its
  change `command-results-and-reset`, not yet built), and adds a `reset` command with its route
  (answered separately through the same change). Apply's report and Reset wait on them. Everything
  else uses routes already in the saved contract.
- **Referenced specs:** `audio-vue:settings-store` (a stored scene's host-assigned id that never
  changes, its `name:` as a label that may repeat a built-in's, built-ins refused for writes and
  deletes, one revision per document with a stale base refused with the current revision, a write
  validated whole and refused with every failure, earlier revisions kept for a revert, a write
  leaving the screen unchanged, a delete refused for the scene on screen and the boot scene, a fixed
  key refused in a stored scene), `audio-vue:control-api` (scenes have create, write, delete and
  revisions routes in the published contract; a command says what became of it, done, refused,
  expired, unknown or no panel; every command but `saver` wakes the display),
  `audio-vue:control-commands` (a switch names a roster scene and puts up a stored scene's current
  revision; a command says what happened, with what forced a rebuild; commands are refused on the
  audio-vue screen; a switch is refused during a calibration; the last scene switched to comes
  back). The status codes and bodies (201, 200, 204, 409 `Stale` with `current_rev`, 422 `Invalid`
  with `failures` of `place` and `message`, 409 `Refusal`, 404; an `Outcome` with 200, 409, 503 and
  504) are stated only by the saved contract, which stands level with audio-vue's specs as a source
  (`host-contract.md`).
