# Spec Delta

## MODIFIED Requirements

### Requirement: An edit draws again only what it changed

After any edit, undo or redo, the canvas SHALL draw again every plate whose cards, cells, group or
card settings changed, SHALL drop the layers of removed cards, and SHALL leave every other layer as
it is.

Source: audio-vue's handoff (2026-11-07): a resize asks for that plate alone, and a backdrop change
for the backdrop. Decision (maintainer, 2026-11-08): card settings are edited in the inspector
(`card-settings`).

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
