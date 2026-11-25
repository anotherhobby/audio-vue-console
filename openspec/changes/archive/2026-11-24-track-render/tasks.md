# Tasks

## 1. The helper's new answers (`ConsoleCore`)

- [x] 1.1 Count a top-level `bytes` in `HelperFrame.payloadLength`
  (`ConsoleCore/Sources/ConsoleCore/HelperFrame.swift`, design D2), adding it to the layers' sum; a
  negative or non-integer value throws `.malformed`. Verify: new cases in the framing tests read a
  `picture` answer of 12 bytes split across three chunks, and a `render` answer with layers reads as
  before; `xcrun swift test --disable-xctest --filter HelperFrame` passes.
- [x] 1.2 Pull the context fields `RenderRequest.message` builds (`display`, `viewing`, `images`,
  `styles` filtered to the scene's named ones, `scene`, `built_in`) into one function on
  `RenderContext` that `RenderRequest.message` and the track request both call
  (`RenderRequest.swift`, design D4). Verify: the existing `RenderRequest` tests pass unchanged.
- [x] 1.3 Add `Renderer.trackHelper() -> RenderHelper?` (`Renderer.swift`, design D1), a new
  `RenderHelper` on the same launcher, nil where `Renderer` has none. Verify: a `RendererTests` case
  with `ScriptedLauncher` shows two launches, one per helper, and stopping the track helper leaves the
  first answering.

## 2. Decoding a track (`ConsoleCore`)

- [x] 2.1 Add `TrackSource` (`ConsoleCore/Sources/ConsoleCore/TrackSource.swift`, design D3). It opens
  a URL with `AVAudioFile` and refuses a rate outside `SchemaFacts`' `install.input.rate` list (worded
  in kHz) or more than two channels, both before decoding. It writes interleaved little-endian
  float32 to `temporaryDirectory/Tracks/<uuid>.f32` in chunks of 65,536 frames, and answers file,
  rate, channels and frames. `remove()` deletes the file. Verify: new `TrackSourceTests`, with WAVs
  generated in the test:
  - a 1 s stereo 48 kHz sine gives 48,000 frames and a 384,000-byte file whose first samples match;
  - a mono file gives one channel and 4 bytes a frame;
  - 22,050 Hz is refused, naming 44.1, 48, 88.2, 96 and 192 kHz from the fixture schema's rates;
  - a 6-channel file is refused;
  - `remove()` leaves no file.

## 3. The track session (`ConsoleCore`)

- [x] 3.1 Add `TrackSession` and `TrackPicture` (`TrackSession.swift`, design D4):
  - `open` sends `track`, built with 1.2's context function plus `path`, `rate` and `channels`, and
    keeps `length`, `notice` and `style_notice`.
  - `picture(at:)` sends `picture` with `moment` and answers width, height, `drawn` and the RGB
    payload; a payload not `width × height × 3` bytes throws.
  - After `.ended`, the next `picture` sends `track` again first.

  Verify: new `TrackSessionTests` with `ScriptedHelper`:
  - the `track` message's fields;
  - a picture's bytes;
  - a refused `track` surfacing the helper's words;
  - a helper ending, then the next `picture` reopening the track before its `picture`.
- [x] 3.2 Add `ClipPlan` (`ClipPlan.swift`, design D7): the frame moments
  `round(rate × (start + n / fps))` for n from 0 while before the span's end. Verify: tests for the
  spec's 30 fps at 48 kHz scenario (480,000, 481,600, 483,200), a 20 s span at 60 fps giving 1,200
  frames, and moments that only rise.
- [x] 3.3 Add `TrackRenderAvailability` (`TrackRenderAvailability.swift`, design D8): nil or the
  reason, from pairing, renderer, too wide, no card, and `CardCodeVerdict`. Verify: a test per
  reason:
  - `differs` with shared drift;
  - `differs` boxing a card the scene holds, with the name listed;
  - `differs` boxing only a card it does not hold, which is allowed;
  - `damagedBundle`, `unreadable` and a nil verdict.

## 4. Writing stills and clips (`ConsoleCore`)

- [x] 4.1 Add `StillWriter` (`StillWriter.swift`, design D6): a `TrackPicture` to PNG through
  `CGImage` (24 bpp, no alpha, sRGB) and `CGImageDestination`. Verify: a test writes a 4 x 2 picture
  of known colours and reads the PNG back with ImageIO, pixel for pixel.
- [x] 4.2 Add `ClipWriter` (`ClipWriter.swift`, design D7): `AVAssetWriter` to a temporary `.mp4`,
  10-bit HEVC at the picture's size (H.264 as first planned; replaced on 2026-11-23, design D7), a
  32BGRA pixel-buffer adaptor fed through
  `vImageConvert_RGB888toBGRA8888`, frame n at `CMTime(value: n, timescale: fps)`, and AAC audio at
  256 kb/s read from the source file over the span with `AVAssetReader`. The audio is written at 44.1
  or 48 kHz as the source is, at 44.1 kHz for an 88.2 kHz source, and at 48 kHz for 96 or 192 kHz. It
  pulls the next picture only when the video input is ready, reports frames written, moves the file
  to the destination on finish, and on cancel or failure removes the temporary file and writes
  nothing at the destination. Verify: new `ClipWriterTests` with a scripted picture source:
  - a 2 s clip at 30 fps of a generated 96 kHz stereo WAV gives an MP4 of 60 video frames,
    `AVURLAsset` reporting about 2.0 s, a 10-bit HEVC video track tagged sRGB at the picture's size and an AAC audio
    track at 48 kHz;
  - the same at 88.2 kHz gives AAC at 44.1 kHz;
  - cancelling after 10 frames leaves no file at the destination and none in the temporary
    directory.

