# Spec Delta

## Purpose

Gives the app one way to talk to a host's API: generated from the host's own contract saved in this
repository, applying the host's rules to every call in one place, and keeping the panel's live state
from the pushed events.

## ADDED Requirements

### Requirement: The client is generated from a saved contract

The app's calls to a host SHALL be generated from a copy of the host's OpenAPI contract saved in this
repository, and the saved copy SHALL be refreshed only from the contract audio-vue writes from its
code, never edited by hand.

Source: Decision (maintainer, 2026-11-02): the client generator is decided first, from a saved
contract. audio-vue `control-api`: the API publishes one machine-readable contract covering every
route.

#### Scenario: Refreshing the contract

- **WHEN** audio-vue's contract changes and the saved copy is refreshed from it
- **THEN** the saved copy is byte for byte the contract audio-vue writes, and the app's calls are
  generated from it with no other source change

#### Scenario: A route the contract does not have

- **WHEN** the app needs a route that is not in the saved contract
- **THEN** it cannot call it until the saved contract is refreshed with it

### Requirement: The supported API is the saved contract's

The app SHALL support the major version of the host API that the saved contract states, and SHALL
hold no other record of which version it supports.

Source: `.claude/CLAUDE.md`, "Host Versions": the app supports exactly one host API, the saved
contract's. The version is read from the saved contract's `info.version`.

#### Scenario: A refreshed contract with a new major

- **WHEN** the saved contract is refreshed from one stating API `2.1.0` to one stating `3.0.0`
- **THEN** the app accepts hosts of major 3 and refuses hosts of major 2, with no other change to say
  so

### Requirement: Every call follows the host's rules in one place

Every call the app makes to a host, HTTP and WebSocket alike, SHALL pass through one place that sends
no `Origin` header and attaches the host's token to every call that takes one.

Source: audio-vue `control-api`, "The API serves no browser"; audio-vue `control-service`, "Everything
but pairing and the version takes a token".

#### Scenario: A new route used

- **WHEN** the app starts calling a route it did not call before
- **THEN** the call carries the token and no `Origin` header with no code written for that route to
  do so

#### Scenario: Opening the events socket

- **WHEN** the app opens `/v1/events`
- **THEN** its handshake carries the token as `Authorization: Bearer` and no `Origin` header

### Requirement: The app keeps the panel's live state

While paired with a host and showing it, the app SHALL hold the panel's state as pushed on
`/v1/events`, replacing what it holds with each message, and SHALL close the socket when it no longer
shows the host.

Source: audio-vue `control-api`, "The state is pushed": each message is one whole state, the first on
connect, then as it changes and in whole every second (the contract's description).

#### Scenario: The panel's condition changes

- **WHEN** the panel goes from up to stale while the app shows the host
- **THEN** the app holds the stale state from the next pushed message, with no request of its own

#### Scenario: A host no longer shown

- **WHEN** the app stops showing a host, or forgets its token
- **THEN** the app closes that host's events socket

### Requirement: A closed events socket is opened again

When the events socket closes while the app still shows the host, the app SHALL say the state is not
live and SHALL keep the last state it held, marked as not current, until a new socket gives a state.
It SHALL try again, waiting longer after each failure up to a limit.

Source: Inferred (this change): a host restarts its agent on deploy and on reboot, and the app should
come back without being asked.

#### Scenario: The agent restarts

- **WHEN** the host's agent restarts while the app shows the host
- **THEN** the app says the state is not live, and shows live state again once the agent answers

#### Scenario: A host that stays away

- **WHEN** the host does not answer for several tries
- **THEN** the app keeps trying at a slower rate, never faster than its limit allows

### Requirement: A refused events socket means pair again

When the host refuses the events socket's handshake and also refuses the app's token on a request, the
app SHALL treat it as a refused token, as `host-pairing` says, and SHALL NOT try the socket again until
the app is paired.

Source: audio-vue `control-api`: a handshake without a valid token is refused, by close code 1008,
which an `Origin` header also earns, so the token is confirmed by a request before it is forgotten.

#### Scenario: A revoked token

- **WHEN** another client revokes this app and the app's events socket is refused on reopening
- **THEN** the app forgets the token, shows itself not paired, and stops opening the socket
