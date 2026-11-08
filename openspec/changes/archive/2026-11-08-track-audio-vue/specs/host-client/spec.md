# Spec Delta

## MODIFIED Requirements

### Requirement: The supported API is the saved contract's

The app SHALL support the version of the host API that the saved contract states, by its numeric
core, and SHALL hold no other record of which version it supports.

Source: `.claude/CLAUDE.md`, "Host Versions": the app supports exactly one host API, the saved
contract's. The version is read from the saved contract's `info.version`.

#### Scenario: A refreshed contract with a new major

- **WHEN** the saved contract is refreshed from one stating API `2.1.0` to one stating `3.0.0`
- **THEN** the app accepts hosts of 3.0.0 and refuses hosts of 2.1.0, with no other change to say
  so

#### Scenario: A refreshed contract with a new minor

- **WHEN** the saved contract is refreshed from one stating API `2.4.0` to one stating `2.5.0`
- **THEN** the app accepts hosts of 2.5.0 and refuses hosts of 2.4.0, with no other change to say so
