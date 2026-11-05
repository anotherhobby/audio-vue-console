# Spec Delta

## MODIFIED Requirements

### Requirement: The app checks API compatibility on connect

The app SHALL read the host's API version as semantic versioning and support one major version, 2:
any minor and patch of it is compatible. For another major, the app SHALL say whether the host is
newer or older than the app.

Source: `product.md`, which checks versions on connect. The semver rule is assumed (walking-skeleton
`design.md`). Major 2 is the API with every read behind the token (audio-vue `settings-store`); the
app dropped major 1 (maintainer, 2026-11-04).

#### Scenario: A compatible host

- **WHEN** the host answers with API version `2.4.2`
- **THEN** the app shows it is connected, with API version 2.4.2

#### Scenario: A newer host

- **WHEN** the host answers with API version `3.0.0`
- **THEN** the app says the host is newer than this app supports and does not show itself connected

#### Scenario: An older host

- **WHEN** the host answers with API version `1.0.0`
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

## ADDED Requirements

### Requirement: Connecting says whether the app is paired

Once connected to a compatible host, the app SHALL say whether it is paired with it. It SHALL show
itself paired only when the host accepts the token the app keeps for the host at that address, and
otherwise SHALL show itself not paired and offer to pair.

Source: audio-vue `control-service`, "Everything but pairing and the version takes a token": an
unpaired app can read nothing but the version.

#### Scenario: A host never paired with

- **WHEN** the app connects to a compatible host it holds no token for
- **THEN** it shows itself connected and not paired, and offers to pair

#### Scenario: A host paired with

- **WHEN** the app connects to a compatible host that accepts the token the app keeps for it
- **THEN** it shows itself connected and paired

#### Scenario: Another address for a paired host

- **WHEN** the app paired with a host at `audio-vue` and connects to it at `audio-vue.local`
- **THEN** it shows itself not paired, since it cannot tell the host is the same before it pairs
