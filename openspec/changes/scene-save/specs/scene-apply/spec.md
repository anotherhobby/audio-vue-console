# Spec Delta

## Purpose

How the app puts a scene on the paired panel and restarts the panel's measurement: Apply, what it
reports and when it is refused, the note that the panel shows an earlier version, and Reset.

## ADDED Requirements

### Requirement: Apply saves the scene, then puts it on the panel

Apply, in the editor's toolbar, SHALL save the open scene as `scene-saving` says when it has unsaved
edits, creating a copy never saved, and SHALL then ask the panel to switch to the scene by its id.
When the save fails, Apply SHALL stop and SHALL NOT switch.

Source: Decision (maintainer, 2026-11-07): Save stores, Apply saves and switches. audio-vue
`control-commands`, "A switch names a scene on the roster": a stored scene's id puts up its current
revision.

#### Scenario: Applying an edit

- **WHEN** the user moves a card in "Studio" and chooses Apply
- **THEN** the host stores the next revision, and the panel switches to "Studio" and draws it

#### Scenario: Applying the scene on screen

- **WHEN** the panel shows "Studio" and the user edits it and chooses Apply
- **THEN** the panel draws the revision just saved

#### Scenario: Applying a scene just opened

- **WHEN** the user opens the built-in RTA and chooses Apply
- **THEN** nothing is saved, and the panel switches to RTA

#### Scenario: A save that fails

- **WHEN** the user chooses Apply and the host refuses the save as invalid
- **THEN** the panel is not switched, and the failures are shown as for a Save

### Requirement: Apply works on any scene of the panel's shape

Apply SHALL be enabled for a scene of the panel's shape, built-in, stored or a copy, and SHALL be
disabled, saying why, for a scene shaped for another panel.

Source: Decision (maintainer, 2026-11-07): Apply covers built-ins but not other shapes.

#### Scenario: Another shape

- **WHEN** the user opens a scene shaped for another panel
- **THEN** Apply is disabled, saying the scene is shaped for another panel

### Requirement: Apply asks nothing first and says what it cost

Apply SHALL NOT ask before switching. When the switch is done, the app SHALL say the scene is on the
panel and whether capture was kept or rebuilt, and when rebuilt, that history restarted and what
forced it, as the panel names it.

Source: Decision (maintainer, 2026-11-07): no confirmation before Apply; the app reports after.
audio-vue `control-commands`, "A command says what happened": the caller hears whether capture was
kept or rebuilt and what forced a rebuild.

#### Scenario: Capture kept

- **WHEN** the user applies a scene whose cards the running capture serves
- **THEN** the app says the scene is on the panel and capture was kept

#### Scenario: Capture rebuilt

- **WHEN** the user applies a scene with a card wanting 60 s of history where 30 s is running
- **THEN** the app asks nothing first, then says capture was rebuilt and history restarted, naming
  the history the panel gives as the reason

### Requirement: An unrecorded Apply says the panel will not start on it

When a done switch was not recorded as the panel's next start, the app SHALL add to its report that
the panel will not start on this scene. When it was recorded, the report SHALL NOT mention it.

Source: Decision (maintainer, 2026-11-07): mention the record only when it failed. audio-vue
`control-commands`, "The last scene switched to comes back": the caller hears when a switch was not
recorded.

#### Scenario: A switch not recorded

- **WHEN** the user applies a scene and the panel answers that the switch was not recorded
- **THEN** the app says the scene is on the panel, and that the panel will not start on it

#### Scenario: A switch recorded

- **WHEN** the user applies a scene and the switch was recorded
- **THEN** the report says nothing about what the panel starts on

### Requirement: A refused Apply says why

When the panel refuses the switch, the app SHALL show the panel's reason. When no panel answers, it
SHALL say so. When the outcome expired or is unknown, it SHALL say the panel may or may not have
switched. In every case a save Apply made SHALL stand.

Source: audio-vue `control-api`, "A command says what became of it": done, refused, expired,
unknown or no panel, each distinct. `control-commands`: a switch is refused during a calibration
and on the audio-vue screen.

#### Scenario: During a calibration

- **WHEN** the user applies a scene while a calibration has the panel
- **THEN** the app shows the panel's reason, the scene is saved, and the panel is not switched

#### Scenario: The panel is down

- **WHEN** the user applies a scene and no panel answers
- **THEN** the app says no panel answered, and the scene is saved

### Requirement: Saving the scene on screen says the panel is behind

After the user saves the scene the panel shows, the editor SHALL say the panel shows an earlier
version of it, until an Apply of that scene, or until the panel shows another scene. The note SHALL
be held only while the app runs.

Source: Decision (maintainer, 2026-11-07): Save stays store-only, and the app says when the panel is
behind. audio-vue `settings-store`: a write never changes the screen.

#### Scenario: Saving the scene on screen

- **WHEN** the panel shows "Studio" and the user saves an edit to it
- **THEN** the editor says the panel shows an earlier version, and Apply updates it

#### Scenario: Applying clears the note

- **WHEN** the note is shown and the user chooses Apply, and the switch is done
- **THEN** the note is gone

#### Scenario: Another scene goes up

- **WHEN** the note is shown and the panel switches to another scene
- **THEN** the note is gone

### Requirement: Reset restarts the panel's measurement

Reset, in the editor's toolbar and in the Panel page's Status section, SHALL ask the panel to reset
its measurement, without asking first, and SHALL say whether it was done or why not, as for Apply.

Source: Decision (maintainer, 2026-11-07): a Reset button, as the standards call it, in the editor and
on the Panel page. audio-vue's reset command, asked for in `console-commands-handoff.md`; what it
restarts is audio-vue's to state.

#### Scenario: A reset

- **WHEN** the user chooses Reset while the panel draws a scene
- **THEN** the panel restarts its measurement, and the app says it was done

#### Scenario: A refused reset

- **WHEN** the panel refuses a reset
- **THEN** the app shows the panel's reason
