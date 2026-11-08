# host-connection Specification

## Purpose

Lets the user reach an audio-vue host agent at an address they give, and know on connect whether this
app speaks that host's API.

## Requirements

### Requirement: The user connects to a host by address

The app SHALL take a host address, as a hostname or an IPv4 address with an optional port, and connect
by reading the host agent's version at `/v1/version` over HTTP. Without a port, it SHALL use 19200, the
host agent's default.

Source: Decision (maintainer, 2026-11-02): one host by address. The port is audio-vue's
`DEFAULT_PORT`, not yet in a spec (maintainer, 2026-11-03; `alignment.md` F4).

#### Scenario: An address without a port

- **WHEN** the user enters `audio-vue.cabin.hobbysprawl.com` and connects
- **THEN** the app reads `http://audio-vue.cabin.hobbysprawl.com:19200/v1/version`

#### Scenario: An address with a port

- **WHEN** the user enters `192.168.1.20:8080` and connects
- **THEN** the app reads `http://192.168.1.20:8080/v1/version`

#### Scenario: An address that cannot be a host

- **WHEN** the user enters text that is not a hostname or IPv4 address, or a port outside 1 to 65535
- **THEN** the app says the address is not valid and sends nothing

### Requirement: Requests carry no Origin header

Every request the app sends to a host SHALL carry no `Origin` header, because the host refuses any
request that has one.

Source: audio-vue `control-api`, "The API serves no browser".

#### Scenario: Reading the version

- **WHEN** the app reads a host's version
- **THEN** the request has no `Origin` header

### Requirement: The app checks API compatibility on connect

The app SHALL read the host's API version as semantic versioning and support one version, the saved
contract's: a host whose version has another numeric core is refused, whatever part differs. For a
refused host, the app SHALL say whether the host is newer or older than the app, and what to do:
deploy audio-vue to the panel where it is older, refresh the app's contract where it is newer.

Source: `product.md`, which checks versions on connect. Decision (maintainer, 2026-11-08): exactly
the saved contract's version, after a host lacking a route of the same major was let through. The
supported version is the saved contract's (`host-client`, "The supported API is the saved
contract's").

#### Scenario: A compatible host

- **WHEN** the saved contract states API `2.5.0` and the host answers with API version `2.5.0`
- **THEN** the app shows it is connected, with API version 2.5.0

#### Scenario: A pre-release or build suffix

- **WHEN** the saved contract states API `2.5.0` and the host answers with `2.5.0+abc`
- **THEN** the app shows it is connected

#### Scenario: A host behind in minor

- **WHEN** the saved contract states API `2.5.0` and the host answers with API version `2.4.0`
- **THEN** the app says the host is older than this app and to deploy audio-vue to the panel, and
  does not show itself connected

#### Scenario: A host ahead in patch

- **WHEN** the saved contract states API `2.5.0` and the host answers with API version `2.5.1`
- **THEN** the app says the host is newer than this app and to refresh the app's contract, and does
  not show itself connected

#### Scenario: A newer host

- **WHEN** the saved contract states API `2.0.0` and the host answers with API version `3.0.0`
- **THEN** the app says the host is newer than this app supports and does not show itself connected

#### Scenario: An older host

- **WHEN** the saved contract states API `2.0.0` and the host answers with API version `1.0.0`
- **THEN** the app says the host is older than this app supports and does not show itself connected

#### Scenario: A version that is not semantic

- **WHEN** the host answers with an API version the app cannot read as semantic versioning
- **THEN** the app reports an unexpected answer from the host

### Requirement: The app shows the state's schema when the panel answers

When connected, the app SHALL show the state's schema number the host reports, or that the panel is
not answering when the host reports none. The schema is shown, not checked, in this capability.

Source: audio-vue `control-api`, "The API states its version": the schema is null where the panel does
not answer.

#### Scenario: The panel answers

- **WHEN** the host answers with API version `2.0.0` and schema 3
- **THEN** the app shows it is connected, with API version 2.0.0 and state schema 3

#### Scenario: The panel is down

- **WHEN** the host answers with API version `2.0.0` and a null schema
- **THEN** the app shows it is connected, and that the panel is not answering

### Requirement: A failed connection says why

When a connection fails, the app SHALL say which of these it was: the host could not be reached or
did not answer in time, the host refused the request, or the host's answer was not a version.

