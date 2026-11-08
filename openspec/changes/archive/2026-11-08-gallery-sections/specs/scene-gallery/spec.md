# Spec Delta

## RENAMED Requirements

- FROM: `### Requirement: This panel's shape comes first`
- TO: `### Requirement: My scenes, then the built-ins, then other shapes`

## MODIFIED Requirements

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
