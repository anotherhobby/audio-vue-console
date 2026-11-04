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

The app SHALL read the host's API version as semantic versioning and support one major version, 1:
any minor and patch of it is compatible. For another major, the app SHALL say whether the host is
newer or older than the app.

Source: `product.md`, which checks versions on connect. The semver rule is assumed (`design.md`).

#### Scenario: A compatible host

- **WHEN** the host answers with API version `1.4.2`
- **THEN** the app shows it is connected, with API version 1.4.2

#### Scenario: A newer host

- **WHEN** the host answers with API version `2.0.0`
- **THEN** the app says the host is newer than this app supports and does not show itself connected

#### Scenario: An older host

- **WHEN** the host answers with API version `0.9.0`
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

- **WHEN** the host answers with API version `1.0.0` and schema 3
- **THEN** the app shows it is connected, with API version 1.0.0 and state schema 3

#### Scenario: The panel is down

- **WHEN** the host answers with API version `1.0.0` and a null schema
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

The app SHALL remember the last address it connected to and offer it when it next launches. It
SHALL NOT connect without the user asking.

Source: Decision (this change): retyping an address on every launch is friction in daily use.

#### Scenario: Relaunching

- **WHEN** the user connected to `audio-vue` and relaunches the app
- **THEN** the address field holds `audio-vue`, and the app is not connected