Source: Inferred (this change): the walking skeleton exists to test the real network path, so its
failures must be told apart.

#### Scenario: Nothing at the address

- **WHEN** no host agent answers at the address within the time limit
- **THEN** the app says the host could not be reached

#### Scenario: The host refuses

- **WHEN** the host answers with HTTP 403
- **THEN** the app says the host refused the request

#### Scenario: Something else answers

- **WHEN** the address answers with a status other than 200 and 403, or with a body that is not a
  version
- **THEN** the app reports an unexpected answer from the host

### Requirement: The app remembers the last address

The app SHALL remember the last address a host answered at, with that host's id when it knows it,
and, when it next launches, SHALL connect to that address once without being asked, showing whether
it is paired. With no address remembered it SHALL send nothing at launch.

Source: Decision (walking-skeleton): retyping an address on every launch is friction in daily use.
Decision (maintainer, 2026-11-04): once paired, a launch that waits for Connect is a step for nothing.

#### Scenario: Relaunching

- **WHEN** the user connected to `audio-vue` and relaunches the app
- **THEN** the panel window shows the panel at `audio-vue`, and the app connects to it and shows
  whether it is paired

#### Scenario: A first launch

- **WHEN** the app launches with no address remembered
- **THEN** it sends nothing, and the panel window offers Add Panel…

### Requirement: Connecting says whether the app is paired

Once a compatible host answers, the app SHALL say whether it is paired with it, and SHALL show itself
connected only when the host accepts the token the app keeps for that host. A host that answers while
the app is not paired SHALL NOT be shown as connected: the app SHALL ask to pair with it and offer to
pair.

Source: audio-vue `control-service`, "Everything but pairing and the version takes a token".
Decision (maintainer, 2026-11-06): connected means the panel can be used.

#### Scenario: A host never paired with

- **WHEN** the app reaches a compatible host it holds no token for
- **THEN** it does not show itself connected, asks to pair with the host, and offers to pair

#### Scenario: A host paired with

- **WHEN** the app reaches a compatible host that accepts the token the app keeps for it
- **THEN** it shows itself connected

#### Scenario: Another address for a paired host

- **WHEN** the app paired with a host at `audio-vue`, has not reached it at `audio-vue.local`, and the
  user adds it by that address
- **THEN** it asks to pair, since it cannot tell the host is the same before it pairs

### Requirement: A launch that cannot reach the address finds the panel by its id

When the remembered address cannot be reached at launch and the host's id is remembered, the app
SHALL connect to the panel announced with that id once it is found, unless the user has chosen or
added another panel first.

Source: Decision (maintainer, 2026-11-06): a launch that cannot reach the address finds the panel by
its id.

#### Scenario: A panel that moved

- **WHEN** the app last connected to host `89efe3f8` at `192.168.1.20`, and at launch nothing answers
  there while that host is announced at `audio-vue.local.`
- **THEN** the app connects to it at `audio-vue.local` and remembers that address

#### Scenario: A panel not yet announced

- **WHEN** at launch the remembered address cannot be reached and no panel with the remembered id is
  found yet
- **THEN** the app says the host could not be reached, and connects to the panel once it is announced,
  unless the user has chosen or added another panel by then

#### Scenario: No id remembered

- **WHEN** the app last connected to an address whose host id it never learned, and at launch that
  address cannot be reached
- **THEN** the app says the host could not be reached, and connects to no found panel on its own

### Requirement: A found panel is paired by its announced id

Connecting to a found panel, the app SHALL send the token it keeps for the host the announcement
names by id, and SHALL count itself paired only when the id read with the token matches the one
announced; it SHALL then know the found address leads to that host.

Source: audio-vue `control-api`, "The announcement is part of the contract": a host found twice has
the same `id`. Decision (maintainer, 2026-11-06): a found panel whose id the app holds a token for is
connected with that token.

#### Scenario: A paired host found at a new address

- **WHEN** the app paired with host `89efe3f8` at `audio-vue`, and connects to the found panel
  announced with id `89efe3f8` at `audio-vue.local.`
- **THEN** it sends the token kept for `89efe3f8`, shows itself connected, and from then on knows
  `audio-vue.local` leads to that host

#### Scenario: A found panel whose id does not match

- **WHEN** the app connects with a kept token to a found panel announced with id `89efe3f8`, and the
  id the host gives with the token is another
- **THEN** it asks to pair, and keeps no link from that address to `89efe3f8`
