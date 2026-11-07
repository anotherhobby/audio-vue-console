# render-runtime Specification

## Purpose

What the app carries to draw scenes: audio-vue's render bundle, mirrored into this repository, and an
interpreter with the bundle's libraries, how each is refreshed, and the check that the bundle the app
runs is the one its manifest names.

## Requirements

### Requirement: The render bundle is mirrored from audio-vue

The app SHALL carry audio-vue's render bundle as `make render-bundle` writes it, mirrored into this
checkout by a script and never by hand: a file audio-vue's bundle no longer holds SHALL be removed
from the mirror. A check mode SHALL say how the mirror differs, changing nothing.

Source: `product.md`, "The decision" (maintainer, 2026-11-06): the card code is bundled into the app
when it is built. audio-vue's handoff (2026-11-07): mirror the directory, never copy over a previous
copy.

#### Scenario: A card changed in audio-vue

- **WHEN** a card's code changes in audio-vue and the mirror is refreshed
- **THEN** the mirror holds audio-vue's new bundle, its manifest included, and nothing of the old one
  that the new one lacks

#### Scenario: Checking

- **WHEN** the check mode runs and audio-vue's bundle differs from the mirror
- **THEN** it names each file that differs and exits with a failure, and the mirror is unchanged

### Requirement: The app carries an interpreter with the bundle's libraries

Every build SHALL carry a relocatable Python, the one audio-vue's checkout runs, with each library
the bundle's requirements pin, at those versions and hashes, and SHALL run the helper with it and
nothing outside the app.

Source: Decision (maintainer, 2026-11-07): bundle CPython, its libraries from audio-vue's lock.
Measured (2026-11-07): so bundled, a sandboxed app drew a scene with no exception.

#### Scenario: A release build

- **WHEN** a release build opens a scene of a paired panel
- **THEN** the scene is drawn by the helper the app carries

### Requirement: A bundle that does not match its manifest is not used

The app SHALL use the bundled manifest only when its digest equals the digest the helper computes from
its own files, and otherwise SHALL draw no scene by the helper, saying the app's render bundle is
damaged.

Source: audio-vue `render-bundle`: the helper computes its digest from its own files rather than
trusting `manifest.json`.

#### Scenario: A file edited inside the app

- **WHEN** a file of the bundled code is changed after the build, so the helper's digest is not the
  bundled manifest's
- **THEN** every card is a plain box, and the canvas says the render bundle is damaged
