# Spec Delta

## Purpose

How the app writes a paired panel's scenes to its host: Save, Rename and Delete, how unsaved scenes
are marked, how a refused write is shown, and the prompt before unsaved scenes are lost.

## ADDED Requirements

### Requirement: Save stores the open scene on the host

Save, by ⌘S or the editor's toolbar, SHALL store the open scene's layout on the host as its next
revision, based on the revision the app holds, with the rest of its document as the host gave it.

Source: `product.md`: saves are explicit. audio-vue `settings-store`: each write names its base
revision.

#### Scenario: Saving an edited scene

- **WHEN** the user moves a card in the stored scene "My RTA" at revision 3 and presses ⌘S
- **THEN** the host stores revision 4 with the card in its new cells, and the scene is no longer
  marked unsaved

#### Scenario: Card settings survive a save

- **WHEN** a card in a stored scene carries settings of its own and the user moves another card and
  saves
- **THEN** the stored revision holds the first card's settings unchanged

### Requirement: A copy's first Save creates it

Saving a copy never saved SHALL create it on the host, and from then on the copy SHALL be that
stored scene, under the id the host gave it, in the gallery and in the open editor.

Source: audio-vue `settings-store`: a stored scene is named by an id the host assigns. Decision
(maintainer, 2026-11-07): a copy reaches the host at its first Save.

#### Scenario: Saving a copy

- **WHEN** the user duplicates the built-in RTA, adds a card and presses ⌘S
- **THEN** the host lists a new stored scene named "RTA copy" with that card, the gallery lists it
  once, not marked unsaved, and the editor stays open on it

### Requirement: Only an editable scene is saved

Save SHALL be enabled only for a scene the canvas may edit that is unsaved. It SHALL NOT be offered
for a built-in scene or a scene shaped for another panel.

Source: `scene-canvas`, "A read-only scene can be looked at, not edited". audio-vue
`settings-store`: a built-in is refused for a write.

#### Scenario: A built-in scene

- **WHEN** the user opens the built-in RTA
- **THEN** Save is disabled

#### Scenario: Nothing to save

- **WHEN** the user opens a stored scene and makes no edit
- **THEN** Save is disabled

### Requirement: Saving leaves the screen as it is

Saving, renaming or deleting a scene SHALL NOT switch or reload the panel, and the app SHALL NOT
say the panel now shows the saved scene.

Source: audio-vue `settings-store`: writing a scene never changes the screen; a reload or a switch
does. `product.md`: no live preview; Apply, which saves and reloads, is a separate button.

#### Scenario: Saving the scene on screen

- **WHEN** the panel shows "My RTA" and the user saves an edit to it
- **THEN** the panel keeps drawing the revision it had loaded

### Requirement: Unsaved scenes are marked

The gallery and the editor's title SHALL mark a scene whose layout differs from the one the host
holds, and every copy not yet saved. A layout undone back to the host's SHALL lose the mark.

Source: Inferred (this change): with explicit saves, the user must see what a quit or switch
would lose.

#### Scenario: An edit marks the scene

- **WHEN** the user moves a card in "My RTA"
- **THEN** the editor's title and the gallery mark "My RTA" as unsaved

#### Scenario: Undoing to the saved layout

- **WHEN** the user moves a card in a saved scene and then undoes the move
- **THEN** the scene is no longer marked unsaved

### Requirement: Rename stores the new name at once

Renaming a stored scene, from the gallery's Rename… or the editor's title, SHALL store at once a new
revision of the host's current document with `name:` set to the new name, and SHALL leave the
scene's unsaved edits unsaved. Renaming a copy never saved SHALL only rename the copy.

Source: Decision (maintainer, 2026-11-07): a rename writes at once, keeping unsaved layout edits as
a draft. audio-vue `settings-store`: a scene's name is its document's `name:`, a label; its id never
changes.

#### Scenario: Renaming a scene with unsaved edits

- **WHEN** "My RTA" has an unsaved card move and the user renames it "Studio"
- **THEN** the host lists the scene as "Studio" with its saved layout, and the card move is still
  shown and still marked unsaved

#### Scenario: Renaming an unsaved copy

- **WHEN** the user renames the unsaved copy "RTA copy" to "Wide"
- **THEN** the gallery lists "Wide", still unsaved, and nothing is written to the host

### Requirement: A name is not empty

A rename SHALL be refused, saying a scene needs a name, when the new name is empty or only
whitespace. Leading and trailing whitespace SHALL be trimmed. A name another scene has SHALL be
accepted.

Source: audio-vue `settings-store`: a stored scene's name may be any label, a built-in's included;
an empty `name:` leaves a client nothing to show. Inferred (this change).

#### Scenario: An empty name

- **WHEN** the user clears a scene's name and confirms
- **THEN** the rename is refused, saying a scene needs a name, and the name is unchanged

