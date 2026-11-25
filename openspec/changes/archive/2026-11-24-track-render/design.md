# Design

## Context

See proposal.md for why. The code as it stands:

- **The helper's client.** `RenderHelper` (actor) sends one request at a time and reads its whole
  answer, starting a new helper after one ends. `Renderer` owns the app's single `RenderHelper`. It
  starts it once paired (`hello`, then `prepare` at `RenderRequest.previewRate`) and wraps it in a
  `RenderQueue` with three lanes: canvas, library, thumbnails. `HelperStimulus` is a precedent for a
  request that is not a `render`: a file path in the container's temporary directory, written by the
  helper.
- **The framing.** `HelperFrame.payloadLength` counts only the `bytes` of each entry in `layers`. A
  `picture` answer gives `bytes` at the top of its header, so as the code stands its pixels would be
  read as the start of the next answer.
- **The request's context.** `RenderContext` holds the panel's display, viewing, images directory and
  stored styles, and `RenderRequest.message` builds a `render` from it with the scene's named styles.
  The scene editor gets it from `PanelScenes.context`, beside `displayKnown`.
- **The code check.** `Renderer.verdict` is a `CardCodeVerdict`: `same`; `differs(CardDrift)`, where
  `CardDrift.boxes(_:)` names a card drawn as a box and a non-empty `shared` stops all drawing;
  `damagedBundle`; or `unreadable`. `noCardsReason` words why nothing is drawn.
- **The rates.** `SchemaFacts` reads `install.input.rate`'s `enum`, lowest first: the Capture page's
  rate list.
- **The sandbox.** `ENABLE_USER_SELECTED_FILES` is `readonly` (`project.xcproj`). `ImagePicker` uses
  `NSOpenPanel`. Nothing in the app writes a file the user chose.
- **The helper's side** is audio-vue's `render_service.py` docstring and its `track-render` change: one
  open track per helper, a later moment continuing the analysis and an earlier one restarting it,
  36 to 45 ms a picture at 1920 x 720 and 2.4 s to reach 60 s in at 48 kHz (measured there on an
  Apple M4 Pro).

## Goals / Non-Goals

**Goals:**
- A clip's memory does not grow with its length: each frame is encoded and released before the next
  is asked for.
- The canvas, library and thumbnails draw while a clip exports.
- What the sheet shows is what Export Still saves.

**Non-Goals:**
- Faster pictures. The helper's cost is audio-vue's, and that project has left it as it is.
- Checkpoints for scrubbing backwards. The helper keeps none, and the console adds none.

## Decisions

### D1. The sheet owns a second `RenderHelper` from the same launcher

`Renderer` gains `trackHelper() -> RenderHelper?`, a new `RenderHelper` on its launcher, or nil
where the app carries no renderer. The sheet's model starts it when the sheet opens, calls `hello`
first, and calls `stop()` when the sheet closes. Requests go straight to the actor with no
`RenderQueue`, since the sheet is its only client and asks for one thing at a time. Both helpers share
the caches directory, so the second start finds the compiled code the first made.

Alternatives:
- A fourth lane on the existing queue, below thumbnails: a clip would still hold the one helper for
  its whole length, and a canvas request arriving mid-clip would wait behind a 40 ms picture at
  best. Worse, any `render` between two pictures retargets the display, so audio-vue's D8 cost is paid
  on every interleave.
- A helper per export: scrubbing and exporting want the same open track, so the sheet would open it
  twice.

### D2. Answers with top-level `bytes` carry that many payload bytes

`HelperFrame.payloadLength` adds a top-level `bytes`, when present, to the layers' sum. A negative or
non-integer value is malformed, as for a layer. `render`'s answers carry no top-level `bytes`, so they
read as before.

### D3. Decoding with `AVAudioFile` to a float file, after the rate and channels are checked

`TrackSource` (ConsoleCore) opens the URL with `AVAudioFile`. It refuses the file before decoding when:
- `fileFormat.sampleRate` is not among `SchemaFacts`' rates, naming them in kHz;
- `channelCount` is over 2.

