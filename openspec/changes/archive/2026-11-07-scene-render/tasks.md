# Tasks

## 1. The contract and the host's reads

- [x] 1.1 Refresh the saved contract with `tools/refresh-contract.sh`; verify `tools/refresh-contract.sh --check` passes and `swift build` in `ConsoleCore` succeeds with the regenerated client.
- [x] 1.2 Add `JSONValue` (`ConsoleCore/Sources/ConsoleCore/JSONValue.swift`): a Codable enum of null, bool, integer, decimal, string, array and object, with a conversion from the generated `OpenAPIObjectContainer`; verify `JSONValueTests` round-trips a scene document with nested params byte-for-byte as JSON, an integer staying an integer.
- [x] 1.3 Add `CardCode` (digest, `from` panel or host) and `HostVersion.cards`, read in `HostClient.version(at:)`; verify `HostClientTests` reads both values and a version with no `cards` fails as `unexpectedAnswer`; add `cards` to every version fixture (`HostClientTests` and `FakeTransport`'s version answer) and verify `HostConnectionTests` still pass.
- [x] 1.4 Add `HostClient+Scenes.swift`: `scenes(at:token:)` (id, name, `builtIn`, `fixed`), `scene(_:at:token:)` (a `SceneDocument` with its `doc`), `install(at:token:)` (each block's `doc` by name), `schema(at:token:)` (the body as `JSONValue`) and `image(_:at:token:)` (the bytes); verify `HostClientScenesTests` over `FakeTransport`, a 404 image included.
- [x] 1.5 Add `HostClient+Cards.swift`: `cardManifest(at:token:)` (`from`, digest, entries); verify `HostClientCardsTests` reads it and maps 401 to `tokenRefused`.
- [x] 1.6 Rewrite `host-contract.md`'s "Scene rendering" for the reads now called; verify it names no API version and points to the saved contract.

## 2. The bundle the app carries

- [x] 2.1 Add `tools/refresh-render-bundle.sh` (`AUDIO_VUE=` override): `make render-bundle` in the checkout, then mirror the checkout's `local/render-bundle/` into this checkout's `local/render-bundle/` with `rsync --delete --exclude __pycache__`; `--check` lists the differences and exits 1, copying nothing; verify a refresh then `--check` passes, and a file added to the mirror by hand is named by `--check` and removed by a refresh.
- [x] 2.2 Extend the tool to build `local/python-runtime/`: read the interpreter's version from the checkout's `.venv`, `uv python install` it into a scratch directory, copy it, `uv pip install -r local/render-bundle/requirements.txt` into it, with `--require-hashes` once the file carries hashes, remove `__pycache__`, and write a stamp of the version and the requirements' hash, skipping the build when the stamp matches; add `local/` to `.gitignore`; verify `local/python-runtime/bin/python3 -c "import numba, scipy, pygame, OpenGL, yaml"` succeeds and a second run skips.
- [x] 2.3 Add the Run Script phase to the app target (design D1a) copying `local/render-bundle/` and `local/python-runtime/` into `Contents/Resources/` with `rsync --delete`, with input and output file lists, failing with the tool's name when the runtime is missing; verify a Debug and a Release build each hold `Contents/Resources/python/bin/python3` and `Contents/Resources/render-bundle/manifest.json`, `codesign --verify` passes on both, and a build with `local/python-runtime/` moved aside fails naming the tool. Stop and report if user script sandboxing refuses the phase (design D1a).
- [x] 2.4 Add `HelperLocation` (`ConsoleCore`): the interpreter and the script under a resources directory, or why there is none (no interpreter, no script, no manifest); verify `HelperLocationTests` with temporary directories.
- [x] 2.5 Record the tool, when to run it, the build phase, the app's size and the sandbox measurements in `commands.md` and `pitfalls.md`, and the mirror in `project-map.md`; verify each entry is dated and names the files.

## 3. The helper's client

- [x] 3.1 Add `HelperFrame` (encode a request; decode an answer and its layers' bytes from chunks split anywhere); verify `HelperFrameTests` with a header split across chunks and a payload split mid-layer.
- [x] 3.2 Add the `HelperProcess` seam and `FoundationHelperProcess`: three pipes, `readabilityHandler` reads, standard error to `os.Logger` (category `render-helper`), `NUMBA_CACHE_DIR` and `PYTHONPYCACHEPREFIX` under Application Support; verify `FoundationHelperProcessTests` echoes a frame through `/bin/cat` and logs a line written to standard error.
- [x] 3.3 Add `RenderHelper` (actor): `hello`, `prepare`, `render`; `RenderFailure.ended` on an end, a short read or a bad frame, then a new process on the next request; `RenderFailure.refused(String)` keeping the process; verify `RenderHelperTests` over `ScriptedHelperProcess` for each case.
- [x] 3.4 Add `LiveHelperTests`, run only when `RENDER_HELPER_LIVE=1`: start `local/python-runtime/bin/python3` on `local/render-bundle/src/render_service.py`, check `hello`'s digest equals `local/render-bundle/manifest.json`'s, render a scene document kept as a test fixture (the proving host's `GET /v1/scenes/rta` answer), then one plate of it; verify it passes and record the timings in `commands.md`.

## 4. Scene documents and the schema's facts

- [x] 4.1 Add `LaidOutScene(_:defaultGrid:)` and `doc(for:)` (design D6); verify `LaidOutSceneTests`: an unset span covers the grid, an unset grid takes the defaults, params and `plate` pass through a move, a new card's entry holds only its cells, a group is written to each member.
- [x] 4.2 Add `SchemaFacts` from `/v1/schema`'s `$defs`: placeable cards with `x-min-cells`, and `block.grid`'s `cols` and `rows` defaults; a card's minimum scaled to a scene's rows, rounded up; verify `SchemaFactsTests` on a trimmed copy of the exported schema.
- [x] 4.3 Give `SceneLayout.resizing` the card's minimum (`CellRect.resizedAcross` stops at it, a card already below it no smaller), and `SceneEditor` the minimums by kind (from 4.2), which it passes for the card resized (`scene-layout`); verify `SceneLayoutTests` for the two new scenarios and the editor's lookup, and that the existing resize tests pass with no minimum given.
- [x] 4.4 Move the shape rule to `DisplayShape` in `ConsoleCore` (match within 0.01, the `8:3` name); verify `DisplayShapeTests` for 1920 x 720 against 96 x 36 and 64 x 36.

## 5. The rendering model

- [x] 5.1 Add `RenderRequest` (scene `doc`, `built_in`, `display`, `fonts`, `rate` always `previewRate`, 48 000 Hz, `images`, `fallback`, optional `plates` and `backdrop`) and `RenderedLayer` (kind, card ids from the placements sent, rect, unfit names, a premultiplied sRGB `CGImage`); verify `RenderRequestTests` encodes the helper's field names and `RenderedLayerTests` reads a 2 x 2 layer's pixels back.
- [x] 5.2 Add `RenderQueue` (design D3); verify `RenderQueueTests`: the canvas's lane goes first, a newer request for the same plates replaces one not sent, one request is in flight at a time.
- [x] 5.3 Add `PlateChanges` (design D5); verify `PlateChangesTests` for a move, a resize, a group, an ungroup, a delete, an add and an undo.
- [x] 5.4 Add `ImageStore`: checks an id's form, fetches it once into Application Support `Images/`; verify `ImageStoreTests` refuses `../x.png` and `a/b.png`, fetches once over `FakeTransport`, and reports a 404.
- [x] 5.5 Add `SceneRendering` (`@Observable`, one per open scene): the first render, plates drawn again from `PlateDiff` after each edit, layers by card id, and what to say (notice, refusal, failure, no renderer, unknown size with 1920 x 1080 used, unfit names); verify `SceneRenderingTests` over a scripted helper.
- [x] 5.6 Add `Thumbnail.flatten(layers:display:width:)`, compositing premultiplied "over" with CoreGraphics; verify `ThumbnailTests` composites a half-alpha layer over an opaque one to the formula within one step.

## 6. The card-code check

- [x] 6.1 Add `CardDrift.between(bundled:host:source:)` and `boxes(_:declaredIn:)` (design D8); verify `CardDriftTests`: equal digests, one family differing, `src/cards/axes.py` differing as shared, an entry only the host has, and a host digest from its files.
- [x] 6.2 Add `CardCodeCheck` (the bundled manifest read, used only when its digest is `hello`'s; the host's manifest read only when the digests differ) and `SceneRendering.apply(_:)`, which boxes a drifted family's cards over their plates and draws nothing for a shared drift or a damaged bundle; a card whose family no manifest names is boxed while any family differs (alignment F3); verify `CardCodeCheckTests` for the verdicts and all three drawings.
- [x] 6.3 Read each card's family entry from the manifest's `cards` map, bundled and host's alike (audio-vue `card-entries`), in `CardDrift`, which boxes a card whose mapped entry differs in either manifest, or one neither declares; and require hashes when building the runtime; verify `CardDriftTests`: a `peak_rms` difference boxes `peak_rms_vertical` and `peak_rms` and no other card.

## 7. The renderer and its Status row

- [x] 7.1 Add `Renderer` (design D9): phases `.idle`, `.starting`, `.preparing`, `.ready`, `.failed`; no helper in a preview; started when `PanelScenes` reports the app paired, `hello` then `prepare` with `{}` and the preview rate; verify `RendererTests` over a scripted helper for each phase, an unpaired app starting nothing.
- [x] 7.2 Add the Renderer row to `PanelRows` and `PanelPage`'s Status (design D9): `—`, "Starting…" with an indeterminate indicator, "Ready", "Could not start: <reason>"; verify `PanelRowsTests` for each phase and `RenderPreview` of `PanelForm` starting and failed.
- [x] 7.3 Make the `Renderer` in `AudioVueConsoleApp.init` and give it to `PanelWindow` and the Scenes page; verify by launching a build paired with the proving host (the row goes from starting to ready, no helper icon in the Dock), and a build whose `Contents/Resources/python` was removed after building (the row says why).

## 8. The Scenes page

- [x] 8.1 Add `PanelScenes` and `HostConnection.makeScenes()` (design D7); verify `PanelScenesTests` over `FakeTransport` loads the listing without fixed scenes, each document, the fonts, the schema's facts and the fallback.
- [x] 8.2 Add `SceneDrafts` (`ConsoleCore`): edited layouts and in-app copies by scene id, Duplicate naming "<name> copy"; make `SceneStore` hold it; verify `SceneDraftsTests`.
- [x] 8.3 Add `AudioVueConsole/Scenes/` (`ScenesPage`, `SceneGallery`, `SceneRow`, `SceneEditorView`, `CardLibrary`, `SceneSettingsPanel`) over `PanelScenes`, `Renderer` and `SceneStore`, with thumbnails from 5.6; verify each with `RenderPreview` over fixture data.
- [x] 8.4 Add `LayerStack` to `SceneCanvas` in place of `CanvasMetrics.backdrop` and `LayoutPlates` when layers are held, moving and stretching layers by the shown cells (design D4), `LayoutPlates` for boxes, and the footer's messages from 5.5; verify with `RenderPreview` over fixture layers, mid-move and mid-resize.
- [x] 8.5 Route `.scenes` in `PanelWindow` to `ScenesPage`; remove `SketchScene`, `SketchCard`, `SketchCardKind`, `SketchShape`, the scenes in `sketch.json`, `SketchScenesPage`, `SketchSceneEditor`, `SketchCardLibrary` and `SketchSceneSettings`, and move `LayoutPlates`' preview off the sample scenes; verify the app builds, `swift test` passes, and no reference to a removed name remains (`grep`).
- [x] 8.6 Update `project-map.md` for the new files and the removed sketches; verify each named file exists.

## 9. Integration

- [x] 9.1 Maintainer's run against the proving host: the Renderer row from starting to ready, the gallery's thumbnails, default and rta opened, a drag, a resize across several cells, a Duplicate edited, a resize stopping at a card's minimum, a release build drawing as a Debug one does; record what was seen in `working-notes.md`.
- [x] 9.2 Extend `LiveHelperTests` to stack rta's layers at 1920 x 720 with `Thumbnail.flatten` at full size and compare them with audio-vue's stacking formula (`out = rgb + under * (1 - a / 255)`) computed in floating point; verify within one 8-bit step, which with audio-vue's two-step hold keeps the app within three of the panel's own render, and record the counts in `host-contract.md`.

## Workflow follow-up

- Archive the change after the maintainer's run, and sync its specs.
- Send audio-vue a handoff naming anything the run found on its side.
