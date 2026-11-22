# scene-gallery Specification

## Purpose

The Scenes page's gallery of the connected panel's scenes: which scenes it lists, in what order, how
each is pictured, and Duplicate, which makes an editable copy kept in the app.

## Requirements

### Requirement: The gallery lists the panel's scenes

While paired with a host, the Scenes page SHALL list the host's scenes, each by its name, marked when
built in, and SHALL leave out a fixed scene. While not paired it SHALL say a panel must be paired to
show its scenes.

Source: audio-vue `control-api`: the scenes listing, with each scene's `built_in` and `fixed`; a
fixed scene is not offered to pick or duplicate.

#### Scenario: A host with its built-in scenes

- **WHEN** the paired host lists the scenes default, rta and calibration, calibration fixed
- **THEN** the gallery lists default and rta, each marked built in

#### Scenario: Not paired

- **WHEN** the app is not paired with the host it holds
- **THEN** the Scenes page says to pair with the panel to see its scenes

### Requirement: A thumbnail is the scene as the helper draws it

Each scene's thumbnail SHALL be its layers, drawn at the panel's size and scaled down, and SHALL be
its plain boxes until they are drawn or when they cannot be. The open scene's thumbnail SHALL follow
its edits.

Source: `scene-canvas`, "Edits last until the app quits": the gallery's thumbnail shows the edits.

#### Scenario: Thumbnails drawn

- **WHEN** the gallery is shown with the helper running
- **THEN** each thumbnail is replaced, one after another, by the scene as the helper draws it

### Requirement: New Scene makes an unsaved scene with no cards

New Scene, in the gallery's toolbar, SHALL make a scene with no cards on the panel's grid, kept in the app, listed under My Scenes and opened on the canvas, named "New Scene",
numbered from 2 where that name is taken. It SHALL write nothing to the host until it is saved
(`scene-saving`).

Source: maintainer, 2026-11-20: a new scene that starts with no cards.

#### Scenario: A new scene on an 8:3 panel

- **WHEN** the user chooses New Scene on a 1920 by 720 panel
- **THEN** the gallery lists "New Scene", marked unsaved, the canvas opens it on a 96 by 36 grid
  with no cards, and the host lists no new scene

#### Scenario: Twice

- **WHEN** the gallery already lists "New Scene" and the user chooses New Scene again
- **THEN** the new scene is named "New Scene 2"

### Requirement: A new scene is the app's alone until it holds a card

A scene with no cards SHALL be kept in the app like a new document: the canvas SHALL show its
backdrop as the helper draws it with no plates, the gallery SHALL show it without a drawn
thumbnail, and Save and Apply SHALL be disabled, Save saying a card is needed. Once it holds a
card it SHALL be drawn, saved and applied as any unsaved copy.

Source: maintainer, 2026-11-20: like a new document, not real until saved. audio-vue
`settings-schema`: a scene holds at least one card.

#### Scenario: Before the first card

- **WHEN** the user has made a new scene and placed no card
- **THEN** the canvas shows the default backdrop, as it will once a card is placed, with no
  refusal, and Save and Apply are disabled

#### Scenario: The first card

- **WHEN** the user drops a card on it
- **THEN** the backdrop and the card are drawn, and Save and Apply are enabled

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

### Requirement: Duplicate waits while a card is parked

Duplicate SHALL be disabled in the editor's toolbar and the gallery for a scene with a parked card
(`card-parking`), saying the cards off the panel must be moved onto it.

Source: Decision (maintainer, 2026-11-22): save, apply and duplicate are blocked while a card is
off the panel.

#### Scenario: A parked card

- **WHEN** "Studio" has a parked card
- **THEN** Duplicate is disabled for "Studio" in the editor and the gallery, saying the cards off
  the panel must be moved onto it

### Requirement: A scene with parked cards says so

The gallery SHALL list a scene that has parked cards like any other, with a note saying how many of
its cards are off the panel.

Source: Decision (maintainer, 2026-11-22): parked cards block saving, so the gallery shows where
they are left.

#### Scenario: Back in the gallery

- **WHEN** the user parks two cards in "Studio" and goes back to the gallery
- **THEN** "Studio" is marked unsaved and notes that two cards are off the panel
