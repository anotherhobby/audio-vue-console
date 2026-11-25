# Spec Delta

## Purpose

Lets the user render the open scene from a music track they pick, as a still at one moment or a clip
over a span, so they can show what a scene does with real music rather than the editor's generated
preview.

## ADDED Requirements

### Requirement: Render with Track opens from the scene editor

The scene editor SHALL offer Render with Track… as a toolbar button and a menu command. It SHALL open
a sheet on the open scene as it is edited, unsaved edits included.

Source: Decision (maintainer, 2026-11-23): a scene editor command opening a sheet.

#### Scenario: An edited scene

- **WHEN** the user changes a card's colour without saving, then chooses Render with Track…
- **THEN** the sheet draws the scene with the new colour

### Requirement: Render with Track says why it cannot be used

Render with Track… SHALL be disabled, saying why, where the scene cannot be drawn:
- the app is not paired;
- the app carries no renderer;
- the scene is too wide for the panel;
- the scene holds no card.

Source: Decision (maintainer, 2026-11-23): drawn at the connected panel's display size. audio-vue
`scene-track-render`, "A scene too wide for the display is refused".

#### Scenario: Too wide

- **WHEN** a scene placing a card past the last column of a 16:9 panel is open
- **THEN** Render with Track… is disabled, and its help says the scene is too wide for the panel

### Requirement: The track is the user's choice of audio file

The sheet SHALL ask the user for an audio file the Mac can decode. It SHALL show the file's name, its
length, its rate and its channel count.

Source: Decision (maintainer, 2026-11-23, audio-vue `track-render` hand-off): the console decodes the
track with the Mac's own audio framework.

#### Scenario: A FLAC album track

- **WHEN** the user picks a 4 min 12 s FLAC file at 96 kHz in stereo
- **THEN** the sheet names the file and shows 4:12, 96 kHz and stereo

### Requirement: A track is decoded at its own rate

A track SHALL be decoded to its samples at the rate it was recorded at, and SHALL never be resampled
for the analysis. A track at a rate the panel does not run at SHALL be refused before it is decoded,
naming the rates the panel runs at, as the host's settings schema lists them.

Source: audio-vue `scene-track-render`, "A track is refused at a rate the panel does not run at".
`capture-input`: the rate list comes from the host's schema, not the app.

#### Scenario: 22,050 Hz

- **WHEN** the user picks a track at 22,050 Hz
- **THEN** the sheet says the panel runs at 44.1, 48, 88.2, 96 and 192 kHz, and nothing can be
  exported

### Requirement: A track of more than two channels is refused

A track of more than two channels SHALL be refused, saying so. A mono track SHALL be taken and passed
to the helper as one channel.

Source: audio-vue `scene-track-render`, "A mono track reaches both channels".

#### Scenario: A 5.1 file

- **WHEN** the user picks a six-channel file
- **THEN** the sheet says the track has more than two channels, and nothing can be exported

### Requirement: The sheet shows the picture at the moment chosen

The sheet SHALL show the scene's picture at the moment chosen, drawn at the panel's display size and
viewing. It SHALL ask for a picture once the moment has stopped moving, and SHALL say it is working
while one is drawn.

Source: Decision (maintainer, 2026-11-23): drawn at the connected panel's display size and viewing.
audio-vue `track-render` hand-off: an earlier moment starts the analysis again, so scrubbing wants a
debounced design.

#### Scenario: Scrubbing

- **WHEN** the user drags the moment from 0:30 to 2:00 and lets go
- **THEN** one picture is asked for, at 2:00, and the sheet shows it once drawn

### Requirement: The sheet says what the helper could not draw

The sheet SHALL show the helper's notice naming a backdrop image it could not draw, and a style the
scene names that the request did not carry.

Source: audio-vue `scene-track-render`, "A track answer says what it could not draw": a still that
quietly used a stand-in backdrop misrepresents the scene.

#### Scenario: A missing image

- **WHEN** the scene's backdrop image is not among the host's images the app holds
- **THEN** the sheet says the image is missing, and shows the fallback backdrop

### Requirement: A still is the picture at its moment as a PNG

Export Still… SHALL save the picture at the moment shown as a PNG at the panel's display size, where
the user chooses.

Source: Decision (maintainer, 2026-11-23): stills and clips of scenes reading real music.

#### Scenario: A still at 1920 x 720

