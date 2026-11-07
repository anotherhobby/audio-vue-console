# panel-window Specification

## Purpose

The app's one window for a panel: the sidebar's pages, and the Panel page, which picks and adds the
panel at its top, shows what the host says about it, and holds connecting and pairing in one spot.

## Requirements

### Requirement: The panel window is the app's window

The app SHALL show one window for a panel, with a sidebar of pages and the panel picker at the top of
the Panel page, and SHALL keep running and connected when the window is closed, bringing it back from
the Window menu or the Dock.

Source: Decision (maintainer, 2026-11-05): the Host Connection window's details move into the panel
window. Decision (pairing): the connection is the app's, not the window's. Decision (maintainer,
2026-11-06): the picker sits on the Panel page.

#### Scenario: Launching

- **WHEN** the app launches
- **THEN** it shows the panel window, open on the Panel page

#### Scenario: Closing the window

- **WHEN** the user closes the panel window and opens it again from the Dock
- **THEN** the app is still connected to the same host, with the same pairing

#### Scenario: Another page

- **WHEN** the user opens Scenes
- **THEN** the window's title is Scenes, and no panel picker shows

### Requirement: A panel is added by its address

The panel picker SHALL offer Add Panel…, which takes a host address and connects to it as
`host-connection` says. The app SHALL hold one panel at a time: adding a panel replaces the one it
held.

Source: Decision (maintainer, 2026-11-05): an address is typed in the picker's Add Panel….
Decision (maintainer, 2026-11-06): Add Panel… stays beside the panels found.

#### Scenario: Adding a panel

- **WHEN** the user chooses Add Panel…, enters `audio-vue`, and connects
- **THEN** the picker shows that panel and the Panel page shows the connection to it

#### Scenario: Adding a second panel

- **WHEN** the app holds one panel and the user adds another by its address
- **THEN** the new panel is the one held, and the picker shows the panel it replaced only if that
  panel is found on the network

### Requirement: The picker names the panel

The picker SHALL be titled Panel, and SHALL show the panel it holds by the host's name when paired,
by its address when not paired, and by its instance name when found with no address yet. While not
paired, a panel found on the network SHALL be marked discovered. It SHALL show no up mark or shape.

Source: audio-vue `control-api`, "The API gives the host's identity". Decision (maintainer,
2026-11-06): titled Panel, since `audio-vue` alone reads as the product; discovered until paired.

#### Scenario: A paired panel

- **WHEN** the app is paired with a host named `audio-vue` at `audio-vue.local`
- **THEN** the picker shows Panel and `audio-vue`

#### Scenario: A paired panel that is down

- **WHEN** the app is paired with a host named `audio-vue` whose panel is down
- **THEN** the picker shows `audio-vue`, and the Status section shows the condition as down

#### Scenario: An unpaired panel

- **WHEN** the app reaches `audio-vue.local` by a typed address, no panel is found on the network at
  that address, and the app is not paired
- **THEN** the picker shows `audio-vue.local`

#### Scenario: An unpaired found panel

- **WHEN** the app reaches the found panel `audio-vue` at `audio-vue.local` and is not paired
- **THEN** the picker shows `audio-vue.local (discovered)`

#### Scenario: An unpaired panel found at the address held

- **WHEN** the app reaches `audio-vue.local` by its remembered address, is not paired, and the panel
  found as `audio-vue` is at `audio-vue.local`
- **THEN** the picker shows `audio-vue.local (discovered)`

#### Scenario: A found panel paired

- **WHEN** the app pairs with the found panel at `audio-vue.local`, whose host is named `audio-vue`
- **THEN** the picker shows `audio-vue`, with no word of it being discovered

### Requirement: The Panel page keeps its sections in order

The Panel page SHALL show the sections Status, Capture, Calibration and Pairing, in that order.
Status SHALL show the condition, the scene on screen and the display's size; Capture the device, the
rate and the analysis time against its budget; Calibration its status and age.

