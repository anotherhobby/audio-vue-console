## ADDED Requirements

### Requirement: A scene that needs a repair is marked in the gallery

A scene that needs a repair (`scene-repair`) SHALL be listed like any other, with a note that it
holds settings the panel no longer takes. A scene that cannot be repaired SHALL carry the same note.

Source: audio-vue `settings-schema`, "The panel loads only what validation passes": the panel refuses
such a scene too, so every one is shown, not only the scene that is open. Decision (maintainer,
2026-11-23).

#### Scenario: Primary after the RTA's settings moved

- **WHEN** a stored scene's `analysis:` holds `rta_weighting`
- **THEN** the gallery lists it under "My Scenes" with the note

#### Scenario: A scene that passes the schema

- **WHEN** a stored scene holds only what the schema declares
- **THEN** it carries no such note
