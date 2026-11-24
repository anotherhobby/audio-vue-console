# panel-display Specification

## Purpose

The Display page: the connected panel's display size, and the installation's idle settings, read
from and written to the host's `display` install block, which every scene inherits unless it sets
its own.

## Requirements

### Requirement: The Display page shows the panel's idle settings

On a paired host, the Display page SHALL show the display's size, then each setting the host's
schema declares for its `display` install block, in declared order, with its label and unit and the
value the block stores, or else its default.

Source: audio-vue `display-sleep` and `screensaver`. Maintainer, 2026-11-24: every screensaver
default but colour and backdrop is set here.

#### Scenario: A host with no display block

- **WHEN** the user opens Display on a host whose `display` block was never written
- **THEN** it shows the display's size, Screensaver at `bounce`, and Screensaver after and Sleep
  after at 0 minutes, with no Use Default beside any of them

#### Scenario: Not paired

- **WHEN** the app is connected to a host it is not paired with
- **THEN** the Display page offers no idle setting, and says the panel must be paired first

### Requirement: An idle setting is written to the host when changed

A change to an idle setting SHALL be written to the host's `display` block at once, on the revision
read, keeping the block's other keys. Use Default SHALL remove the setting from the block. The
page SHALL then say when the change applies, in the host's terms: at the panel's next start.

Source: audio-vue `settings-store`: install blocks are written whole on a revision, and a
`display` write applies at the next start. A client cannot restart the panel (maintainer,
2026-11-05).

#### Scenario: Screensaver after ten minutes

- **WHEN** the user sets Screensaver after to 10
- **THEN** the host's `display` block stores `saver_after_min: 10` with its other keys, and the
  page says the change applies at the panel's next start

#### Scenario: Back to the default

- **WHEN** the block stores `sleep_after_min: 30` and the user chooses Use Default beside Sleep after
- **THEN** the block no longer holds `sleep_after_min`, and Sleep after shows 0

### Requirement: A refused idle setting keeps the host's values

A write the host refuses SHALL say why in the host's words and show the values the host holds. A
write refused because the block changed since it was read SHALL read the block again, show the
host's values and say they changed elsewhere.

Source: audio-vue `settings-store`, "A stale write is refused" and "A write is validated whole
before it is stored". `capture-input` handles the `input` block the same way.

#### Scenario: Changed on another Mac

- **WHEN** another client wrote the `display` block since the page read it, and the user changes
  Sleep after
- **THEN** nothing is stored, the page shows the block as the host now holds it, and says it
  changed elsewhere

### Requirement: A scene shows the panel's idle settings as written

Once an idle setting is written, a scene's Display section SHALL show the new value for that
setting wherever the scene leaves it unset, without reading the scenes again.

Source: `scene-settings`, "An unset setting shows the value of the block it inherits from".

#### Scenario: Ten minutes, then a scene

- **WHEN** the user sets the panel's Screensaver after to 10, then opens a scene that sets none
- **THEN** the scene's Screensaver after shows 10 and says it uses the panel's
