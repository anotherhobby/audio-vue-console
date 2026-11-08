# Spec Delta

## MODIFIED Requirements

### Requirement: Duplicate makes an unsaved copy

Duplicate, on a scene of this panel's shape that is not fixed, SHALL make a copy kept in the app, not
built in and so editable, listed in the gallery and opened on the canvas. The copy SHALL be named for
the scene with "copy" after it, or "copy 2", "copy 3" and on, the first no other scene has. It SHALL
write nothing to the host until the copy is saved, as `scene-saving` says.

Source: `product.md`: built-in scenes are read-only, shown with "duplicate to edit"; saves are explicit.
Decision (maintainer, 2026-11-07): a copy stays in the app until its first Save.

#### Scenario: Duplicating a built-in scene

- **WHEN** the user chooses Duplicate on the built-in scene RTA
- **THEN** the gallery lists "RTA copy", not marked built in and marked unsaved, the canvas opens it
  for editing, and the host lists no new scene

#### Scenario: Duplicating twice

- **WHEN** the gallery already lists "RTA copy" and the user duplicates RTA again
- **THEN** the new copy is named "RTA copy 2"

#### Scenario: Another shape

- **WHEN** a scene's shape is not the panel's
- **THEN** Duplicate for This Panel is shown and disabled
