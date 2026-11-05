# Spec Delta

## Purpose

The app's one window for a panel: picking and adding the panel, the sidebar's pages, and the Overview,
which shows what the host says about the panel and holds connecting and pairing in one spot.

## ADDED Requirements

### Requirement: The panel window is the app's window

The app SHALL show one window for a panel, with the panel picker at the top of a sidebar of pages, and
SHALL keep running and connected when the window is closed, bringing it back from the Window menu or
the Dock.

Source: Decision (maintainer, 2026-11-05): the Host Connection window is retired and its details move
into the panel window. Decision (pairing): the connection is the app's, not the window's.

#### Scenario: Launching

- **WHEN** the app launches
- **THEN** it shows the panel window, open on the Overview

#### Scenario: Closing the window

- **WHEN** the user closes the panel window and opens it again from the Dock
- **THEN** the app is still connected to the same host, with the same pairing

### Requirement: A panel is added by its address

The panel picker SHALL offer Add Panel…, which takes a host address and connects to it as
`host-connection` says. The app SHALL hold one panel at a time: adding a panel replaces the one it
held.

Source: Decision (maintainer, 2026-11-05): an address is typed in the picker's Add Panel…. Decision
(maintainer, 2026-11-02): one host by address; discovery comes later.

#### Scenario: Adding a panel

- **WHEN** the user chooses Add Panel…, enters `audio-vue`, and connects
- **THEN** the picker shows that panel and the Overview shows the connection to it

#### Scenario: Adding a second panel

- **WHEN** the app holds one panel and the user adds another by its address
- **THEN** the picker shows only the new panel

### Requirement: The picker names the panel

The picker SHALL show the panel by the host's name when paired, with its display's shape when the
host gives it, and by its address when the app cannot read the name, with a mark for whether the panel
is up.

Source: audio-vue `control-api`, "The API gives the host's identity": the host's id, name and display
size are read with the token.

#### Scenario: A paired panel

- **WHEN** the app is paired with a host named `audio-vue` with a 1920 × 1080 display, its panel up
- **THEN** the picker shows `audio-vue`, `16:9`, and that it is up

#### Scenario: A paired panel that is down

- **WHEN** the app is paired with a host named `audio-vue` whose panel is down, so the host gives no
  display size
- **THEN** the picker shows `audio-vue`, with no shape, and not up

#### Scenario: An unpaired panel

- **WHEN** the app is connected to `audio-vue.local` and not paired
- **THEN** the picker shows `audio-vue.local`, with no shape, and not up

### Requirement: The Overview keeps its sections in order

The Overview SHALL show the sections Panel, Capture, Calibration and Pairing, in that order. Panel
SHALL show the condition, the scene on screen and the display's size; Capture the device, the rate
and the analysis time against its budget; Calibration its status and age.

Source: Decision (maintainer, 2026-11-05): the sketched sections stay in the same order, with
Pairing added last.

#### Scenario: A paired host whose panel is up

- **WHEN** the app is paired with a host whose panel is up and drawing
- **THEN** the Overview shows, from the host, its condition, scene, display size, capture device,
  rate, analysis time and budget, and calibration status and age

### Requirement: A value not read shows a dash

The Overview SHALL show `—` for any value it has not read from the host, including every value while
not paired and every value the host reports as null, and SHALL NOT show a made-up or remembered value
in its place.

Source: Decision (maintainer, 2026-11-05): real, live data, with a dash where none is pulled yet.
audio-vue `control-state`: a section reports a value it does not have as null.

#### Scenario: Not paired

- **WHEN** the app is connected to a host and not paired
- **THEN** every value in Panel, Capture and Calibration is `—`

#### Scenario: A panel that is down

- **WHEN** the host reports the panel down, with its sections empty
- **THEN** Panel shows the condition as down, and every other value in Panel, Capture and Calibration
  that the host does not give is `—`

### Requirement: The Overview follows the live state

While the panel window shows a paired host, the Overview's values SHALL follow the live state as
`host-client` keeps it, and SHALL say when the state is not live.

Source: audio-vue `control-api`, "The state is pushed".

#### Scenario: A scene switched on the host

- **WHEN** the scene on screen changes on the host while the Overview is showing
- **THEN** the Overview shows the new scene without the user asking

#### Scenario: The socket closed

- **WHEN** the events socket closes and has not come back
- **THEN** the Overview says its values are not live

### Requirement: The Pairing section holds connecting and pairing

The Pairing section SHALL show the address, whether the app is connected and why not, with what
`host-connection` shows of a connection, whether it is paired, and the action that comes next: Pair when not paired, Pair Again when paired. Entering the
code SHALL be a sheet over the window.

Source: Decision (maintainer, 2026-11-05): the Host Connection window's details, pairing among them,
move into the Overview's Pairing section.

#### Scenario: Connected and not paired

- **WHEN** the app is connected to a host and not paired
- **THEN** the Pairing section shows the address, connected, not paired, and Pair

#### Scenario: A host that cannot be reached

- **WHEN** the host at the address cannot be reached
- **THEN** the Pairing section shows the address and says the host could not be reached

### Requirement: The Pairing section lists the host's clients

When paired, the Pairing section SHALL list the host's paired clients in place, as `host-pairing`
says, each with a way to revoke it.

Source: Decision (maintainer, 2026-11-05): the clients list is inline, not a sheet, and the sidebar
has no Access page.

#### Scenario: Paired

- **WHEN** the app is paired with a host that lists two clients
- **THEN** the Pairing section lists both, this app marked, each with a revoke button

#### Scenario: Not paired

- **WHEN** the app is not paired
- **THEN** the Pairing section lists no clients

### Requirement: The sidebar has no Access page

The sidebar SHALL list Overview, Scenes, Input, Calibration, Display and History, and no Access page.
The pages other than Overview are held to no requirement here, and keep their sample values until
their own changes build them.

Source: Decision (maintainer, 2026-11-05): Access goes; the other pages can wait, and sample data is
fine before the project's release.

#### Scenario: The sidebar

- **WHEN** the panel window is open
- **THEN** its sidebar lists Overview, Scenes, Input, Calibration, Display and History, in that order
