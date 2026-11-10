# Spec Delta

## MODIFIED Requirements

### Requirement: Edits are kept until saved or discarded

A scene's edits SHALL be kept while the app runs until saved or discarded (`scene-saving`):
opening the scene again, and its thumbnail, SHALL show them. A kept edit SHALL keep every part of
each card's entry but its cells, its group and the settings the user changed as the host gave it,
and every scene setting the user did not change as the host gave it.

Source: `product.md`: saves are explicit. Decisions (maintainer): unsaved edits are asked about
before a quit or a switch of panel (2026-11-07); card settings are edited in the inspector, and so
are scene settings (2026-11-08).

#### Scenario: Reopening a scene

- **WHEN** the user moves a card, goes back to the gallery and opens the scene again
- **THEN** the card is where it was moved to, and the gallery thumbnail shows it there

#### Scenario: Reopening keeps card settings

- **WHEN** a card carries settings of its own, and the user moves another card, goes back to the
  gallery and opens the scene again
- **THEN** the first card is drawn with its settings, as before the move

#### Scenario: Reopening keeps a changed setting

- **WHEN** the user changes a card's setting, goes back to the gallery and opens the scene again
- **THEN** the card shows the changed setting in the inspector and is drawn with it, and its other
  settings, plate colour and alternate are as the host gave them

#### Scenario: Reopening keeps a changed scene setting

- **WHEN** the user changes the scene's backdrop, goes back to the gallery and opens the scene again
- **THEN** the backdrop is as changed on the canvas and the thumbnail, and every other block is as
  the host gave it
