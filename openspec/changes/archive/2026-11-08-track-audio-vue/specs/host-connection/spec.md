# Spec Delta

## MODIFIED Requirements

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
