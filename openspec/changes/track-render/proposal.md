# Proposal

## Why

The maintainer wants stills and short clips of scenes reading real music, to show how different
audio-vue's scenes can be. The console's previews read 32 s of generated music, which is right for
editing and wrong for showing what a scene does with a given track. audio-vue's `track-render` gave
the render helper two requests, `track` and `picture`, that analyse a track the console names from its
first sample and draw a scene at any moment of it, every card holding the history a panel that had
played the track would hold. The console now needs the side that picks the track, decodes it, chooses
the moment or the span, and writes the file. This replaces the idea of a screenshot of the live
panel (maintainer, 2026-11-23).

## What Changes

- **Render with Track… in the scene editor** (maintainer, 2026-11-23). A toolbar button and a menu
  command open a sheet on the open scene, unsaved edits included. The sheet:
  - picks a track;
  - scrubs to a moment and shows the scene's picture there;
  - exports a still at that moment, or a clip over a span.
- **The console decodes the track** with the Mac's own audio framework, at its own rate, and hands
  the helper raw float samples (audio-vue's ruling). A track at a rate the panel does not run at, or
  with more than two channels, is refused with the reason. It is never resampled.
- **A still is a PNG at the moment shown.**
- **A clip is a 10-bit HEVC MP4 carrying the track's audio for its span** (maintainer, 2026-11-23;
  HEVC in place of H.264, the same day, after H.264 banded a dark backdrop). It runs
  at 30 or 60 frames a second, 30 by default. Each frame is the picture at its own moment, and the
  export shows its progress and can be cancelled.
- **Drawn at the connected panel's display size and viewing** (maintainer, 2026-11-23). These are
  the same ones the canvas is drawn with. A scene too wide for the panel cannot be rendered, as it
  cannot be applied.
- **Exports run in a helper of their own** (maintainer, 2026-11-23). A clip holds its helper for most of a minute,
  and the canvas, library and thumbnails must not wait behind it. The sheet starts a second helper
  when it opens and ends it when it closes.
- **The card code check holds.** Where the helper's code differs from the panel's for any card the
  scene holds, nothing is rendered, and the sheet says why. A still or clip of code the panel does not
  run would misrepresent the panel.
- **Scrubbing is forward-friendly** (maintainer, 2026-11-23). Moving the moment later continues the analysis, and
  moving it earlier starts it again from the track's first sample. The sheet asks for a picture only
  once the moment has stopped moving, and says it is working while one is drawn.

Not doing:
- A screenshot of the live panel.
- Display sizes other than the panel's.
- Other formats: H.264, ProRes, GIF or a still as JPEG.
- An export for YouTube (scaled to 4K, with faint grain to survive its 8-bit re-encode): a change of
  its own, if wanted.
- A queue of exports, or exporting several scenes at once.
- Working around cards that read only the blocks they are drawn on (the goniometer and per-block
  peak holds). audio-vue is changing those cards in a change of its own. Until then, a clip shows
  what a panel drawing at the clip's frame rate would show.

## Capabilities

### New Capabilities

- `track-render`: rendering a scene from a music track the user picks: the sheet, the track's
  decoding and refusals, the moment and the span, the still and the clip, and what stops a render.

### Modified Capabilities

- `render-helper`: exports have a helper of their own, started with the sheet and ended with it,
  so the canvas's requests never wait behind a clip.

## Impact

- **Code:**
  - `ConsoleCore` gains the track session:
    - `track` and `picture` on `RenderHelper`;
    - the track's request built from `RenderContext`;
    - the moments of a clip;
    - decoding to a float file in the container's temporary directory.
  - `ConsoleCore` gains a clip writer: AVFoundation's asset writer, 10-bit HEVC frames from the helper's
    RGB with the track's audio for the span. It also gains a PNG writer.
  - `Renderer` gains a way to start a second helper from the same launcher.
  - The app target gains the sheet, the toolbar button and the menu command.
- **Sandbox:** user-selected files go from read-only to read-write, so Save can write the still or
  clip where the user chooses.
- **Host:** nothing is asked of audio-vue. The requests are in its render helper now.
- **Referenced specs relied on:**
  - `audio-vue:scene-track-render`, once audio-vue archives `track-render`; until then the change's
    delta. It covers opening a track, the rate and channel refusals, mono to both channels, the
    analysis at the track's own rate, the request's display and viewing, notices, too wide,
    whole-block moments, past the end, history from the first sample, successive moments and an
    earlier moment, the picture within two steps of the panel's, and the preview left as it was.
  - `audio-vue:scene-render`: the render helper's requests, its refusals and its standard streams.
  - `audio-vue:render-bundle`: the code the helper carries, and its digest.
