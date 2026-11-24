# Spec Delta

## ADDED Requirements

### Requirement: Each scene has an Apply button beside its name

Each scene in the gallery, built-in, stored or a copy, SHALL show an Apply button beside its name,
which applies it as `scene-apply` says, without opening it. While an Apply is under way, every
gallery Apply SHALL be disabled.

Source: Decision (maintainer, 2026-11-24): next to each scene name, an apply button, so scenes are
applied without the scene editor.

#### Scenario: Applying RTA from the gallery

- **WHEN** the user chooses Apply beside the built-in RTA
- **THEN** the panel switches to RTA, and the gallery stays shown

#### Scenario: A scene too wide

- **WHEN** a scene reaches column 96 on a 64-column panel
- **THEN** its Apply is disabled, saying the scene is too wide for this panel

### Requirement: The gallery says what its last Apply did

The gallery SHALL show the outcome of its last Apply, naming the scene, as the editor's banner
says it (`scene-apply`), until the next Apply or the gallery is left. A refused or failed switch
SHALL be said there; a failed save SHALL be shown as for a Save.

Source: `scene-apply`, "Apply asks nothing first and says what it cost".

#### Scenario: Capture rebuilt

- **WHEN** the user applies "Studio" from the gallery and the panel rebuilds capture
- **THEN** the gallery says "Studio" is on the panel, that capture was rebuilt and history restarted,
  and why

#### Scenario: No panel answers

- **WHEN** the user applies "Studio" from the gallery and no panel answers
- **THEN** the gallery says no panel answered
