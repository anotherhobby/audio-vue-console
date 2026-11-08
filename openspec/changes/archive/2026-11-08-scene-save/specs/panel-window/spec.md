# Spec Delta

## MODIFIED Requirements

### Requirement: A panel is added by its address

The panel picker SHALL offer Add Panel…, which takes a host address and connects to it as
`host-connection` says. The app SHALL hold one panel at a time: adding a panel replaces the one it
held, once any unsaved scenes are settled as `scene-saving` says.

Source: Decision (maintainer, 2026-11-05): an address is typed in the picker's Add Panel….
Decision (maintainer, 2026-11-06): Add Panel… stays beside the panels found. Decision (maintainer,
2026-11-07): switching panels with unsaved scenes asks first.

#### Scenario: Adding a panel

- **WHEN** the user chooses Add Panel…, enters `audio-vue`, and connects
- **THEN** the picker shows that panel and the Panel page shows the connection to it

#### Scenario: Adding a second panel

- **WHEN** the app holds one panel and the user adds another by its address
- **THEN** the new panel is the one held, and the picker shows the panel it replaced only if that
  panel is found on the network

#### Scenario: Adding a panel with unsaved scenes

- **WHEN** a scene is unsaved and the user adds another panel by its address
- **THEN** the app asks to Save All, Discard or Cancel before connecting, and with Cancel keeps the
  panel it holds

### Requirement: Choosing a found panel connects to it

Choosing a found panel in the picker SHALL connect to it as `host-connection` says, and make it the
panel held, replacing the one held before, once any unsaved scenes are settled as `scene-saving`
says.

Source: Decision (maintainer, 2026-11-06): the app connects to one panel at a time, and choosing a
found panel connects to it. Decision (maintainer, 2026-11-07): switching panels with unsaved scenes
asks first.

#### Scenario: Choosing a panel

- **WHEN** the app holds `audio-vue` and the user chooses the found panel at `studio.local`
- **THEN** the app connects to it, the picker shows it as the panel held, and the Panel page shows
  the connection to it

### Requirement: The Panel page keeps its sections in order

The Panel page SHALL show the sections Status, Capture, Calibration and Pairing, in that order.
Status SHALL show the condition, the scene on screen and the display's size, and offer Reset as
`scene-apply` says; Capture the device, the rate and the analysis time against its budget;
Calibration its status and age.

Source: Decision (maintainer, 2026-11-05): the sketched sections keep their order, Pairing last.
Decision (maintainer, 2026-11-06): the Overview is the Panel page, opening on Status. Decision
(maintainer, 2026-11-07): Reset in the editor and on the Panel page.

#### Scenario: A paired host whose panel is up

- **WHEN** the app is paired with a host whose panel is up and drawing
- **THEN** the Panel page shows, from the host, its condition, scene, display size, capture device,
  rate, analysis time and budget, and calibration status and age, and Status offers Reset
