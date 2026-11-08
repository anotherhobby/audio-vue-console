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

### Requirement: My scenes, then the built-ins, then other shapes

The gallery SHALL list the scenes of the panel's shape under "My Scenes" when not built in, then
under "Built-in Scenes" when built in, and every other scene last under "Other Shapes", none
dimmed. An empty "My Scenes" or "Built-in Scenes" SHALL say what goes there; an empty "Other
Shapes" SHALL be left out.

Source: `product.md`: scenes are tied to a display shape. audio-vue `scene-grid`: a scene is fitted
to the display at its own aspect. Decision (maintainer, 2026-11-07).

#### Scenario: An 8:3 panel

- **WHEN** the panel's display is 1920 by 720, and the host lists the built-in RTA (grid 96 by 36),
  the built-in Default (no grid, so 64 by 36), and the stored "My RTA" (96 by 36) and "Wide" (64 by
  36)
- **THEN** "My Scenes" lists "My RTA", "Built-in Scenes" lists RTA, "Other Shapes" lists Default and
  "Wide", and none is dimmed

#### Scenario: An unsaved copy

- **WHEN** the user duplicates the built-in RTA
- **THEN** "RTA copy" is listed under "My Scenes"

#### Scenario: No scenes of the user's

- **WHEN** the host lists only built-in scenes and there is no copy
- **THEN** "My Scenes" is shown, saying a built-in scene is duplicated to make one

#### Scenario: Every scene fits

- **WHEN** every scene the host lists has the panel's shape
- **THEN** no "Other Shapes" section is shown

### Requirement: A thumbnail is the scene as the helper draws it

Each scene's thumbnail SHALL be its layers, drawn at the panel's size and scaled down, and SHALL be
its plain boxes until they are drawn or when they cannot be. The open scene's thumbnail SHALL follow
its edits.

Source: `scene-canvas`, "Edits last until the app quits": the gallery's thumbnail shows the edits.

#### Scenario: Thumbnails drawn

- **WHEN** the gallery is shown with the helper running
- **THEN** each thumbnail is replaced, one after another, by the scene as the helper draws it

### Requirement: Duplicate makes an unsaved copy

Duplicate, on a scene of this panel's shape that is not fixed, SHALL make a copy kept in the app, not
built in and so editable, listed in the gallery and opened on the canvas. The copy SHALL be named for
the scene with "copy" after it, or "copy 2", "copy 3" and on, the first no other scene has. It SHALL
write nothing to the host until the copy is saved, as `scene-saving` says.

Source: `product.md`: built-in scenes are read-only, shown with "duplicate to edit"; saves are explicit.
Decision (maintainer, 2026-11-07): a copy stays in the app until its first Save.

#### Scenario: Duplicating a built-in scene

- **WHEN** the user chooses Duplicate on the built-in scene RTA
- **THEN** the gallery lists "RTA copy", not marked built in and marked unsaved, the canvas opens it
  for editing, and the host lists no new scene

#### Scenario: Duplicating twice

- **WHEN** the gallery already lists "RTA copy" and the user duplicates RTA again
- **THEN** the new copy is named "RTA copy 2"

#### Scenario: Another shape

- **WHEN** a scene's shape is not the panel's
- **THEN** Duplicate for This Panel is shown and disabled