### Requirement: Built-in scenes are neither renamed nor deleted

The app SHALL NOT offer Rename or Delete for a built-in scene. Rename and Delete SHALL be offered
for a stored scene of any shape and for a copy never saved.

Source: audio-vue `settings-store`: a built-in is refused for a write or a delete. `product.md`:
built-in scenes are read-only.

#### Scenario: A built-in's menu

- **WHEN** the user opens the gallery menu of the built-in RTA
- **THEN** it offers neither Rename… nor Delete…

#### Scenario: A stored scene of another shape

- **WHEN** the user opens the gallery menu of a stored scene shaped for another panel
- **THEN** it offers Rename… and Delete…

### Requirement: Delete asks, then removes the scene

Delete… on a stored scene SHALL ask first, naming the scene and saying it cannot be undone, and on
confirmation SHALL delete it on the host, remove it from the gallery and close it if open. Delete… on
a copy never saved SHALL discard it without writing to the host.

Source: audio-vue `settings-store`: a delete removes a stored scene with its revisions. Inferred
(this change): a delete cannot be undone, so it is confirmed.

#### Scenario: Deleting a stored scene

- **WHEN** the user chooses Delete… on "Studio" and confirms
- **THEN** the host no longer lists "Studio", and the gallery does not show it

#### Scenario: Cancelling

- **WHEN** the user chooses Delete… on "Studio" and cancels
- **THEN** nothing is written, and "Studio" stays

### Requirement: A refused delete says why

When the host refuses a delete, the app SHALL show the host's reason and keep the scene.

Source: audio-vue `settings-store`: a delete is refused for the scene on screen and for the scene the
panel is recorded to start on, naming why.

#### Scenario: The scene on screen

- **WHEN** the user deletes the scene the panel shows
- **THEN** the app shows the host's reason, that the scene is on screen, and the scene stays

### Requirement: An invalid scene names each failure

When the host refuses a save or rename as invalid, the app SHALL show each failure it names, with
its place and message, and SHALL keep the edits unsaved.

Source: audio-vue `control-api`: an invalid document is refused with every failure, each by its
place and what is wrong.

#### Scenario: A refused save

- **WHEN** the host refuses a save with a failure at a card's place
- **THEN** the app shows that failure, and the scene stays marked unsaved

### Requirement: A scene saved elsewhere is not overwritten unasked

When the host refuses a save or rename because the scene has a newer revision, the app SHALL say the
scene was changed elsewhere and offer Save Over It, which stores the edit over the newer revision,
and Discard Mine, which drops the edit and reads the host's scene.

Source: audio-vue `settings-store`: a write on a stale base is refused with the current revision.
Recommended (this change): one user's two clients are the likely case, so the choice is theirs.

#### Scenario: Saving over a newer revision

- **WHEN** the app holds revision 3 of "Studio", another client stores revision 4, and the user saves
  and chooses Save Over It
- **THEN** the host stores revision 5 with this app's layout

#### Scenario: Discarding the edit

- **WHEN** the same save is refused and the user chooses Discard Mine
- **THEN** the canvas shows revision 4 as the host holds it, not marked unsaved

### Requirement: Any other failed write keeps the edits

When a save, rename or delete fails for any other reason, the app SHALL name the failure and keep
the scene and its edits as they were.

Source: Inferred (this change): a failed write must lose nothing the user made.

#### Scenario: The host is unreachable

- **WHEN** the user saves while the host does not answer
- **THEN** the app says the host could not be reached, and the scene stays marked unsaved

### Requirement: Unsaved scenes are settled before they are lost

Quitting the app, or connecting to another panel, while scenes are unsaved SHALL first ask, naming
them, to Save All, Discard or Cancel. Save All SHALL save each and go on only if every save
succeeds. Cancel SHALL leave everything as it was. Connecting to the same panel again SHALL keep
unsaved scenes.

Source: Decision (maintainer, 2026-11-07): quitting or switching panels with unsaved scenes asks
Save / Discard, listing them.

#### Scenario: Quitting with an unsaved scene

- **WHEN** "Studio" is unsaved and the user quits and chooses Save All
- **THEN** the host stores "Studio", and the app quits

#### Scenario: A save fails while quitting

- **WHEN** the user quits, chooses Save All, and the host refuses one save
- **THEN** the app does not quit, and shows why that save failed

#### Scenario: Switching panels

- **WHEN** "Studio" is unsaved and the user chooses another panel in the picker and chooses Discard
- **THEN** the app connects to the other panel, and "Studio"'s edits are gone

#### Scenario: Reconnecting to the same panel

- **WHEN** "Studio" is unsaved and the app connects to the same panel again
- **THEN** nothing is asked, and "Studio" is still shown with its edits, marked unsaved