Source: Decision (maintainer, 2026-11-05): the sketched sections keep their order, Pairing last.
Decision (maintainer, 2026-11-06): the Overview is the Panel page, opening on Status.

#### Scenario: A paired host whose panel is up

- **WHEN** the app is paired with a host whose panel is up and drawing
- **THEN** the Panel page shows, from the host, its condition, scene, display size, capture device,
  rate, analysis time and budget, and calibration status and age

### Requirement: A value not read shows a dash

The Panel page SHALL show `—` for any value it has not read from the host, including every value
while not paired and every value the host reports as null, and SHALL NOT show a made-up or remembered
value in its place.

Source: Decision (maintainer, 2026-11-05): real, live data, with a dash where none is pulled yet.
audio-vue `control-state`: a section reports a value it does not have as null.

#### Scenario: Not paired

- **WHEN** a host answers and the app is not paired
- **THEN** every value in Status, Capture and Calibration is `—`

#### Scenario: A panel that is down

- **WHEN** the host reports the panel down, with its sections empty
- **THEN** Status shows the condition as down, and every other value in Status, Capture and
  Calibration that the host does not give is `—`

### Requirement: The Panel page follows the live state

While the panel window shows a paired host, the Panel page's values SHALL follow the live state as
`host-client` keeps it, and SHALL say when the state is not live.

Source: audio-vue `control-api`, "The state is pushed".

#### Scenario: A scene switched on the host

- **WHEN** the scene on screen changes on the host while the Panel page is showing
- **THEN** the Panel page shows the new scene without the user asking

#### Scenario: The socket closed

- **WHEN** the events socket closes and has not come back
- **THEN** the Panel page says its values are not live

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

The sidebar SHALL list Panel, Scenes, Input, Calibration, Display and History, and no Access page and
no panel picker. The pages other than Panel and Scenes are held to no requirement here, and keep their
sample values until their own changes build them.

Source: Decision (maintainer, 2026-11-05): Access goes; the other pages can wait, and sample data is
fine before the project's release. Decision (maintainer, 2026-11-06): Overview is renamed Panel, and
the picker moves to the Panel page.

#### Scenario: The sidebar

- **WHEN** the panel window is open
- **THEN** its sidebar lists Panel, Scenes, Input, Calibration, Display and History, in that order,
  with nothing above them

### Requirement: The Panel page leads with pairing while not paired

While a host answers and the app is not paired, the Panel page SHALL lead with a prompt to pair,
above Status, naming the panel and offering Pair.

Source: Decision (maintainer, 2026-11-06): while not paired, the first thing the page says is what to
do.

#### Scenario: A host not paired with

- **WHEN** the host at `audio-vue.local` answers and the app is not paired with it
- **THEN** the Panel page leads with "Pair with audio-vue.local to see and control its panel." and
  Pair, above Status

### Requirement: The picker lists the panels found

The picker SHALL list every panel found on the network (`host-discovery`) that it does not hold, by
its address, or by its instance name until its address is known, in order of instance name, after
the panel it holds, and SHALL keep the list current as panels are found and withdrawn.

Source: Decision (maintainer, 2026-11-06): the picker lists the panels found, merged by host id, and
the one held; a panel goes by its address until paired.

#### Scenario: Two panels found

- **WHEN** the app holds `audio-vue` and the panels `studio` at `studio.local` and `cabin` at
  `cabin.local` are found
- **THEN** the picker shows `audio-vue`, then `cabin.local` and `studio.local`

#### Scenario: The held panel is found

- **WHEN** the panel the app holds is also found on the network, with the id the app knows for it or
  at the address the app holds it by
- **THEN** the picker shows it once, as the panel held

#### Scenario: A found panel withdrawn

- **WHEN** a panel listed as found is withdrawn from the network
- **THEN** the picker no longer lists it

### Requirement: Choosing a found panel connects to it

Choosing a found panel in the picker SHALL connect to it as `host-connection` says, and make it the
panel held, replacing the one held before.

Source: Decision (maintainer, 2026-11-06): the app connects to one panel at a time, and choosing a
found panel connects to it.

