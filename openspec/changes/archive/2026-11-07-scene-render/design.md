# Design

## Context

See `proposal.md` for why. The state today, read on 2026-11-07:

- **The Scenes page is a sample.** `PanelWindow`'s `SamplePage` shows `SketchScenesPage` over
  `SketchData.shared` (`sketch.json`): `SketchPanel`, `SketchScene`, `SketchCard`, `SketchCardKind`
  (the library's roster, sized from the sample scenes) and `SketchShape` (the shape rule, an aspect
  match within 0.01). `SceneStore`, owned by the App, builds a `SceneLayout` per sample scene and
  keeps edits by spec until quit. `SketchSceneEditor` hosts `SceneCanvas` with the panel's aspect.
- **The canvas draws boxes.** `SceneCanvas.display` fills the panel's outline with
  `CanvasMetrics.backdrop`, fits the grid's region inside it by aspect, and draws `LayoutPlates`
  (coloured rounded rectangles) under the hit targets, outlines and handles. `shownLayout` is the
  layout as the current gesture would leave it. `GridGeometry` maps cells to points with row 0 at the
  top, as audio-vue's scene format counts rows (`schema/scene.py`, "counted from 0 at the top").
- **The host side.** `HostClient` calls the version, `/v1/host`, pairing and clients; each call
  builds a generated client with `HostRules`. `HostConnection` makes `PairedClients` and `LiveState`
  with the kept token (`makeClients()`, `liveState()`). `HostIdentity` already carries the display's
  `widthPx` and `heightPx`. The saved contract is older than audio-vue's: `tools/refresh-contract.sh
  --check` shows `Version.cards` (required) and `GET /v1/cards/manifest` added, nothing removed.
- **The helper** (audio-vue `src/render_service.py`, read 2026-11-07): `hello`, `prepare`,
  `render`, framed as a 4-byte big-endian length and JSON, layers' bytes after the answer. `render`
  takes a null `rate` (it falls to the analyser's default through `installed_rate`); `prepare` does
  `int(request["rate"])` and so needs one. `plates` picks each plate holding any named placement, so
  one member names a group's layer (`scene_layers.render`).
- **The sandbox.** The app target sets `ENABLE_APP_SANDBOX` with no entitlements file. Measured with
  sandboxed, ad-hoc signed probe apps (2026-11-07): the checkout's `.venv/bin/python` cannot be seen.
  A relocatable CPython (uv's `cpython-…-macos-aarch64`) with the bundle's pinned libraries installed
  into it, and `local/render-bundle/`, copied into the probe's `Contents/Resources` and sealed by an
  ad-hoc signature of the app alone (`codesign --verify` passes), ran under the plain sandbox: `hello`
  0.41 s cold and 0.15 s warm, the default scene at 1920 x 720 7.2 s with numba's and Python's caches
  empty and 2.0 s filled, one plate again 0.021 s, and the digest the checkout's helper gives. The
  interpreter and libraries are 348 MB; the bundle is 1.5 MB.
- **The bundle** (`local/render-bundle/`, written by `make render-bundle`): 107 files at their
  repository paths, `manifest.json` (`digest`, `entries`, 70 entries keyed by repository path, a card
  family as its directory `src/cards/<family>`, shared modules as files, `src/cards/axes.py` among
  them) and `requirements.txt` (seven distributions, pinned with hashes). It names no interpreter;
  audio-vue's `pyproject.toml` requires one at or above a version, and its `.venv` runs one.

## Goals / Non-Goals

**Goals:**

- Every picture of a scene comes from the helper, or is a plain box that says why it is not.
- Nothing in the app does cell or pixel arithmetic of the panel's: layers arrive with their rects.
- The rules (which plates to draw again, what a drift draws, what a request carries) live in
  `ConsoleCore`, where Swift Testing reaches them through a scripted helper.

**Non-Goals:**

- Signing, notarising or slimming the bundled interpreter (the app is ad-hoc signed, `product.md`).
- Writing anything to the host: saving, creating, deleting scenes, Apply.
- The inspector's settings, scene settings, and any edit that changes a scene setting.
- The panel's physical size, which the user will enter in the Panel window (a later change).

## Decisions

### D1. The app carries a relocatable CPython and the mirrored bundle

`tools/refresh-render-bundle.sh` does two things, like `tools/refresh-contract.sh` with `AUDIO_VUE=`
naming the checkout. It runs `make render-bundle` there and mirrors its `local/render-bundle/` into this
checkout's `local/render-bundle/`, ignored by git, removing what audio-vue's no longer holds;
`--check` diffs instead. Then it builds `local/python-runtime/` (ignored by git): uv installs the
interpreter the checkout's `.venv` runs, as a relocatable build, and installs the mirror's
`requirements.txt` into it, hashes required once the file carries them (it carries none today,
alignment F16), and `__pycache__` directories are removed. It
rebuilds the runtime only when the interpreter or the requirements changed (a stamp file beside it).

- *Over sandbox exceptions pointing at the checkout*: measured to work, but only in Debug, by
  build settings naming one machine's paths, and thrown away by the next change (maintainer,
  2026-11-07: why not bundle now).
- *Over Homebrew's framework*: it links against `/opt/homebrew`, so it is not relocatable.
- *Over a frozen binary*: ruled out (maintainer, 2026-11-07, "bundling CPython").
- Neither is committed (changed during apply, alignment F16): the runtime is built from the
  checkout's interpreter, so a build needs the checkout anyway, and a committed copy of audio-vue's
  code would be held to this repository's checks, which audio-vue's code answers to on its own side.
- The interpreter is the one the checkout's `.venv` runs, read from it at refresh, since that is the
  one audio-vue's tests ran the bundle under; no version is written into this repository.

### D1a. A build phase copies both into the app

A Run Script phase after Resources copies `local/render-bundle/` to `Contents/Resources/render-bundle/` and
`local/python-runtime/` to `Contents/Resources/python/` with `rsync --delete`, before the app is
signed; it fails the build, naming the tool to run, when the runtime is missing. The app's own ad-hoc
signature seals both as resources, as measured.

- `ENABLE_USER_SCRIPT_SANDBOXING` is on for the project, so the phase declares its inputs and outputs
  in file lists, which task 2.3 measures first; the fallback is turning it off for this target alone.
- *Over folder references in the project*: Xcode's copy of a folder reference does not delete what the
  source no longer holds, and the project's one folder entry is the synchronized `AudioVueConsole`.

### D2. The helper's client is an actor in `ConsoleCore`, over a process seam

`RenderHelper` (an actor) speaks the protocol: `HelperFrame` encodes and decodes the framing, and
`HelperProcess` is the seam: start, write, an `AsyncStream<Data>` of standard output's chunks and
terminate. `FoundationHelperProcess` runs Foundation's `Process` with three pipes, reads standard
output and error through each handle's `readabilityHandler`, and sends error lines to `os.Logger`
(subsystem the bundle id, category `render-helper`). Tests use `ScriptedHelperProcess`.

- It starts `Contents/Resources/python/bin/python3` on `Contents/Resources/render-bundle/src/
  render_service.py` (`HelperLocation`, from `Bundle.main`).
- The environment it is started with: `NUMBA_CACHE_DIR` and `PYTHONPYCACHEPREFIX`, directories in
  Application Support (the container's, under the sandbox), so neither cache is written beside the
  code, which the sandbox refuses. Measured: both were written and used.
- *Over blocking reads*: a prepare runs seconds, and a blocking read would hold a thread of the
  cooperative pool that long.
- A process that ends, a short read or a frame that does not parse fails the request in flight with
  `RenderFailure.ended`, and the next request starts a new process. `ok: false` with `refused` is
  `RenderFailure.refused(String)`, and the process is kept.
- `ConsoleCore` may run a process: `app-boundaries` forbids only UI frameworks there.

### D3. One request at a time, the canvas first

`RenderQueue` (main actor) feeds the helper one request at a time. It holds two lanes: the canvas's
and the thumbnails'. The canvas's lane runs first, and within it a newer request for the same plates
replaces one not yet sent (`render-helper`, `scene-rendering`). So a resize sends the size it is at
when the helper is free, never a queue of every step.

### D4. A layer is a `CGImage`, placed by its rect

`RenderedLayer` holds the kind, the card ids it holds (mapped from the placement indices of the
document sent), its rect in display pixels, the cards it names as not fitting, and a `CGImage` made
over the bytes as 8-bit RGBA, premultiplied last, sRGB. `ConsoleCore` already imports CoreGraphics
(`GridGeometry`).

- sRGB, because the scene's colours are written as sRGB hex and the panel shows them unmanaged.
- The canvas's `LayerStack` view draws the backdrop over the whole panel outline and each plate at
  its rect times one factor, the outline's width over the display's. The grid's region stays where
  `SceneCanvas` puts it, the largest centred rectangle at the grid's aspect, which is how audio-vue's
  `Grid.region` fits it (`layout.py`), so layers and outlines agree.
- While a gesture is shown, a plate's layer is moved by the change in its cells' rectangle, edge by
  edge, in points: a move translates it, and a resize stretches it until the new layer arrives.

### D5. An edit draws again the plates it changed

`PlateDiff` compares the layout before and after an edit by card id. A plate is a card in no group,
or a group; it is drawn again when its members or any member's cells changed. Removed plates drop
their layers. The request names one placement per plate, since the helper draws a group's layer for
any member. Moves draw again on release only; resizes on each cell step and release.

### D6. A scene document keeps what the layout does not

`SceneDocument` holds a scene's id, name, `builtIn`, `fixed` and its `doc` as a `JSONValue`, a small
Codable enum in `ConsoleCore` with integers and decimals kept apart, so a placement's params, plate
colour and alternate pass through untouched and a cell is never sent as `48.0`. `SceneDocument.layout(defaults:)` builds the `SceneLayout`: the grid from `doc.grid`, else
the schema's declared defaults; each card's cells, an unset `col` or `row` being 0 and an unset span
the whole grid (audio-vue `scene_model.parse`). It keeps each card's original entry by its new id.
`document(for:)` writes the layout back into `doc.cards`, in layout order, each entry its original
with `col`, `row`, `colspan`, `rowspan` and `group` replaced, and a new card's entry those alone.

### D7. The host's reads go through one model

`HostConnection.makeScenes()` makes `PanelScenes` with the kept token, as `makeClients()` does. It
reads `/v1/scenes`, each scene's document, `/v1/install` (the `fonts` block's `doc`), `/v1/schema` (each `card.*` with `x-placeable` and `x-min-cells`, and `block.grid`'s
defaults), and the `default` scene's `doc.backdrop` as the fallback. The display size is the
connection's `HostIdentity`. `HostClient` gains `scenes`, `scene(id:)`, `install`, `schema`,
`image(id:)` and `cardManifest`, in `HostClient+Scenes.swift` and `HostClient+Cards.swift`, and
`HostVersion` gains `cards`, a `CardCode` of the digest and where it came from.

- Images are kept in Application Support under `Images/`, each file named by its id, after checking
  the id against audio-vue's form (a name with no separator, ending `.png`, `.jpg` or `.jpeg`, no
  `..`), since the host's text becomes a file name. An id held is never fetched again: an upload's id
  is its SHA-256, and a shipped image's name changes with it.

### D8. The card-code check compares the host's manifest with the bundled one

`CardCode.compare(bundled:host:)` is pure. Equal digests match. Otherwise each differing key is a card
family's when it is a directory under `src/cards/` and shared otherwise (`src/cards/axes.py` is
shared), and a card is drawn as a box when its family's entry differs (`card-code`). The bundled
manifest is `local/render-bundle/manifest.json`, used only when its digest equals `hello`'s
(`render-runtime`). Each manifest maps every card to its family's entry (`cards`, audio-vue
`card-entries`); a card whose entry differs in either manifest, or one neither declares, is a box. A
message lists at most three names, then how many more (`CardDrift.listed`); the Status row lists
none and points to the Scenes page (maintainer, 2026-11-07).

### D9. The renderer starts once paired, and Status says how it is

`Renderer` (main actor, `@Observable`), made in the App's `init`, owns the queue and the helper and
moves through `.idle` (not paired), `.starting`, `.preparing`, `.ready(digest)` and `.failed(reason)`.
`PanelScenes` (D7) tells it when the app is paired, and it starts the helper then: `hello`, then
`prepare` with `{}` and `RenderRequest.previewRate`, 48 000 Hz, which every render request carries too
(maintainer, 2026-11-07: the rate does not matter to a preview). Only the narrowband card's spectrum
depends on the rate, and on generated music it shows its empty state. A scene that sets its own
`capture_rate` still gets a run at that rate, since the helper lets it win (one more run, about 2 s).
It starts
no helper in a preview (`XCODE_RUNNING_FOR_PREVIEWS`, since a preview runs a copy of the app,
`pitfalls.md`). Once ready, `PanelWindow` has it compare its code with the panel's
(`Renderer.checkCode`, through `PanelScenes.cardCode`, nothing loaded) and holds the verdict there,
which the Scenes page and the editor read. `PanelRows` gains the Renderer row from the phase and the
verdict: `—` while idle, "Starting…" and "Making the first frame…" with an indeterminate
`ProgressView`, "Checking the card code…", "Ready" only when the code matches, and in orange, a shared
or card difference, a damaged bundle, or "Could not start: <reason>" (maintainer, 2026-11-07, after
the first run said Ready while drawing nothing). A later host at another rate changes nothing there: the render that
needs the new run makes it, and the canvas says it is drawing.

- *Over a launch screen*: the wait is about 2 s at every start and about 7 s at the first after the
  app changes, since runs live only in the helper's memory and numba recompiles for new code. A row
  under Status is enough to show the app is not hung (maintainer, 2026-11-07).
- *Over a determinate progress bar*: `prepare` is one request with one answer, and its time is the
  analysis of 32 s of music, so there are no steps the app can count. A bar would need audio-vue's
  protocol to send progress before the answer, which so short a wait does not earn.

### D10. The Scenes page leaves the sketches

`ScenesPage`, `SceneGallery`, `SceneRow`, `SceneEditor` view (named `SceneEditorView`, since
`SceneEditor` is the core's model), `CardLibrary` and `SceneSettingsPanel` move to
`AudioVueConsole/Scenes/` over `PanelScenes`, `Renderer` and `SceneStore`. `SceneStore` keeps layouts
and in-app copies by scene id. `DisplayShape` (the shape rule and its `8:3` name) moves to
`ConsoleCore`. `SketchScene`, `SketchCard`, `SketchCardKind`, `SketchShape` and the sample scenes in
`sketch.json` go; `SketchPanel` stays for the sample pages.

## Risks / Trade-offs

- [The app grows by about 350 MB, and every build copies it] → `rsync` copies only what changed; the
  runtime is rebuilt only when its stamp changes.
- [A fresh clone cannot build until the tool has built the runtime] → the build phase fails naming the
  tool (`commands.md`).
- [uv's relocatable interpreter is not the one audio-vue's `.venv` was made from (Homebrew's)] → the
  version is the same, read from the `.venv`; the live test (task 3.4) runs the bundled helper, and
  the digest check catches a bundle that is not the checkout's code.
- [Nested code in `Resources` is sealed, not signed] → measured to run under the sandbox; a download
  is allowed past Gatekeeper by hand already (`product.md`, "Packaging").
- [A layer is about 5.5 MB at 1920 x 720, and thumbnails would hold every scene's] → only the open
  scene keeps its layers; a thumbnail is flattened to a small image and the layers dropped.
- [Colours shown on a wide-gamut Mac display differ from the panel's] → the layers are tagged sRGB,
  so ColorSync shows the colours the hex values name.
- [The stacked layers in the app differ from the panel's render] → audio-vue holds its stacking to
  two 8-bit steps of its own render; task 9.2 holds the app's compositing to one step of that
  stacking's formula. What Core Animation does on screen is not measured: it composites in the
  display's colour space.
- [Edits are lost at quit, copies included] → the existing rule (`scene-canvas`); saving comes later.

## Open Questions

None that change the plan. The questions that do are in `alignment.md`.
