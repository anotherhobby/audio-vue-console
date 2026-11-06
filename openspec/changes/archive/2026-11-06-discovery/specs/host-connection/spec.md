# Spec Delta

## MODIFIED Requirements

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

## ADDED Requirements

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
