# Spec Delta

## ADDED Requirements

### Requirement: The pane around the panel is a grid of the panel's cells

While a scene is edited, the canvas pane outside the panel's outline SHALL be drawn as a light grid
whose cells are the panel's cells as drawn, lined up with the panel's columns and rows, so a parked
card covers whole cells of it. The grid SHALL follow the panel's size as the pane is resized or the
panel is drawn smaller. No grid line SHALL be drawn on the panel.

Source: Decision (maintainer, 2026-11-24): the space outside the scene is a light grid matching the
panel's grid.

#### Scenario: A card parked below

- **WHEN** a card is parked below the panel
- **THEN** its outline lies exactly on the grid's lines around the panel

#### Scenario: Narrowing the window

- **WHEN** the panel is drawn smaller to keep a parked card in view
- **THEN** the grid's cells shrink with the panel's and stay lined up with them

### Requirement: The Grid button picks the grid's colour

The editor's toolbar SHALL hold a Grid button at its far end, just before the Inspector button. It
SHALL offer a colour for the grid around the panel and a way back to the default. The colour SHALL
apply to every scene's editor at once and SHALL be kept across launches.

Source: Decision (maintainer, 2026-11-24): a grid button in the toolbar, to the far right just left of
the panel's button, changes the grid's colour.

#### Scenario: Choosing a colour

- **WHEN** the user chooses Grid and picks red
- **THEN** the grid around the panel is drawn in a light red, and stays so in another scene's editor
  and after the app is quit and opened again

#### Scenario: Back to the default

- **WHEN** the user chooses Grid and returns to the default colour
- **THEN** the grid is drawn in its default light colour
