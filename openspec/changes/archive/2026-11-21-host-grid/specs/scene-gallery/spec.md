# Spec Delta

## ADDED Requirements

### Requirement: My scenes, then the built-ins

The gallery SHALL list the scenes not built in under "My Scenes", then the built-in ones under
"Built-in Scenes", none dimmed. An empty section SHALL say what goes there.

Source: Decision (maintainer, 2026-11-07, 2026-11-21): scenes are listed mine first; a scene has no
shape to sort by. audio-vue `scene-grid`: a scene is drawn on whichever display shows it.

#### Scenario: An 8:3 panel

- **WHEN** the host lists the built-in RTA and Default and the stored "My RTA" and "Wide"
- **THEN** "My Scenes" lists "My RTA" and "Wide", and "Built-in Scenes" lists RTA and Default

#### Scenario: An unsaved copy

- **WHEN** the user duplicates the built-in RTA
- **THEN** "RTA copy" is listed under "My Scenes"

#### Scenario: No scenes of the user's

- **WHEN** the host lists only built-in scenes and there is no copy
- **THEN** "My Scenes" is shown, saying how a scene is made

### Requirement: A scene too wide for the panel says so

A scene that places a card past the panel's last column SHALL be listed like any other, with a note
that it is too wide for this panel.

Source: Decision (maintainer, 2026-11-21): a scene too wide is listed and can be opened. audio-vue
`scene-grid`, "A scene too wide for the display is refused".

#### Scenario: A scene made for a wider panel

- **WHEN** the panel's grid has 64 columns and a stored scene places a card ending at column 96
- **THEN** the gallery lists it under "My Scenes" with the note

#### Scenario: A scene that fits

- **WHEN** every card of a scene ends within the panel's columns
- **THEN** it carries no note

### Requirement: A panel with no display offers no scenes to edit

While the panel's state gives no grid, the Scenes page SHALL say the panel has no display to lay
scenes out for, and SHALL offer no scene to open, make or duplicate.

Source: Decision (maintainer, 2026-11-21). audio-vue `control-state`: the display's grid is null
where there is no display yet.

#### Scenario: Before the display is open

- **WHEN** the panel's state gives no grid
- **THEN** the Scenes page says so and lists nothing to open

#### Scenario: The display opens

- **WHEN** the state then gives a grid
- **THEN** the gallery is shown

### Requirement: Duplicate makes an unsaved copy of any scene

Duplicate, on a scene that is not fixed, SHALL make an editable copy kept in the app, listed in the
gallery and opened on the canvas, named for the scene with "copy" after it, numbered from 2 where
that name is taken. It SHALL write nothing to the host until it is saved (`scene-saving`).

Source: `product.md`: built-in scenes are read-only, shown with "duplicate to edit"; saves are explicit.
Decision (maintainer, 2026-11-07): a copy stays in the app until its first Save.

#### Scenario: Duplicating a built-in scene

- **WHEN** the user chooses Duplicate on the built-in scene RTA
- **THEN** the gallery lists "RTA copy", not marked built in and marked unsaved, the canvas opens it
  for editing, and the host lists no new scene

#### Scenario: Duplicating twice

- **WHEN** the gallery already lists "RTA copy" and the user duplicates RTA again
- **THEN** the new copy is named "RTA copy 2"

#### Scenario: A scene too wide

- **WHEN** the user duplicates a scene too wide for the panel
- **THEN** the copy is made, as wide, and opened for editing

## REMOVED Requirements

### Requirement: My scenes, then the built-ins, then other shapes

**Reason**: A scene has no shape (audio-vue `host-grid`, 2026-11-21). Replaced by "My scenes, then
the built-ins" and "A scene too wide for the panel says so".
**Migration**: None.

### Requirement: Duplicate makes an unsaved copy

**Reason**: A scene of another shape is no longer set apart (audio-vue `host-grid`, 2026-11-21). Replaced by
"Duplicate makes an unsaved copy of any scene".
**Migration**: None.
