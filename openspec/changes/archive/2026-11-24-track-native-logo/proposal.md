# Proposal

## Why

audio-vue's `native-logo` draws the logo natively, gives the `logo` card four colours of its own,
and lets a scene dress its screensaver: the same four colours, and whether to use the scene's
backdrop and plate. The panel runs it now (maintainer, 2026-11-24). The console draws a scene
block's role colours with no colour and no roles. The installation's idle settings, which a scene's
new screensaver look sits beside, are still a sketch with a toggle that matches no setting.

## What Changes

- **The scene's Display section shows the screensaver's colours as a card's own colours are
  shown.** Each of the four takes one of the scene's roles, offered in the scene's colours as
  edited, or a colour of its own. Unset, it shows the logo's own colour and names no role. The two
  new choices, the scene's backdrop and the scene's plate, are switches.
- **The Display page edits the installation's idle settings.** It shows the screensaver, the
  minutes before it starts and the minutes before the display sleeps, from the host's `display`
  block. It writes each change to the host and says when it applies: at the panel's next start.
  A scene's Display section then shows the new values as the panel's. The made-up "Sleep when
  quiet" toggle and "Off" choice go, and the page keeps the display's size.
- **The logo card's four colours are checked, not built.** The inspector already reads a card's
  own colour defaults. The change confirms that a `logo` card shows Wordmark, Bar foot, Bar top and
  Hold colour under Colours, each unset at the logo's own colour.
- **The render bundle the app carries is the one the panel runs.** Every build already mirrors
  audio-vue's bundle. The change checks that the bundled interpreter draws a `logo` card, the
  bundle's first use of pygame's font module, and refreshes the test fixtures from the host's
  schema.

Not doing:
- A preview of the screensaver in the console (maintainer, 2026-11-24). The screensaver is not a
  scene, and the render helper draws scenes.
- Restarting the panel so an idle setting applies at once. A client cannot restart the panel.
- Screensavers other than `bounce`, or settings of the screensaver's own beyond the host's.

## Capabilities

### New Capabilities

- `panel-display`: the Display page: the display's size, and the installation's idle settings read
  from and written to the host's `display` block, with when each change applies.

### Modified Capabilities

- `scene-settings`: a colour in a scene block takes one of the scene's roles or a colour of its
  own, as a card's colour does, unset showing its own default.
- `panel-window`: Display joins Panel, Scenes and Capture as a page with no sample values.

## Impact

- **Code:**
  - `AudioVueConsole/Scenes/SceneSettings.swift`: `BlockSettingRow` gives a colour setting the
    scene's colours and roles, from the same code `CardSettingsList` uses.
  - `AudioVueConsole/Scenes/CardSettings.swift`: what a role colour takes from the scene moves to
    one place both lists call.
  - `ConsoleCore`: `PanelScenes`, which already holds the install blocks a scene inherits from,
    keeps their revisions and writes the `display` block, so the page and the scenes read one
    copy. `InstallWritten` gains when a write applies.
  - The app target gains the Display page. `SketchDisplayPage` goes, and `SamplePage` keeps only
    History.
  - Test fixtures: `schema-trimmed.json` from the host's schema.
- **Host:** nothing is asked of audio-vue. The settings, the write route and its answer are there
  now.
- **Referenced specs relied on:**
  - `audio-vue:screensaver` (archived from `native-logo`, 2026-11-24): a scene's `display:` block
    sets `bounce`'s four colours and chooses its backdrop and plate. The installation's block sets
    none of them.
  - `audio-vue:logo`: the logo card's four colours are its own, with concrete defaults.
  - `audio-vue:card-colours`: the logo's own colours are a named exception to defaulting to a
    role.
  - `audio-vue:display-sleep`: the two timeouts, a zero skipping only its own stage, and a scene
    overriding them.
  - `audio-vue:settings-schema`: `x-own`, `x-inherits` and the declarations the inspector is
    generated from.
  - `audio-vue:settings-store`: install blocks are written with a revision, a stale write is
    refused, and a `display` write applies at the panel's next start.
  - `audio-vue:render-bundle`: the code the helper carries, and its digest.