Otherwise it reads `processingFormat` (deinterleaved float32 at the file's own rate) in chunks of
65,536 frames, interleaves them, and writes little-endian float32 to
`temporaryDirectory/Tracks/<uuid>.f32`. It answers the file, rate, channels and length in frames. The
sheet removes the file when it closes or another track is picked.

`AVAudioFile` reads what the Mac decodes (WAV, AIFF, FLAC, ALAC, MP3, AAC), at the file's rate, with no
converter in the path. The schema's rates are the panel's, and a refusal from the helper after a long
decode would waste the user's wait. The helper still refuses a bad rate, so the two cannot disagree
for long without the sheet showing it.

Alternatives:
- `AVAssetReader` with LPCM output settings: more set-up for the same samples, and an output rate
  left unset is easy to get wrong into a resample.
- Writing a WAV: the helper reads no header (audio-vue D2).

### D4. `TrackSession` holds the open track and its last moment

`TrackSession` (ConsoleCore, an actor) wraps the sheet's `RenderHelper`:
- `open(source:scene:builtIn:context:)` sends `track` with `RenderContext`'s display, viewing, images
  and the scene's named styles, built as `RenderRequest.message` builds them. It keeps the answer's
  `length`, `notice` and `style_notice`.
- `picture(at sample:)` sends `picture` and answers a `TrackPicture`: width, height, `drawn` and the
  RGB bytes.
- On `RenderFailure.ended`, it marks the track closed and throws. The next `picture` sends `track`
  again first (`render-helper` delta, "A track render's helper that ends is started again").

The request-building is shared with `RenderRequest` by pulling its named-styles and context fields
into one helper both use. A `track` takes no `rate`, `plates` or `backdrop`.

### D5. Scrubbing asks for the newest moment once the slider rests

The sheet's slider is in seconds over the track's length. A change waits 200 ms (maintainer, 2026-11-23) for the
next. When it rests, the moment becomes `round(rate × seconds)`. If a picture is under way, the moment
replaces the one waiting, and only the newest is sent when the helper is free. While waiting, the last
picture stays shown under a progress indicator. Releasing the slider sends at once.

Alternative: asking on every change. Each backward step restarts the analysis from sample 0, which
takes seconds a minute into a track.

### D6. A still is the shown picture, encoded with ImageIO

Export Still… takes the `TrackPicture` on screen. It does not ask again, so the saved still is exactly
what was shown. It makes a `CGImage` from the RGB (8 bits a component, 24 bits a pixel, no alpha,
sRGB), and `CGImageDestination` writes it as PNG to a URL from `NSSavePanel`.

### D7. A clip is written by `AVAssetWriter`, one frame asked for at a time

`ClipWriter` (ConsoleCore) writes to a temporary file in the container. Once it finishes, the file is
moved to the place the user chose, so a cancel or a failure leaves nothing there. It has two inputs:
- **Video:** 10-bit HEVC (Main10) at quality 0.8, at the picture's size, tagged BT.709 primaries and
  matrix with the sRGB transfer function, through the writer's pixel-buffer receiver in 32BGRA, the
  buffers from a `CVMutablePixelBuffer.Pool`. vImage converts each RGB picture
  (`vImageConvert_RGB888toBGRA8888`, alpha 255). Frame n is presented at the span's start plus
  `CMTime(value: n, timescale: fps)`. The receiver's `append` waits until the writer takes the
  frame, and the next picture is asked for only after it, so at most one picture is held.
- **Audio:** `AVAssetReader` on the original file over the span, as LPCM, into an AAC input (stereo
  or mono as the track, 256 kb/s). `AVAssetWriter` takes AAC only at 44.1 and 48 kHz: it refuses
  88.2, 96 and 192 kHz in `canApply(outputSettings:)` (measured 2026-11-23, macOS 27.2). So the
  file's sound is written at the rate of the track's family: 88.2 kHz becomes 44.1, and 96 and
  192 kHz become 48. Only the clip's sound is resampled; the analysis keeps the track's own rate
  (proposal).

Each input is fed by its own child task (`async let`), the sound from the reader's output provider and
the frames from the pictures, so the writer interleaves them. The macOS 27 SDK deprecates the older
calls: `AVAssetWriterInputPixelBufferAdaptor`, `add`, `startWriting`, `startReading`,
`isReadyForMoreMediaData`, `copyNextSampleBuffer` and `requestMediaDataWhenReady`. The package treats
warnings as errors, so the clip uses the async receivers and providers. The frames are `round(rate × (start + n / fps))` for n from 0 while that moment is before the span's end,
and the moments only rise, so the helper's analysis runs once through the span. The first picture
pays for the run from 0 to the start. Progress is frames written over the frames planned. Cancel
calls `cancelWriting` and removes the temporary file.

Alternatives:
- 8-bit H.264, as first ruled (maintainer, 2026-11-23): replaced the same day. A clip of a dark
  gradient backdrop showed bands, tinted and blocky, that the panel does not. Measured with the real
  helper's picture as the reference: the H.264 frame's banding was 0.69, against the picture's own
  0.17. The error is a light box blur of the decoded frame against a heavy blur of the picture, RMS
  in 8-bit levels, over the bare backdrop. Most of it is the 8-bit 4:2:0 Y'CbCr conversion itself:
  0.60 simulated before any compression. So bit rate did not help (0.69 at 20 and 50 Mb/s). Dither
  on the RGB gave 0.64, and dither in our own Y'CbCr conversion 0.56; the encoder discards the
  dither. 10-bit HEVC at quality 0.8 scored 0.25, after an 8-bit decode, and looked like the
  picture, at about the same file size (2026-11-23).
- ProRes: ruled out (maintainer, 2026-11-23).
- Holding all frames and writing at the end: 4 MB a frame, about 3.7 GB for a 30 s clip at 30 fps.

### D8. What stops a render is decided once, from the verdict and the scene

`TrackRenderAvailability` (ConsoleCore) answers why not, or nil, from:
- the pairing;
- whether the app carries a renderer;
- `LaidOutScene`'s too-wide state;
- the card count;
- `Renderer.verdict`.

Under `.differs(drift)`, a non-empty `drift.shared` stops it, and so does any of the scene's cards for
which `drift.boxes(_:)` is true, naming them with `CardDrift.listed`. `damagedBundle` and `unreadable`
stop it with `noCardsReason`, and a nil verdict (not yet checked) disables it with "Checking the
renderer's code…". The editor's toolbar button and menu command read the same answer for their help.

A parked card is no reason to disable it. The request carries `LaidOutScene.doc(for:)` of the draft's
content, as `SceneRendering` builds its requests, which leaves parked cards out (`card-parking`,
"Parked cards never reach the panel"). Too wide is judged without them too.

### D9. User-selected files become read-write

`ENABLE_USER_SELECTED_FILES` goes to `readwrite` in `project.xcproj`, so `NSSavePanel` can grant the
destination. Opening the track already works under read-only.

### D10. Where it lives

- **ConsoleCore:** `TrackSource`, `TrackSession`, `TrackPicture`, `ClipPlan` (the frame moments),
  `ClipWriter`, `StillWriter`, `TrackRenderAvailability`, and the framing change.
- **App target:** `Scenes/TrackRenderSheet.swift` (the sheet, with track picker, slider and picture,
  start, end and fps, Export Still… and Export Clip…, progress and Cancel), and the toolbar button in
  `SceneEditorView`. The menu command goes in the File menu after Revert to Saved, through a new
  `renderWithTrack` action on `SceneFileActions`, nil while disabled, as Save and Revert are.

The pixel and AVFoundation work stays in ConsoleCore, where it is tested without the app.

## Risks / Trade-offs

- **[Players without HEVC]** Some older players, and Firefox on Linux, cannot play HEVC. → Ruled
  acceptable (maintainer, 2026-11-23). YouTube takes the upload but re-encodes it to 8 bits, so some
  banding can return there; an export for it is a change of its own.

- **[Two helpers' memory]** A second Python process with numba and GL is a few hundred MB while the
  sheet is open. → It lives only with the sheet.
- **[Shared numba cache]** Two processes may write the same cache index at once if both compile.
  → Both run the same bundle, compiled by the first helper before the sheet can open, so the
  second reads. A failure there ends the helper, which the sheet reports and restarts.
- **[Odd display sizes]** HEVC at 4:2:0 wants even dimensions. → Panels seen so far are even
  (1920 x 720, 1920 x 1080). An odd size fails the writer, and the sheet shows its error. If a panel
  needs it, padding by one pixel is a later change.
- **[Cards that read only the frames they are drawn on]** The goniometer and per-block peak holds
  show fewer blocks at 30 fps than a panel at 60. → audio-vue's `cards-see-every-block`, a change of
  its own. The console adds no workaround.
- **[Silence resets]** A long silent intro resets the analysis, as on a panel. → Shown as the panel
  would show it.
- **[Long first picture]** A still five minutes into a 192 kHz track takes about 37 s (audio-vue's
  measure for a whole track). → The progress indicator stays up, and Cancel or closing the sheet ends
  the helper.
