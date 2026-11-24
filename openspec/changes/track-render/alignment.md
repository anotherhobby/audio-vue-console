# Code alignment

## Read

Pass of 2026-11-23, every group of the plan:

- `ConsoleCore/Sources/ConsoleCore/RenderHelper.swift`: `ask`, `accepted`, `drop`, the one-at-a-time
  lock, and `hello`, `prepare` and `stimulus` as the shape for `track` and `picture`.
- `HelperFrame.swift`: `payloadLength` sums only `layers[].bytes`; `HelperAnswerReader.next`.
- `RenderQueue.swift`: three lanes on one `RenderHelper`, newest-with-key replacement.
- `RenderRequest.swift`: `RenderContext` fields, `namedStyles`, `message`.
- `Renderer.swift`: one `RenderHelper` from `launcher`, `start`, `verdict`, `stimulus`, `stop`.
- `HelperStimulus.swift`: a helper-written file in the container's temporary directory.
- `HelperProcess.swift`, lines 65–100: the caches directory and the environment a launch is given.
- `CardCodeCheck.swift`, `CardDrift.swift`: `CardCodeVerdict` cases, `boxes(_:)`, `listed`,
  `noCardsReason`.
- `SchemaFacts.swift`, `inputRates(_:)`: `install.input.rate`'s `enum`, lowest first.
- `LaidOutScene.swift`: `doc(for: SceneContent)` writes `content.layout.cards` only; `isTooWide`.
- `SceneSession.swift`: `hasParked`, `canApply`, `canDuplicate`, `isTooWide`.
- `PanelScenes.swift`, `context`: a `RenderContext`.
- `AudioVueConsole/Scenes/SceneEditorView.swift`: `toolbar`, `fileActions`, `.focusedSceneValue`.
- `AudioVueConsole/Scenes/SceneCommands.swift`: `SceneFileActions` and the File menu's Save and Revert.
- `AudioVueConsole.xcodeproj/project.xcproj`: `ENABLE_APP_SANDBOX` YES, `ENABLE_USER_SELECTED_FILES`
  `readonly`.
- Tests: `ScriptedHelper.swift` (`ScriptedLauncher.launches`, `requests`), `RendererTests`,
  `HelperFrameTests`, `RenderRequestTests`, `Fixtures/schema-trimmed.json`.
