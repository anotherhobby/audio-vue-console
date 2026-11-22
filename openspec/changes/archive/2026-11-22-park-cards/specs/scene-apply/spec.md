# Spec Delta

## MODIFIED Requirements

### Requirement: Apply works on any scene that fits the panel

Apply SHALL be enabled for every scene the gallery lists, built-in, stored or a copy, that is not
too wide for the panel and has no card parked (`card-parking`). For a scene too wide, or one with a
parked card, it SHALL be disabled, saying why.

Source: Decision (maintainer, 2026-11-07, 2026-11-21). audio-vue `scene-grid`, "A switch to a scene
too wide for the display is refused". Decision (maintainer, 2026-11-22): apply is blocked while a
card is off the panel.

#### Scenario: A built-in scene

- **WHEN** the user opens the built-in RTA on a panel it fits
- **THEN** Apply is enabled

#### Scenario: A scene too wide

- **WHEN** the user opens a scene reaching column 96 for a 64-column panel
- **THEN** Apply is disabled, saying the scene is too wide for this panel

#### Scenario: Made to fit

- **WHEN** the user moves its cards within the panel's columns
- **THEN** Apply is enabled

#### Scenario: A parked card

- **WHEN** the user parks a card
- **THEN** Apply is disabled, saying the cards off the panel must be moved onto it
