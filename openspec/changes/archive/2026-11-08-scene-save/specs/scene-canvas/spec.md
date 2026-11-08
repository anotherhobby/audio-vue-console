# Spec Delta

## RENAMED Requirements

- FROM: `### Requirement: Edits last until the app quits`
- TO: `### Requirement: Edits are kept until saved or discarded`

## MODIFIED Requirements

### Requirement: Edits are kept until saved or discarded

A scene's edits SHALL be kept while the app runs until they are saved or discarded, as
`scene-saving` says: leaving the editor and opening the scene again SHALL show them, and so SHALL
the scene's thumbnail. A kept edit SHALL keep each card's entry from the document it was made from,
so every card setting but its cells and group stays as the host gave it.

Source: `product.md`: saves are explicit. Decision (maintainer, 2026-11-07): unsaved edits are asked
about before a quit or a switch of panel.

#### Scenario: Reopening a scene

- **WHEN** the user moves a card, goes back to the gallery and opens the scene again
- **THEN** the card is where it was moved to, and the gallery thumbnail shows it there

#### Scenario: Reopening keeps card settings

- **WHEN** a card carries settings of its own, and the user moves another card, goes back to the
  gallery and opens the scene again
- **THEN** the first card is drawn with its settings, as before the move