- KB: `pitfalls.md` (the sandbox and its child, cal-play from the container's `tmp/`, toolbar items),
  `open-questions.md` (nothing on the helper or exports).
- audio-vue:
  - `src/render_service.py`'s docstring;
  - `openspec/changes/track-render/` (proposal, design, `scene-track-render` delta);
  - `scene-render` (standing), "The helper speaks over its standard streams", "says which card code
    it carries", "A request carries a scene and its display";
  - `render-bundle` (requirement list);
  - open changes `cards-see-every-block` (empty folder), `rta-fine-bands`, `track-render`.
- Measured: `AVAssetWriter.canApply(outputSettings:forMediaType: .audio)` for AAC stereo at 256 kb/s,
  on macOS 27.2.

## Findings

- **F1. A `picture` answer's pixels are not counted** (resolved)
  - Plan: `picture` answers `bytes` after its JSON.
  - Code: `HelperFrame.payloadLength` reads only `layers`, so the pixels would be read as the next
    answer's length and the stream judged malformed.
  - Goes to: design (D2) and task 1.1.
  - Resolution: a top-level `bytes` is added to the payload length.

- **F2. AAC above 48 kHz** (resolved)
  - Plan (first draft): the clip's sound resampled to 48 kHz above 48 kHz, assumed.
  - Code: measured, `AVAssetWriter` accepts AAC at 44,100 and 48,000 Hz and refuses 88,200, 96,000
    and 192,000 Hz in `canApply`.
  - Goes to: design (D7) and task 4.2.
  - Resolution: the sound is written at its family's rate (88.2 → 44.1; 96 and 192 → 48). The analysis
    is unchanged. Task 4.2 tests 96 and 88.2 kHz sources.

- **F3. The menu command goes through a focused value** (resolved)
  - Plan (first draft): a command in `SceneCommands`.
  - Code: `SceneCommands` is the File menu, acting on `SceneFileActions` from `@FocusedValue`, each
    action nil while disabled.
  - Goes to: design (D10) and task 5.3.
  - Resolution: a `renderWithTrack` action after Revert to Saved.

- **F4. Parked cards** (resolved)
  - Plan (first draft): silent.
  - Code: `card-parking`, "Parked cards never reach the panel", covers the scene the helper draws.
    `LaidOutScene.doc(for:)` writes only `content.layout.cards`, and `SceneSession` holds back Apply
    and Duplicate while a card is parked.
  - Goes to: design (D8) and task 5.3.
  - Resolution: the request uses `doc(for: content)`, so parked cards are left out. Parking does not
    disable Render with Track, since nothing is written to the host.

- **F5. audio-vue's `scene-track-render` scenario names the RTA's weighting in the scene's analysis**
  (resolved: handed to audio-vue, Q3)
  - Plan: relies on "A track is analysed at its own rate under the scene's analysis block", not on
    that scenario.
  - Code: its scenario "A time weighting" says "a scene whose analysis takes the RTA's Slow
    weighting". Since `rta-card-settings` and `rta-fine-bands`, that is the `rta_bars` card's
    `reading`, and the scene's `analysis:` holds no RTA setting.
  - Goes to: neither; audio-vue's session should reword it before archiving `track-render`.
  - Resolution: raised with the maintainer.

- **F6. audio-vue's `track-render` names our `render-helper` under Impact** (resolved: handed to
  audio-vue, Q3)
  - Plan: `render-helper` gains two ADDED requirements (a track render's own helper, and its restart).
    No existing requirement changes.
  - Code: audio-vue's `track-render` proposal relies on `audio-vue-console:render-helper` for "the
    helper is the app's child and keeps its caches in the app's container", which this change keeps.
  - Goes to: neither; the maintainer tells audio-vue's session that the console runs a second helper
    while the sheet is open.

- **F7. audio-vue's `cards-see-every-block` is open** (deferred)
  - Plan: the proposal's Not doing leaves cards that read only the blocks they are drawn on to
    audio-vue.
  - Code: the change's folder exists with no artifacts. When it lands, a clip's goniometer and
    peak holds change, with no console change, since the helper draws them.
  - Goes to: neither.
  - Resolution: deferred until it lands. The bundle refresh brings it in.

- **F8. The referenced spec is still a change** (deferred)
  - Plan: relies on `audio-vue:scene-track-render`.
  - Code: it is a delta in audio-vue's open `track-render`, not a standing spec, so it can change
    before archive.
  - Goes to: tasks (Workflow follow-up).
  - Resolution: re-point the sources once audio-vue archives it.

- **F9. The macOS 27 SDK deprecates the writer calls D7 named** (resolved during apply, 2026-11-23)
  - Plan: a pixel-buffer adaptor, `requestMediaDataWhenReady` queues and `cancelWriting`.
  - Code: the SDK deprecates `AVAssetWriterInputPixelBufferAdaptor`, `add`, `startWriting`,
    `startReading`, `isReadyForMoreMediaData` and `copyNextSampleBuffer`, and the package treats
    warnings as errors.
  - Goes to: design (D7).
  - Resolution: the async receivers and providers, the sound and the frames each fed by its own
    `async let`.

- **F10. The sheet's state is in ConsoleCore, and the rates come from `SchemaFacts`** (resolved during
  apply, 2026-11-23)
  - Plan: the sheet and "its model" in the app target. The rates from `SchemaFacts`' function.
  - Code: the editor holds `SchemaFacts` but not the schema, so `SchemaFacts` now keeps `rates`. The
    model, `TrackRender`, went to ConsoleCore so `TrackRenderTests` can hold its ordering,
    newest-moment-wins scrubbing and cleanup. `TrackRenderAvailability` gained "The panel's rates
    can't be read". `RateText` shows a hundredth, so 22,050 Hz reads 22.05 kHz, not 22 kHz.
  - Goes to: tasks (5.2's note).

- **F11. H.264 bands a dark gradient backdrop** (resolved after the maintainer's look, 2026-11-23)
  - Plan: clips as H.264 MP4.
  - Code: a clip frame of a dark backdrop showed bands that the panel and the still do not. The
    frame's PNG profile was CoreMedia 709 and its flat runs were multiples of 16 pixels. The cause
    is 8-bit 4:2:0 Y'CbCr, not the encoder's settings; the measurements are in design D7.
  - Goes to: requirement (the maintainer ruled 10-bit HEVC), design (D7), task 4.2.
  - Resolution: 10-bit HEVC at quality 0.8, tagged sRGB. `ClipWriterTests` checks the codec, the 10
    bits and the tag.

## Questions for the maintainer

All three answered by the maintainer on 2026-11-23, each as recommended:

- **Q1 (proposal, D1).** Exports run in a helper of their own, started with the sheet and ended with it.
  Ruled yes.
- **Q2 (D5, task 5.2).** The picture is asked for once the slider rests for 200 ms, and a new clip spans
  the 20 s from the moment shown. Ruled as written.
- **Q3 (F5, F6).** audio-vue's session is told to reword `scene-track-render`'s "A time weighting"
  scenario to the card's `reading`, and that the console runs a second helper. Ruled yes, through a
  handoff file in audio-vue's root (`console-track-render-handoff.md`, 2026-11-23).

## Confirmed

- `RenderHelper.ask` sends any `op` and checks `ok`, `refused` and `error`, so `track` and `picture`
  need no new transport, only the framing change (F1).
- `ScriptedLauncher` counts launches and requests, so task 1.3's two-helper test and 3.1's request
  tests can be written with the existing doubles.
- `SchemaFacts.inputRates` reads the rates from the schema. The fixture holds 44,100, 48,000, 88,200,
  96,000 and 192,000, so task 2.1's refusal wording can be tested against it.
- `PanelScenes.context` is a `RenderContext` with display, viewing, images and styles: what `track`
  takes besides the scene and samples.
- A helper child reads files only from the app and its container (`pitfalls.md`). The decoded samples
  go in the container's temporary directory (D3), as the stimulus does.
- `ENABLE_USER_SELECTED_FILES` is `readonly` today, so task 5.1 is needed for `NSSavePanel`
  destinations.
- `CardCodeVerdict` and `CardDrift` give what D8 needs: shared drift, per-card boxes, and a reason
  for a damaged or unreadable bundle.
- Designed numbers:
  - 1 s of 48 kHz stereo float32 is 384,000 bytes;
  - 30 fps from 10 s at 48 kHz gives samples 480,000, 481,600 and 483,200;
  - 20 s at 60 fps is 1,200 frames;
  - a 1920 x 720 RGB picture is 4,147,200 bytes, so 900 frames would be about 3.7 GB held, which
    D7's one-at-a-time pull avoids;
  - five minutes of 192 kHz stereo float32 is 460,800,000 bytes (audio-vue D2).
