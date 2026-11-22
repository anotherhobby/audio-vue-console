# Spec Delta

## MODIFIED Requirements

### Requirement: Duplicate makes an unsaved copy of any scene

Duplicate, on a scene that is not fixed and has no card parked (`card-parking`), SHALL make an
editable copy kept in the app, listed in the gallery and opened on the canvas, named for the scene
with "copy" after it, numbered from 2 where that name is taken. It SHALL write nothing to the host
until it is saved (`scene-saving`). In the editor's toolbar and the gallery, it SHALL be disabled
for a scene with a parked card, saying why.

Source: `product.md`: built-in scenes are read-only, shown with "duplicate to edit"; saves are explicit.
Decision (maintainer, 2026-11-07): a copy stays in the app until its first Save. Decision
(maintainer, 2026-11-22): duplicate is blocked while a card is off the panel.

#### Scenario: Duplicating a built-in scene

- **WHEN** the user chooses Duplicate on the built-in scene RTA
- **THEN** the gallery lists "RTA copy", not marked built in and marked unsaved, the canvas opens it
  for editing, and the host lists no new scene

#### Scenario: Duplicating twice

- **WHEN** the gallery already lists "RTA copy" and the user duplicates RTA again
- **THEN** the new copy is named "RTA copy 2"

#### Scenario: A scene too wide

- **WHEN** the user duplicates a scene too wide for the panel
- **THEN** the copy is made, as wide, and opened for editing

#### Scenario: A parked card

- **WHEN** "Studio" has a parked card
- **THEN** Duplicate is disabled for "Studio" in the editor and the gallery, saying the cards off
  the panel must be moved onto it

## ADDED Requirements

### Requirement: A scene with parked cards says so

The gallery SHALL list a scene that has parked cards like any other, with a note saying how many of
its cards are off the panel.

Source: Decision (maintainer, 2026-11-22): parked cards block saving, so the gallery shows where
they are left.

#### Scenario: Back in the gallery

- **WHEN** the user parks two cards in "Studio" and goes back to the gallery
- **THEN** "Studio" is marked unsaved and notes that two cards are off the panel
