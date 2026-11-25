# Spec Delta

## ADDED Requirements

### Requirement: A library tile is drawn at its card's whole minimum

Each library tile SHALL be drawn once, at its card's whole size in the open scene's settings
(`card-minimum`, "A card's whole size is the smallest whole one"), with its library setup where it
has one.

Source: Decision (maintainer, 2026-11-24): a card is shown at its whole minimum, plain tiles and
set-up tiles alike, replacing the 2026-11-21 ruling that a tile shows the smallest size that keeps
the reading.

#### Scenario: A meter with ticks

- **WHEN** the meter's tile is set up with ticks on, and the helper answers the meter whole with
  its ticks at 10 × 8 and no smaller
- **THEN** the meter's tile is drawn at 10 × 8 with its ticks

#### Scenario: A readout drawn whole above its minimum

- **WHEN** a readout's declared minimum is 8 by 4 cells and the helper answers it whole first at
  10 by 5
- **THEN** its tile is drawn at 10 by 5

## MODIFIED Requirements

### Requirement: A card that cannot show its reading at its minimum is named on its tile

When the helper reports a card as unable to show its reading at the size its tile is drawn at, its library
tile SHALL say so. Where the helper answers no size on the grid at which the card shows its reading, the
tile SHALL be drawn at the card's declared minimum and say so.

Source: audio-vue `scene-render`, "The answer says what does not fit" and "The helper answers where a
card shows its reading". audio-vue `card-layout`: the too-small check. Amended (maintainer, 2026-11-21)
with the tile's size under the scene's settings.

#### Scenario: A card too small at its minimum

- **WHEN** the helper answers no size on the open scene's grid at which the loudness table shows its
  reading
- **THEN** the loudness table's tile is drawn at its declared minimum and says it is too small to show its
  reading

## REMOVED Requirements

### Requirement: A library tile is drawn at the smallest size that shows its reading

**Reason**: Replaced by "A library tile is drawn at its card's whole minimum" (maintainer,
2026-11-24): a tile shows the card with everything its settings ask for, not the smallest size that
keeps the reading.
**Migration**: None; the tile's size now comes from the helper's `minimum` answer.

### Requirement: A tile's size is the first size on a ladder that shows its reading

**Reason**: The helper answers a card's sizes directly (audio-vue `scene-render`, "The helper
answers where a card is drawn whole"), so the console no longer searches a ladder of renders.
**Migration**: None; `LibraryTiles` asks for the minimum once and draws the tile once.

### Requirement: An aspect-locked card keeps its shape on the ladder

**Reason**: There is no ladder. audio-vue lays an aspect-locked card out in its own shape within
any slot, and answers its minimum from that layout.
**Migration**: None.
