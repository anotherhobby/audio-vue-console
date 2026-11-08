# Spec Delta

## MODIFIED Requirements

### Requirement: An edit draws again only what it changed

After any edit, undo or redo, the canvas SHALL draw again every plate whose cards, cells, group or
card settings changed, SHALL drop the layers of removed cards, and SHALL leave every other layer as
it is. A change to the scene's backdrop SHALL draw the backdrop alone again; a change to any other
scene setting SHALL draw the backdrop and every plate again.

Source: audio-vue's handoff (2026-11-07): a resize asks for that plate alone, and a backdrop change
for the backdrop. Decision (maintainer, 2026-11-08): card settings are edited in the inspector
(`card-settings`), and so are scene settings (`scene-settings`).

#### Scenario: Grouping

- **WHEN** the user groups two cards
- **THEN** the two plates are replaced by one layer drawn for the group, and no other plate is drawn
  again

#### Scenario: Deleting

- **WHEN** the user deletes a card
- **THEN** its layer is gone, and no request is sent

#### Scenario: Changing a setting

- **WHEN** the user changes a setting of one card in a group
- **THEN** that group's plate is drawn again, and no other plate is drawn again

#### Scenario: Changing the backdrop

- **WHEN** the user changes the backdrop's gradient
- **THEN** the backdrop is drawn again, and no plate is

#### Scenario: Changing the palette

- **WHEN** the user changes a palette colour
- **THEN** the backdrop and every plate are drawn again

### Requirement: Library tiles follow the scene's settings, not its cards

The library's tiles SHALL be drawn again only when the open scene's settings or grid, as edited,
differ from those they were drawn for. An edit to the scene's cards SHALL draw no tile again. Tiles
SHALL appear one by one as they are drawn, each a plain box until then.

Source: Decision (maintainer, 2026-11-07): tiles are drawn in the open scene's settings; a tile
holds one card at its minimum, which no layout edit changes. Decision (maintainer, 2026-11-08):
scene settings are edited in the inspector (`scene-settings`).

#### Scenario: Moving a card

- **WHEN** the user moves a card on the canvas
- **THEN** no library tile is drawn again

#### Scenario: Two scenes with the same settings

- **WHEN** the user opens a scene, then another whose settings and grid are the same
- **THEN** the second scene's library shows the tiles already drawn, and none is drawn again

#### Scenario: A scene with other settings

- **WHEN** the user opens a scene whose settings differ from the last scene's
- **THEN** the library shows plain boxes, each replaced by its drawn plate as it arrives

#### Scenario: Editing the palette

- **WHEN** the user changes a palette colour of the open scene
- **THEN** the library's tiles are drawn again in the new colour
