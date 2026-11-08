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
