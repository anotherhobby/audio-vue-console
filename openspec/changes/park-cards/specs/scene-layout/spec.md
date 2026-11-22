# Spec Delta

## MODIFIED Requirements

### Requirement: A move keeps to the grid and refuses taken cells

Moving cards SHALL shift them together by whole cells, keeping their sizes. A nudge past the grid's
edge SHALL stop at the edge. A drag that would take any moved card past the edge SHALL park the
cards instead (`card-parking`). A move that lands any moved card on a card not being moved SHALL be
refused, leaving every card where it was.

Source: Decision (maintainer, 2026-11-02): cards never overlap, and no push and no swap. Decision
(maintainer, 2026-11-22): a card dragged off the panel is parked.

#### Scenario: A move into free cells

- **WHEN** a card is moved 4 columns right into free cells
- **THEN** it is 4 columns right, at the same size

#### Scenario: A move past the edge

- **WHEN** a card 2 columns from the grid's right edge is nudged 4 columns right with shift held
- **THEN** it ends at the right edge, 2 columns right

#### Scenario: A drag past the edge

- **WHEN** a card 2 columns from the grid's right edge is dragged 5 columns right
- **THEN** it is parked off the grid (`card-parking`), and no longer in the layout

#### Scenario: A move onto another card

- **WHEN** a move would land a card on any cell of a card not being moved
- **THEN** the move is refused, saying the space is taken, and no card moves

#### Scenario: Two cards moved together

- **WHEN** two cards side by side are moved one column right as one move, the left card into cells
  the right card leaves
- **THEN** both move, since neither lands on a card that stays put
