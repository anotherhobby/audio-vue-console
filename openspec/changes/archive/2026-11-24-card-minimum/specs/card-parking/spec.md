# Spec Delta

## MODIFIED Requirements

### Requirement: A parked card resizes within the pane

Dragging a parked card's handle SHALL resize it in whole cells, as one step named Resize, stopping
at the panel's edge, at any parked card in its path, at the pane's edge, and at its readable floor
as a card on the grid does (`scene-layout`, `card-minimum`). A resize SHALL never take a parked card
onto the panel.

Source: Decision (maintainer, 2026-11-24): a parked card resizes as a card on the panel does,
stopping before Too Small; a card is wholly on the panel or wholly off it (2026-11-22).

#### Scenario: Growing a parked card

- **WHEN** a parked 10 × 4 card has free pane cells to its right and the user drags its right handle
  3 columns right
- **THEN** it is 13 columns wide, and Edit offers Undo Resize

#### Scenario: Stopping at the panel's edge

- **WHEN** a card parked on the row below the grid is dragged by its top handle 2 rows up
- **THEN** it does not grow, as its top edge already meets the panel

#### Scenario: Stopping at another parked card

- **WHEN** a parked card's right handle is dragged into another parked card
- **THEN** its right edge stops at that card's left edge

#### Scenario: Stopping at the pane's edge

- **WHEN** a parked card's bottom handle is dragged past the pane's last row
- **THEN** its bottom edge stops at the pane's last row

#### Scenario: The declared minimum

- **WHEN** a parked meter's minimum is still being asked for, its declared minimum 8 × 6, and it is
  shrunk by dragging a corner 5 cells in
- **THEN** it stops at 8 × 6

#### Scenario: The readable floor

- **WHEN** a parked meter 12 × 10 whose readable floor is 7 rows at 12 columns has its bottom handle
  dragged 5 rows up
- **THEN** it stops at 12 × 7
