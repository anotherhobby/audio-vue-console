# host-discovery Specification

## Purpose

Lets the app find audio-vue panels on the LAN without an address: the service it browses for, what
it reads from each announcement, how one host seen several ways is one panel, and when a panel leaves
the list.

## Requirements

### Requirement: The app browses for announced panels

While it runs, the app SHALL browse the local network for DNS-SD services of type `_audio-vue._tcp`,
and SHALL list each one found as a panel, with its instance name and the host id in its TXT record's
`id`.

Source: audio-vue `control-api`, "The announcement is part of the contract". Decision (maintainer,
2026-11-06): the picker lists the panels found.

#### Scenario: A host announcing

- **WHEN** a host on the LAN announces instance `audio-vue` of `_audio-vue._tcp`, with TXT
  `id=89efe3f8`
- **THEN** the app lists a panel named `audio-vue` with id `89efe3f8`

#### Scenario: No host announcing

- **WHEN** no host on the LAN announces `_audio-vue._tcp`
- **THEN** the app lists no panel found, and sends nothing to any host for it

### Requirement: A found panel is reached where it is announced

The app SHALL reach a found panel at the host name and port its announcement resolves to, and SHALL
send nothing to it before it is chosen or recognised by its id.

Source: audio-vue `control-service`, "The agent announces itself on the network": the instance
resolves to the host and the port the agent serves.

#### Scenario: Resolving a found panel

- **WHEN** the panel `audio-vue` resolves to `audio-vue.local.` at port 19200 and the app connects to
  it
- **THEN** the app reads `http://audio-vue.local:19200/v1/version`

#### Scenario: An agent on another port

- **WHEN** a found panel resolves to port 8080
- **THEN** the app connects to it at port 8080, not at the default port

### Requirement: One host is one panel, by its id

The app SHALL list announcements carrying the same TXT `id` as one panel, and announcements carrying
different ids as different panels, whatever their instance names.

Source: audio-vue `control-api`, "The announcement is part of the contract", and `control-service`,
"A name already taken gives way": a renamed instance is still the same panel by its id. Measured
(2026-11-06): the proving host is seen on two interfaces at once.

#### Scenario: One host on two interfaces

- **WHEN** the same host's announcement is found on two network interfaces
- **THEN** the app lists it once

#### Scenario: Two hosts of one name

- **WHEN** two hosts named `audio-vue` announce, one renamed `audio-vue (2)` by the responder, with
  different ids
- **THEN** the app lists two panels, `audio-vue` and `audio-vue (2)`

### Requirement: An announcement without an id is not listed

The app SHALL NOT list an announcement whose TXT record has no `id`, since it cannot be told apart
from other hosts or matched to a pairing.

Source: audio-vue `control-api`, "The announcement is part of the contract": every announcement
carries `id`.

#### Scenario: A TXT record with no id

- **WHEN** an instance of `_audio-vue._tcp` is found whose TXT record has no `id`
- **THEN** the app does not list it

### Requirement: A withdrawn panel leaves the list

When every announcement of a panel is withdrawn, the app SHALL remove that panel from the panels it
has found.

Source: audio-vue `control-service`, "The announcement lasts as long as the agent": an instance in
the picker is a panel that answers.

#### Scenario: The agent stops

- **WHEN** the agent on a found host stops and its announcement is withdrawn
- **THEN** the app no longer lists that panel as found

#### Scenario: One interface goes

- **WHEN** a host found on two interfaces is withdrawn from one of them
- **THEN** the app still lists the panel

### Requirement: The app knows when it may not browse

When macOS refuses the app local network access, the app SHALL report that it may not reach the
local network, apart from finding no panels, and SHALL browse again once access is given.

Source: Inferred (this change): macOS asks before an app browses the local network, and a denial
also stops connections to LAN hosts (`pitfalls.md`, "No Local Network prompt").

#### Scenario: Access denied

- **WHEN** the user has denied the app local network access
- **THEN** the app reports that it may not reach the local network, not that no panel was found

#### Scenario: Access given later

- **WHEN** the user allows the app local network access in System Settings while it runs
- **THEN** the app lists the panels announced on the LAN
