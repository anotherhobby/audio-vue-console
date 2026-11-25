# Spec Delta

## MODIFIED Requirements

### Requirement: A resize stops at a neighbour's edge

Resizing a card SHALL move only the edges being dragged, by whole cells. Each edge SHALL stop at the
grid's edge and at the edge of any card in its path. A card SHALL be no lower than its readable
floor at its width (`card-minimum`), and SHALL be narrowed only to widths its height can show its
reading at; one already below its floor SHALL NOT be made smaller.

Source: Decision (maintainer, 2026-11-02): a resize stops at the neighbour's edge, by the same rule
as a drop. audio-vue `card-layout`: no resize below a card's minimum (maintainer, 2026-11-04,
2026-11-07). Decision (maintainer, 2026-11-24): a resize stops before Too Small, not at the
declared minimum.

#### Scenario: Growing into free cells

- **WHEN** a card's right edge is dragged 3 columns right into free cells
- **THEN** the card is 3 columns wider

#### Scenario: Growing into a neighbour

- **WHEN** a card's right edge is dragged 6 columns right and a card starts 2 columns away on rows it
  shares
- **THEN** the card is 2 columns wider and meets the neighbour

#### Scenario: Shrinking to the minimum

- **WHEN** a card 20 columns wide, whose answer starts at 17 columns and whose height reads at
  every width it holds, has its left edge dragged 6 columns right
- **THEN** the card is 17 columns wide, ending where it ended

#### Scenario: A card already below its minimum

- **WHEN** a card 10 rows high whose readable floor at its width is 12 rows has its bottom edge
  dragged 2 rows up
- **THEN** the card stays 10 rows high

#### Scenario: Narrowing stops where the height cannot read

- **WHEN** a waveform 20 × 8 whose readable floor is 8 rows at 20 columns and 9 rows at 19 has its
  right edge dragged 3 columns left
- **THEN** it stays 20 columns wide, and no edge grows

#### Scenario: Narrowing a taller card

- **WHEN** the same waveform is 20 × 10, its floor 10 rows at 17 columns, and its right edge is
  dragged 3 columns left
- **THEN** it is 17 columns wide and 10 rows high
