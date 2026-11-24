# Spec Delta

## ADDED Requirements

### Requirement: A track render has a helper of its own

Render with Track… SHALL start a helper of its own when its sheet opens, and SHALL end it when the
sheet closes. Its requests SHALL never wait behind the canvas's, the library's or the thumbnails',
and theirs SHALL never wait behind it.

Source: audio-vue `track-render` hand-off: one helper answers one request at a time, and a clip holds
it for most of a minute. Decision (maintainer, 2026-11-23).

#### Scenario: Editing during an export

- **WHEN** a clip is being exported and the user resizes a card in another scene
- **THEN** the resized plate is drawn without waiting for the clip

#### Scenario: Closing the sheet

- **WHEN** the user closes the Render with Track sheet
- **THEN** its helper's standard input is closed and the helper ends, and the canvas's helper keeps
  running

### Requirement: A track render's helper is greeted before its first track

A track render's helper SHALL be asked which code it carries before it is sent a track.

Source: audio-vue `scene-render`, "The helper says which card code it carries". `card-code`: the app
draws by the helper only where it knows that code.

#### Scenario: Opening the sheet

- **WHEN** the user opens the Render with Track sheet and picks a track
- **THEN** the sheet's helper is greeted before the track is sent to it

### Requirement: A track render's helper that ends is started again

When a track render's helper ends, the sheet SHALL say the picture or the export failed, and SHALL
start a new helper and open the track again for the next request it makes.

Source: audio-vue `track-render` hand-off: a helper that ends loses its open track, and the console
opens it again. `render-helper`, "A helper that ends is started again".

#### Scenario: A crash while scrubbing

- **WHEN** the track render's helper ends while drawing the picture at 2:00
- **THEN** the sheet says the picture could not be drawn, and moving the moment again starts a new
  helper, opens the track and draws it
