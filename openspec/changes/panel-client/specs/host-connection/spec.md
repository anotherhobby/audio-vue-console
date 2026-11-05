# Spec Delta

## MODIFIED Requirements

### Requirement: The app checks API compatibility on connect

The app SHALL read the host's API version as semantic versioning and support one major version, the
saved contract's: any minor and patch of it is compatible. For another major, the app SHALL say
whether the host is newer or older than the app.

Source: `product.md`, which checks versions on connect. The semver rule is assumed (walking-skeleton
`design.md`). The supported major is the saved contract's (`host-client`, "The supported API is the
saved contract's").

#### Scenario: A compatible host

- **WHEN** the saved contract states API `2.0.0` and the host answers with API version `2.4.2`
- **THEN** the app shows it is connected, with API version 2.4.2

#### Scenario: A newer host

- **WHEN** the saved contract states API `2.0.0` and the host answers with API version `3.0.0`
- **THEN** the app says the host is newer than this app supports and does not show itself connected

#### Scenario: An older host

- **WHEN** the saved contract states API `2.0.0` and the host answers with API version `1.0.0`
- **THEN** the app says the host is older than this app supports and does not show itself connected

#### Scenario: A version that is not semantic

- **WHEN** the host answers with an API version the app cannot read as semantic versioning
- **THEN** the app reports an unexpected answer from the host

### Requirement: The app remembers the last address

The app SHALL remember the last address a host answered at and, when it next launches, SHALL connect
to it once without being asked, showing whether it is paired. With no address remembered it SHALL
send nothing at launch.

Source: Decision (walking-skeleton): retyping an address on every launch is friction in daily use.
Decision (maintainer, 2026-11-04): once paired, a launch that waits for Connect is a step for nothing.

#### Scenario: Relaunching

- **WHEN** the user connected to `audio-vue` and relaunches the app
- **THEN** the panel window shows the panel at `audio-vue`, and the app connects to it and shows
  whether it is paired

#### Scenario: A first launch

- **WHEN** the app launches with no address remembered
- **THEN** it sends nothing, and the panel window offers Add Panel…