- **WHEN** the panel's display is 1920 x 720 and the user exports a still at 1:05
- **THEN** a 1920 x 720 PNG is saved, the picture the sheet showed at 1:05

### Requirement: A clip is a 10-bit HEVC MP4 of a span with its audio

Export Clip… SHALL save the span from its start to its end as a 10-bit HEVC MP4 at the panel's
display size, tagged with the sRGB transfer function, carrying the track's audio for the span.

Source: Decision (maintainer, 2026-11-23): an MP4 with the track's audio; 10-bit HEVC in place of
H.264 (maintainer, 2026-11-23), after 8-bit H.264 banded a dark gradient backdrop that the panel
shows smooth (design D7).

#### Scenario: A dark gradient backdrop

- **WHEN** a clip is made of a scene whose backdrop is a dark gradient
- **THEN** a frame of it shows the gradient in the steps of the helper's own picture, with no blocks
  or tinted bands

#### Scenario: A 20 s clip

- **WHEN** the user exports a clip from 1:00 to 1:20
- **THEN** a 20 s MP4 is saved, its picture the scene reading the track in 10-bit HEVC and its
  sound the track from 1:00 to 1:20

### Requirement: A clip runs at 30 or 60 frames a second

A clip SHALL be exported at 30 or 60 frames a second, 30 unless the user chooses 60. Frame n of a clip
starting at s seconds SHALL be the picture at sample round(rate × (s + n / fps)).

Source: Decision (maintainer, 2026-11-23). audio-vue `track-render` hand-off: the clip's frame rate is
the console's to name, and this is the moment of each frame.

#### Scenario: 30 fps at 48 kHz

- **WHEN** a clip at 30 fps starts at 10 s into a 48 kHz track
- **THEN** its first three frames are the pictures at samples 480,000, 481,600 and 483,200

### Requirement: A clip's export shows its progress and can be cancelled

While a clip is exported, the sheet SHALL show how many of its frames are written. Cancel SHALL stop
the export and leave no file where the user chose to save.

Source: audio-vue `track-render` hand-off: a picture takes about 40 ms, so a clip of a minute takes
over a minute (measured there on an Apple M4 Pro).

#### Scenario: Cancelled halfway

- **WHEN** the user cancels a 900-frame clip after 450 frames
- **THEN** the export stops, and no file is left at the place chosen

### Requirement: Nothing is rendered where the card code differs

Where the helper's code differs from the panel's for the scene's shared code, or for a card the scene
holds, the sheet SHALL render nothing. It SHALL say which code differs.

Source: `card-code`, "Shared code that differs draws no card" and "A card whose own code differs is a
plain box": a still has no place for a box, and a picture of code the panel does not run misrepresents
the panel.

#### Scenario: The meter's code differs

- **WHEN** the panel runs a newer `meter` than the app carries, and the scene holds a meter
- **THEN** the sheet says the meter's code differs from the panel's, and offers no export

### Requirement: The decoded samples are removed with the sheet

The samples decoded from a track SHALL be kept only while the sheet is open, and SHALL be removed when
it closes or when another track is picked.

Source: Inferred: a five-minute stereo track at 192 kHz is about 460 MB decoded (audio-vue's
archived `2026-11-23-track-render`, design D2).

#### Scenario: Closing the sheet

- **WHEN** the user closes the sheet after picking a track
- **THEN** the decoded samples are no longer on disk

### Requirement: Export Image saves the scene as the canvas draws it

The scene editor SHALL offer Export Image… beside Render with Track…. It SHALL save the scene as the
canvas draws it, the backdrop and every plate stacked at 16 bits a component, at the panel's
display size, as a 16-bit PNG where the user chooses.

Source: Decision (maintainer, 2026-11-23): a simple export of the scene as it is in the scene view;
16 bits after an 8-bit PNG banded under a dark glass card where the canvas did not.

#### Scenario: A drawn scene

- **WHEN** the canvas has drawn a scene for a 1920 x 720 panel and the user chooses Export Image…
- **THEN** a 1920 x 720, 16-bit PNG of the scene as drawn is saved where the user chooses

### Requirement: Export Image waits for the scene to be drawn

Export Image… SHALL be disabled, saying why, until the scene is drawn, and while any card is drawn as
a box.

Source: `card-code`, "A card whose own code differs is a plain box": an image has no place for a box.

#### Scenario: Before the scene is drawn

- **WHEN** the renderer is still drawing the scene
- **THEN** Export Image… is disabled, and its help says the scene isn't drawn yet