## 5. The sheet and its command (app target)

- [x] 5.1 Set `ENABLE_USER_SELECTED_FILES` to `readwrite` in `AudioVueConsole.xcodeproj/project.xcproj`
  (design D9). Verify: the app builds, and `codesign -d --entitlements - ` on the built app shows
  `com.apple.security.files.user-selected.read-write`.
- [x] 5.2 Add `AudioVueConsole/Scenes/TrackRenderSheet.swift` and its model (design D5, D10). The
  sheet has:
  - Choose Track… (`NSOpenPanel` for audio types) and the track's name, length, rate and channels, or
    `TrackSource`'s refusal;
  - the slider, debounced 200 ms and sent at once on release, with only the newest moment waiting;
  - the picture, under a progress indicator while drawn;
  - the helper's notices;
  - start and end fields, defaulting to the moment and 20 s on, and a 30/60 fps picker defaulting to
    30;
  - Export Still… and Export Clip… through `NSSavePanel`, the clip with progress and Cancel.

  The track helper starts when the sheet opens and stops when it closes, and the decoded file is
  removed then or on a new track. Verify: it builds; a SwiftUI preview shows the sheet with a sample
  picture and no helper; the quality gate reports the files clean.
  Built 2026-11-23: the sheet's state is `TrackRender` in ConsoleCore (tested in
  `TrackRenderTests`), the view `TrackRenderSheet`. The preview shows the sheet before a track is
  chosen, with a launcher that starts nothing; a sample picture would need a way into the model's
  private state. Xcode's MCP `RenderPreview` could not render it (the workspace listed no schemes),
  so the preview is checked only by building.
- [x] 5.3 Add Render with Track… to `SceneEditorView`'s toolbar (after Duplicate) and to the File
  menu after Revert to Saved, through a new `renderWithTrack` on `SceneFileActions`
  (`SceneCommands.swift`), nil while disabled. Both use `TrackRenderAvailability`'s reason, the button
  as its help. They open the sheet on `draft.laidOut.doc(for: draft.content)` (unsaved edits included,
  parked cards left out, design D8), `draft.laidOut`'s built-in flag and `scenes.context`. Verify: it
  builds; with a scene too wide the button is disabled with its help, and the menu item is disabled.
- [x] 5.4 Add Export Image… beside Render with Track… (maintainer, 2026-11-23): `SceneRendering.picture`
  and `pictureUnavailable` (`SceneRendering+Picture.swift`) flatten the canvas's layers at the
  display's size at 16 bits a component (`Thumbnail.flatten(bits:)`; the maintainer's look,
  2026-11-23), `StillWriter.write(_: CGImage, to:)` saves them, and `failureAlert`
  (`FailureAlert.swift`) says why a save failed. Verify: `SceneRenderingPictureTests` pass, the
  saved PNG reading back at 16 bits; the app
  builds; the quality gate reports the files clean.

## 6. Integration

- [x] 6.1 Add `LiveTrackRenderTests`, skipped without `RENDER_HELPER_LIVE`, run as
  `RENDER_HELPER_LIVE=1 xcrun swift test --disable-xctest --filter LiveTrackRenderTests` in
  `ConsoleCore/`. It decodes a generated 10 s 48 kHz stereo sine, opens it with
  `Fixtures/rta-scene.json` at 1920 x 720, draws pictures at 1 s and 5 s and writes a 2 s clip from
  3 s, then prints the timings. Verify: it passes; record the command and timings in
  `.claude/kb/agent/commands.md`.
- [x] 6.2 Update the KB: `project-map.md` (the new types and the sheet) and `host-contract.md`
  (the helper's `track` and `picture` paragraph, now used by the app). Verify: the files name every
  type added in groups 1 to 5.
- [x] 6.3 The maintainer's run on the proving panel (reviewed on screen, 2026-11-24):
  - open a scene and Render with Track…;
  - pick an album track at 44.1 kHz and one at 96 kHz;
  - scrub forward and back;
  - export a still and a 20 s clip at 30 and at 60 fps, and play them in QuickTime;
  - cancel a clip;
  - edit another scene while a clip exports;
  - Export Image… a drawn scene and compare the PNG with the canvas.

  Verify: the maintainer reports each item as expected.

## Workflow follow-up

- Once audio-vue archives `track-render`, point `track-render`'s sources at
  `audio-vue:scene-track-render` as a standing spec.
- Verify, then archive the change after the maintainer's run.
- Remind the maintainer to delete `track-render-handoff.md` and `rta-fine-bands-handoff.md`.
