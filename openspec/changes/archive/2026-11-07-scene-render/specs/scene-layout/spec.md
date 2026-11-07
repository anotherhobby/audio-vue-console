# Spec Delta

## MODIFIED Requirements

### Requirement: A resize stops at a neighbour's edge

Resizing a card SHALL move only the edges being dragged, by whole cells. Each edge SHALL stop at the
grid's edge and at the edge of any card in its path. A card SHALL be no smaller than its declared
minimum, or one cell where it declares none, nor made smaller when already below it.

Source: Decision (maintainer, 2026-11-02): a resize stops at the neighbour's edge, by the same rule
as a drop. audio-vue `card-layout`: no resize below a card's minimum (maintainer, 2026-11-04,
2026-11-07).

#### Scenario: Growing into free cells

- **WHEN** a card's right edge is dragged 3 columns right into free cells
- **THEN** the card is 3 columns wider

#### Scenario: Growing into a neighbour

- **WHEN** a card's right edge is dragged 6 columns right and a card starts 2 columns away on rows it
  shares
- **THEN** the card is 2 columns wider and meets the neighbour

#### Scenario: Shrinking to the minimum

- **WHEN** a card 20 columns wide whose minimum is 17 columns has its left edge dragged 6 columns right
- **THEN** the card is 17 columns wide, ending where it ended

#### Scenario: A card already below its minimum

- **WHEN** a card 10 columns wide whose minimum is 17 has its right edge dragged 2 columns left
- **THEN** the card stays 10 columns wide
