# Spec Delta

## ADDED Requirements

### Requirement: The gallery's Apply is the editor's

Apply in the gallery (`scene-gallery`) SHALL do what the editor's Apply does: save a scene with
unsaved edits, a copy never saved included, then ask the panel to switch to it. It SHALL ask nothing
first, report as the editor's does, stop where the save fails, and be disabled where the editor's
would be, saying why.

Source: Decision (maintainer, 2026-11-24): scenes are applied without going into the editor; an
unsaved scene is saved, then applied, as from the editor.

#### Scenario: A stored scene with no edits

- **WHEN** the user chooses Apply on "Studio" in the gallery, with no unsaved edits
- **THEN** nothing is saved, the panel switches to "Studio", and the gallery says the scene is on the
  panel and whether capture was kept

#### Scenario: A scene with unsaved edits

- **WHEN** "Studio" is marked unsaved and the user chooses its Apply in the gallery
- **THEN** the host stores the next revision, the panel switches to it, and "Studio" is no longer
  marked unsaved

#### Scenario: A copy never saved

- **WHEN** the user chooses Apply on "RTA copy", never saved
- **THEN** the host stores it as a new scene, the panel switches to it, and the gallery lists it as
  stored

#### Scenario: A save that fails

- **WHEN** the user chooses Apply in the gallery and the host refuses the save
- **THEN** the panel is not switched, and the gallery shows why, as for a Save

#### Scenario: A parked card

- **WHEN** "Studio" has a parked card
- **THEN** its Apply in the gallery is disabled, saying the cards off the panel must be moved onto it
