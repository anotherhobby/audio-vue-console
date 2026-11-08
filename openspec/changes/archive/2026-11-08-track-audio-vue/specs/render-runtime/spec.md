# Spec Delta

## MODIFIED Requirements

### Requirement: The render bundle is mirrored from audio-vue

The app SHALL carry audio-vue's render bundle as `make render-bundle` writes it, mirrored into this
checkout by a script and never by hand: a file audio-vue's bundle no longer holds SHALL be removed
from the mirror. Every build of the app SHALL refresh the mirror from the audio-vue checkout before
carrying it, and SHALL fail, naming the checkout, where it cannot. A check mode SHALL say how the
mirror differs, changing nothing.

Source: `product.md`, "The decision" (maintainer, 2026-11-06): the card code is bundled into the app
when it is built. audio-vue's handoff (2026-11-07): mirror the directory, never copy over a previous
copy. Decision (maintainer, 2026-11-08): a rebuild picks up audio-vue's changed card code.

#### Scenario: A card changed in audio-vue

- **WHEN** a card's code changes in audio-vue and the mirror is refreshed
- **THEN** the mirror holds audio-vue's new bundle, its manifest included, and nothing of the old one
  that the new one lacks

#### Scenario: A rebuild after a card changed

- **WHEN** a card's code changes in audio-vue and the app is built again, with nothing else run
- **THEN** the built app carries audio-vue's new bundle, and its manifest's digest is the new one

#### Scenario: No audio-vue checkout

- **WHEN** the app is built and the audio-vue checkout is missing or `make render-bundle` fails
- **THEN** the build fails with an error naming the checkout, and carries no stale bundle

#### Scenario: Checking

- **WHEN** the check mode runs and audio-vue's bundle differs from the mirror
- **THEN** it names each file that differs and exits with a failure, and the mirror is unchanged