#### Scenario: Choosing a panel

- **WHEN** the app holds `audio-vue` and the user chooses the found panel at `studio.local`
- **THEN** the app connects to it, the picker shows it as the panel held, and the Panel page shows
  the connection to it

### Requirement: The picker says when the app may not reach the local network

When the app may not reach the local network (`host-discovery`), the picker SHALL say so in place
of the panels found, and say where in System Settings to allow it.

Source: Inferred (this change): a denial stops discovery and connections to LAN hosts, and would
otherwise look like no panel on the network.

#### Scenario: Local network access denied

- **WHEN** the user has denied the app local network access
- **THEN** the picker lists no panels found, and says the app may not reach the local network and
  that Privacy & Security, Local Network, in System Settings allows it

### Requirement: The Panel page names the panel as the picker does

The Panel page's prompt to pair and its word on the connection SHALL name the panel as the picker
does, without the mark of being discovered. What the app says when it cannot reach a host SHALL name
the address.

Source: Decision (maintainer, 2026-11-06): one panel goes by one name, so it never reads as two.

#### Scenario: A paired panel

- **WHEN** the app is paired with `audio-vue` at `audio-vue.local`
- **THEN** the picker shows `audio-vue` and the Pairing section says "Connected to audio-vue"

#### Scenario: A host that cannot be reached

- **WHEN** the app cannot reach the remembered address `192.0.2.1`
- **THEN** the Panel page says it could not reach `192.0.2.1`

### Requirement: The Pairing section shows the connection's details

The Pairing section SHALL show the address, the host's API version and state schema once it answers,
and the connection: connected only while paired and sending its state, with Pair Again; lost contact
while paired and not; and why not when the host cannot be reached. Entering the code SHALL be a
sheet over the window.

Source: Decision (maintainer, 2026-11-05): the details move into the Pairing section. Decision
(maintainer, 2026-11-06): connected means the panel can be used.

#### Scenario: A host not paired with

- **WHEN** a host answers and the app is not paired
- **THEN** the Pairing section shows the address and the host's API version and state schema, and
  does not say connected

#### Scenario: Paired

- **WHEN** the app is paired with `audio-vue` at `audio-vue.local`
- **THEN** the Pairing section shows the address `audio-vue.local`, "Connected to audio-vue", the
  host's API version and state schema, and Pair Again

#### Scenario: Lost contact

- **WHEN** the app is paired with `audio-vue` and its state stops coming, as when its agent stops
- **THEN** the Pairing section says "Lost contact with audio-vue. Trying again…" and not connected,
  and says "Connected to audio-vue" again once the state comes back

#### Scenario: A host that cannot be reached

- **WHEN** the host at the address cannot be reached
- **THEN** the Pairing section shows the address and says the host could not be reached

### Requirement: Status says whether scenes can be drawn

Status SHALL hold a Renderer row: while the helper starts, that it is starting, with an indicator; once
its code is compared with the panel's, Ready only where it matches; and in a warning colour, why
scenes are not drawn as the panel draws them, or why it could not start. While not paired, `—`.

Source: Decision (maintainer, 2026-11-07): a line under Status in place of a launch screen; it must
not say Ready when the card code differs, and says so in orange. `card-code`.

#### Scenario: Pairing

- **WHEN** the app becomes paired, starts the helper, and its code matches the panel's
- **THEN** the Renderer row says it is starting, with a working indicator, then Ready

#### Scenario: Shared code differs

- **WHEN** the helper is ready and `src/frame.py` differs from the panel's
- **THEN** the Renderer row says scenes are not drawn because the card code differs, in orange, and
  does not say Ready; the Scenes page names `src/frame.py`

#### Scenario: A card's code differs

- **WHEN** the helper is ready and only the waveform card's code differs
- **THEN** the Renderer row says some cards differ, in orange, and the Scenes page names the
  waveform

#### Scenario: A helper that cannot start

- **WHEN** the app was built without its interpreter
- **THEN** the Renderer row says the renderer could not start, and why, in orange
