# Spec Delta

## ADDED Requirements

### Requirement: New Scene makes an unsaved scene with no cards

New Scene, in the gallery's toolbar, SHALL make a scene with no cards on the panel's grid, kept in the app, listed under My Scenes and opened on the canvas, named "New Scene",
numbered from 2 where that name is taken. It SHALL write nothing to the host until it is saved
(`scene-saving`).

Source: maintainer, 2026-11-20: a new scene that starts with no cards.

#### Scenario: A new scene on an 8:3 panel

- **WHEN** the user chooses New Scene on a 1920 by 720 panel
- **THEN** the gallery lists "New Scene", marked unsaved, the canvas opens it on a 96 by 36 grid
  with no cards, and the host lists no new scene

#### Scenario: Twice

- **WHEN** the gallery already lists "New Scene" and the user chooses New Scene again
- **THEN** the new scene is named "New Scene 2"

### Requirement: A new scene is the app's alone until it holds a card

A scene with no cards SHALL be kept in the app like a new document: the canvas SHALL show its
backdrop as the helper draws it with no plates, the gallery SHALL show it without a drawn
thumbnail, and Save and Apply SHALL be disabled, Save saying a card is needed. Once it holds a
card it SHALL be drawn, saved and applied as any unsaved copy.

Source: maintainer, 2026-11-20: like a new document, not real until saved. audio-vue
`settings-schema`: a scene holds at least one card.

#### Scenario: Before the first card

- **WHEN** the user has made a new scene and placed no card
- **THEN** the canvas shows the default backdrop, as it will once a card is placed, with no
  refusal, and Save and Apply are disabled

#### Scenario: The first card

- **WHEN** the user drops a card on it
- **THEN** the backdrop and the card are drawn, and Save and Apply are enabled
