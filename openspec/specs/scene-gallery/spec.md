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

### Requirement: This panel's shape comes first

The gallery SHALL list the scenes whose grid has the panel's shape under "For this panel", and the
others under "Other shapes", the panel's shape being its display's width over its height.

Source: `product.md`: scenes are tied to a display shape, the grid's columns over its rows.
audio-vue `scene-grid`: an unset grid is the declared default.

#### Scenario: An 8:3 panel

- **WHEN** the panel's display is 1920 by 720 and a scene's grid is 96 by 36
- **THEN** the scene is listed under "For this panel"

### Requirement: A thumbnail is the scene as the helper draws it

Each scene's thumbnail SHALL be its layers, drawn at the panel's size and scaled down, and SHALL be
its plain boxes until they are drawn or when they cannot be. The open scene's thumbnail SHALL follow
its edits.

Source: `scene-canvas`, "Edits last until the app quits": the gallery's thumbnail shows the edits.

#### Scenario: Thumbnails drawn

- **WHEN** the gallery is shown with the helper running
- **THEN** each thumbnail is replaced, one after another, by the scene as the helper draws it

### Requirement: Duplicate makes an unsaved copy

Duplicate, on a scene of this panel's shape that is not fixed, SHALL make a copy kept in the app, named
for the scene with "copy" after it, not built in and so editable, listed in the gallery and opened on
the canvas. It SHALL write nothing to the host, and the copy SHALL be gone when the app quits.

Source: `product.md`: built-in scenes are read-only, shown with "duplicate to edit"; saves are explicit.
Inferred (this change): saving to the host is a later change.

#### Scenario: Duplicating a built-in scene

- **WHEN** the user chooses Duplicate on the built-in scene RTA
- **THEN** the gallery lists "RTA copy", not marked built in, and the canvas opens it for editing

#### Scenario: Another shape

- **WHEN** a scene's shape is not the panel's
- **THEN** Duplicate for This Panel is shown and disabled
