# Spec Delta

## Purpose

How the app checks that the card code it draws with is the code the panel runs, and how it draws a
card or a scene when it is not, so the console never presents a picture the panel's code did not
produce.

## ADDED Requirements

### Requirement: The code's digest is compared on connect

When the app connects to a host while the helper is running, it SHALL compare the digest the helper
gives for its code with the digest the host's version read gives, and SHALL hold the cards as
matching only when they are equal.

Source: `product.md`, "The decision" (maintainer, 2026-11-06): the handshake compares one digest, the
way the app compares the API version. audio-vue `control-api`: the version read gives the code's
digest and where it came from.

#### Scenario: The same code

- **WHEN** the helper's digest and the host's are equal
- **THEN** every card is drawn by the helper, and no difference is shown

### Requirement: A difference names each entry that differs

When the digests differ, the app SHALL read the host's manifest and compare its entries with the
bundled manifest's, naming each entry that differs, is only the host's, or is only the app's. It
SHALL say whether the host's digest is the running panel's or the host's files'.

Source: `product.md`, "The decision": only on a mismatch does the app fetch the host's manifest and
name each entry that differs. audio-vue `control-api`: the manifest read, behind the token.

#### Scenario: One card changed on the host

- **WHEN** the host's manifest differs from the bundled one only in the waveform card's entry
- **THEN** the app names the waveform card as different from the panel's

#### Scenario: The panel is down

- **WHEN** the digests differ and the host's comes from its files, not the running panel
- **THEN** the app says the comparison is with the code the panel will run at its next start

### Requirement: A card whose own code differs is a plain box

Where a card's own entry differs, every placement of that card SHALL be drawn as a plain box with its
name, over its plate where the helper drew one, and every other card SHALL be drawn by the helper. A
card's entry SHALL be the one the manifests' card map gives it; a card neither declares is a box.

Source: `product.md`, "The decision" (maintainer, 2026-11-06). A card's entry is its family's
directory, not always its name (`peak_rms_vertical` is in `src/cards/peak_rms`).

#### Scenario: A changed card in a scene

- **WHEN** the waveform card's entry differs and a scene holds a waveform and a meter
- **THEN** the waveform is a plain box named waveform, and the meter is drawn by the helper

### Requirement: Shared code that differs draws no card

Where an entry that is not a card's own differs, the app SHALL draw nothing by the helper, the
backdrop included: every card SHALL be a plain box with its name, and the canvas SHALL say which
shared entries differ.

Source: `product.md`, "The decision" (maintainer, 2026-11-06): a shared entry that differs renders no
card, since every card draws through it. Even an edit to a comment counts as drift until the app is
rebuilt.

#### Scenario: A shared module changed

- **WHEN** the entry for the glass module differs
- **THEN** every card in every scene is a plain box with its name, and the canvas names the glass
  module as different from the panel's
