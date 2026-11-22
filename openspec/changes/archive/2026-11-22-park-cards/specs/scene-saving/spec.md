# Spec Delta

## MODIFIED Requirements

### Requirement: Only an editable scene is saved

Save SHALL be enabled only for a scene the canvas may edit that is unsaved and has no card parked
(`card-parking`). While a card is parked it SHALL be disabled, saying the cards off the panel must
be moved onto it. It SHALL NOT be offered for a built-in scene. A scene too wide for the panel
SHALL be saved like any other.

Source: `scene-canvas`, "A read-only scene can be looked at, not edited". audio-vue
`settings-store`: a built-in is refused for a write; `scene-grid`: a scene write is accepted however
wide the scene is. Decision (maintainer, 2026-11-22): save is blocked while a card is off the
panel.

#### Scenario: A built-in scene

- **WHEN** the user opens the built-in RTA
- **THEN** Save is disabled

#### Scenario: Nothing to save

- **WHEN** the user opens a stored scene and makes no edit
- **THEN** Save is disabled

#### Scenario: A scene too wide

- **WHEN** the user edits a stored scene too wide for the panel
- **THEN** Save is enabled

#### Scenario: A parked card

- **WHEN** the user parks a card of a stored scene
- **THEN** Save and File ▸ Save are disabled, saying the cards off the panel must be moved onto it

#### Scenario: The card returned

- **WHEN** the user then moves the parked card back onto the grid
- **THEN** Save is enabled

### Requirement: Unsaved scenes are settled before they are lost

Quitting the app, or connecting to another panel, while scenes are unsaved SHALL first ask, naming
them, to Save All, Discard or Cancel. Save All SHALL save each and go on only if every save
succeeds. Where any unsaved scene has a parked card, Save All SHALL save nothing, SHALL name each
such scene, and SHALL NOT go on. Cancel SHALL leave everything as it was. Connecting to the same
panel again SHALL keep unsaved scenes.

Source: Decision (maintainer, 2026-11-07): quitting or switching panels with unsaved scenes asks
Save / Discard, listing them. Decision (maintainer, 2026-11-22): save is blocked while a card is
off the panel.

#### Scenario: Quitting with an unsaved scene

- **WHEN** "Studio" is unsaved and the user quits and chooses Save All
- **THEN** the host stores "Studio", and the app quits

#### Scenario: A save fails while quitting

- **WHEN** the user quits, chooses Save All, and the host refuses one save
- **THEN** the app does not quit, and shows why that save failed

#### Scenario: Quitting with a parked card

- **WHEN** "Studio" and "Wide" are unsaved, "Wide" has a parked card, and the user quits and
  chooses Save All
- **THEN** nothing is written, the app does not quit, and it says "Wide" has cards off the panel

#### Scenario: Switching panels

- **WHEN** "Studio" is unsaved and the user chooses another panel in the picker and chooses Discard
- **THEN** the app connects to the other panel, and "Studio"'s edits are gone

#### Scenario: Reconnecting to the same panel

- **WHEN** "Studio" is unsaved and the app connects to the same panel again
- **THEN** nothing is asked, and "Studio" is still shown with its edits, marked unsaved
