# Spec Delta

## RENAMED Requirements

- FROM: `### Requirement: Apply works on any scene of the panel's shape`
- TO: `### Requirement: Apply works on any scene`

## MODIFIED Requirements

### Requirement: Apply works on any scene

Apply SHALL be enabled for every scene the gallery lists, built-in, stored or a copy, of the panel's
shape or another.

Source: Decision (maintainer, 2026-11-07): Apply covers built-ins and other shapes. audio-vue
`scene-grid`: a scene is fitted to the display at its own aspect, with backdrop outside it.

#### Scenario: Another shape

- **WHEN** the user opens the built-in Default, 16:9, on an 8:3 panel and chooses Apply
- **THEN** the panel switches to it, fitted to the display with backdrop either side

#### Scenario: A built-in scene

- **WHEN** the user opens the built-in RTA
- **THEN** Apply is enabled
