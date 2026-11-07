# Code alignment

## Read

Pass 1, 2026-11-07.

- `AudioVueConsole/PanelWindow.swift`: `SamplePage` routes `.scenes` to `SketchScenesPage`; the
  `.task` that connects at launch; `WatchKey` (task 7.3, 8.5).
- `AudioVueConsole/AudioVueConsoleApp.swift`: `init` makes discovery and the connection; the App owns
  `SceneStore` (tasks 7.3, 8.2).
- `AudioVueConsole/Canvas/SceneCanvas.swift`: `display` (backdrop, region by aspect), `region`
  (`LayoutPlates`, targets, outlines, handles), `shownLayout`, `preview` (task 8.4).
- `AudioVueConsole/Canvas/LayoutPlates.swift`: boxes and the preview built on `SceneStore()` over the
  sample scenes (tasks 8.4, 8.5).
- `AudioVueConsole/Canvas/SceneStore.swift`: layouts by spec from `SketchScene` (task 8.2).
- `AudioVueConsole/Sketches/`: `SketchScenesPage`, `SketchSceneEditor`, `SketchCardLibrary`,
  `SketchSceneSettings`, `SketchData` (`SketchPanel`, `SketchScene`, `SketchCard`, `SketchCardKind`,
  `SketchShape`) (task 8.5).
- `ConsoleCore/Sources/ConsoleCore/HostClient.swift`: `version(at:)`, `call`, `body`, the failure map
  (tasks 1.3 to 1.5).
- `HostClient+Clients.swift`: the shape a token-carrying call takes (tasks 1.4, 1.5).
- `HostClient+Pairing.swift`: `HostIdentity` carries `widthPx` and `heightPx` (design D7).
- `HostConnection.swift`: `makeClients()`, `liveState()`, the kept pairing (task 8.1).
- `PairedClients.swift`: the model pattern `makeScenes()` follows (task 8.1).
- `GridGeometry.swift`: row 0 at the top; `rect(of:)`, `offset(for:)` (design D4).
- `APIVersion.swift`, `SavedContract.swift`: the major check, unchanged by a minor rise (task 1.1).
- `ConsoleCore/Package.swift`: targets, warnings as errors; nothing stops `Process` in `ConsoleCore`
  (design D2).
- `ConsoleCore/Tests/ConsoleCoreTests/`: `FakeTransport.swift:63` and `HostClientTests.swift:29-31,
  58-60` build version answers with no `cards` (task 1.3).
- `AudioVueConsole.xcodeproj/project.xcproj`: `ENABLE_APP_SANDBOX`, no `CODE_SIGN_ENTITLEMENTS`,
  `INFOPLIST_FILE` at the root (task 2.1).
- `tools/refresh-contract.sh --check`: the diff adds `Version.cards`, `CardCode`, `CardManifest` and
  `GET /v1/cards/manifest`, and removes nothing (task 1.1).
- audio-vue `src/render_service.py`: the docstring, `read_message`, `write_message`, `Service.hello`,
  `prepare` (`int(request["rate"])`), `render` (a null rate falls to the default), `main`.
- audio-vue `src/scene_layers.py`: `render` (`chosen` takes a plate holding any named placement),
  `stack` (the formula task 9.2 checks against).
- audio-vue `src/scene_model.py`: `region`, `slot`, `content`, `installed_rate`, `capture_rate_for`,
  `parse` (an unset span is the grid's), `min_span` use at line 263.
- audio-vue `src/layout.py`: `Grid.region` (centred, at the grid's aspect), `span` (GL rows, from the
  top in the format), `min_span` (rounded up).
- audio-vue `src/images.py`: `FORM`, `UPLOAD`, `is_id`, `path` (design D7).
- audio-vue `src/schema/scene.py`, `install.py`, `check.py`, `export.py`: row counted from the top;
  the rate unset is 48 000 Hz; a float setting takes an integer; the exported `$defs`.
- audio-vue `src/panel_screen.py`: the screen's backdrop, glass and card (design D9).
- audio-vue `tests/test_render_service.py`: `Helper`, the reference client.
- Referenced specs, read in full: audio-vue `scene-render` and `render-bundle` (as deltas of the open
  change `console-render`), `control-api` (version, manifest, host, schema, documents),
  `scene-grid`, `card-layout`.
- KB: `open-questions.md` (no open item), `pitfalls.md` (a preview runs a copy of the app; the
  sandbox's Keychain behaviour, not touched).
- Measured with a sandboxed, ad-hoc signed probe app (design Context): the checkout unseen; with
  read-only exceptions, `hello` 0.23 s, the default scene 5.3 s cold and 2.5 s warm, one plate
  0.025 s; an exception path with `..` refused.
- Every task read against the code as the tasks before it leave it. Removals searched under
  `AudioVueConsole/`, `ConsoleCore/`, the Xcode project and the KB (F11).

Pass 2, 2026-11-07, after the maintainer's answers to Q1 to Q6.

- Measured: uv's relocatable CPython with `local/render-bundle/requirements.txt` installed (348 MB)
  and the bundle, in a probe app's `Contents/Resources`, ad-hoc signed as one app, ran under the plain
  sandbox (design Context); `codesign --verify` passed.
- audio-vue `local/render-bundle/`: `manifest.json`'s keys (70, card families as directories,
  `src/cards/axes.py` and other shared files beside them), `requirements.txt` (seven pinned
  distributions with hashes), no interpreter named; `pyproject.toml`'s `requires-python`.
- `tools/refresh-contract.sh`: the pattern the bundle tool follows; `.gitignore` (no `local/`).
- `SceneLayoutEdits.resizing` and `CellRect.resizedAcross`: the one-cell floor task 4.3 replaces;
  `LayoutCard` (kind, cells, group).
- `scene-layout`, "A resize stops at a neighbour's edge", read whole for the MODIFIED block.
- The project's `ENABLE_USER_SCRIPT_SANDBOXING = YES` (task 2.3).
- Tasks of groups 2, 3, 4, 6, 7 and 9 reread against the plan as revised.

## Findings

- **F1. A sandboxed app cannot run the checkout's helper** (resolved)
  - Plan: audio-vue's handoff runs the helper straight from `../audio-vue/.venv` in the first round.
  - Code: the app target is sandboxed. Measured: the interpreter's path does not exist to a sandboxed
    process. Read-only exceptions made it run; so did a bundled relocatable interpreter, with none.
  - Goes to: design D1 and D1a, `render-runtime`, tasks 2.1 to 2.5.
  - Resolution: bundle now (maintainer, 2026-11-07, asking why not; measured to work).

- **F2. `prepare` needs a rate** (resolved)
  - Plan: the first run is made with the default analysis at a rate.
  - Code: `Service.prepare` does `int(request["rate"])`; `render` takes a null rate.
  - Goes to: `render-helper`, "The helper starts once the app is paired"; design D9; task 7.1.
  - Resolution: the rate does not matter to a preview, so the app picks 48 000 Hz for `prepare` and
    every render (maintainer, 2026-11-07, during apply). No ask of audio-vue is needed. The helper
    still starts once paired (maintainer, 2026-11-07).

- **F3. Nothing says which family declares each card** (resolved; built by audio-vue's
  `card-entries`, read in task 6.3, 2026-11-07)
  - Plan: a card whose own entry differs is drawn as a box (`card-code`).
  - Code: the host's manifest comes through the API already, and the app's comes with the bundle
    (`manifest.json`), so no helper request is needed for the entries. Neither manifest says which
    family directory declares a card, and a card's name is not its family's: `peak_rms_vertical` is
    declared in `src/cards/peak_rms/manifest.py`.
  - Goes to: design D8, task 6.2, and a handoff to audio-vue.
  - Resolution: ask audio-vue to carry each card's family in the manifest, so the bundle and the
    host's read both give it (maintainer: "thru the API").

- **F4. The card-layout spec says the console stops a resize at the card's minimum** (resolved)
  - Plan: a resize stopped at the grid's edge and a neighbour, a card at least one cell.
  - Code: audio-vue `card-layout`, Source: "the console will not let a card be resized smaller"
    (maintainer, 2026-11-04). `CellRect.resizedAcross` clamps at one cell.
  - Goes to: `scene-layout` MODIFIED, task 4.3.
  - Resolution: in this change (maintainer, 2026-11-07).

- **F5. The change's scope is wider than "read-only"** (resolved)
  - Plan: Duplicate makes an in-app copy, and the library lists the host's cards.
  - Code: on a host with only built-in scenes every scene is read-only (`scene-canvas`), so with no
    Duplicate no move or resize could be seen drawing real cards. Bundling does not change this: it
    decides where the helper comes from, not which scenes can be edited.
  - Goes to: requirement (`scene-gallery`, `scene-canvas`).
  - Resolution: both kept (maintainer, 2026-11-07).

- **F6. The launch screen** (resolved, superseded)
  - Plan: a SwiftUI launch screen over the window while the helper starts.
  - Code: runs live only in the helper's memory (`scene_frames.Frames`), so every start pays about
    2 s, and the first after an update about 7 s; `prepare` is one request with no steps.
  - Resolution: no launch screen; a Renderer row under Status with an indeterminate indicator
    (maintainer, 2026-11-07). `panel-window` gains the requirement; design D9; task 7.2.

- **F7. audio-vue's change is complete but not archived** (deferred)
  - Plan: `scene-render` and `render-bundle` are named as audio-vue specs.
  - Code: `openspec list --specs --store audio-vue` has neither; they are deltas of `console-render`,
    marked complete, and can change at its archive.
  - Goes to: none now. Apply re-reads both once audio-vue archives.

- **F8. audio-vue's open change names our `scene-canvas` under its Impact** (resolved)
  - Plan: this change modifies `scene-canvas`'s library requirement.
  - Code: `console-render`'s proposal relies on `audio-vue-console:scene-canvas` and `scene-layout`
    for the canvas the layers replace boxes in. The library is not what it relies on.
  - Goes to: the next handoff to audio-vue, which names the change.

- **F9. A version answer with no `cards` now fails** (resolved)
  - Plan: task 1.3 adds `HostVersion.cards`.
  - Code: `Version.cards` is required in the new contract, so the generated decoder refuses the
    fixtures in `HostClientTests` and `FakeTransport`'s version answer.
  - Goes to: task 1.3, which now updates every version fixture.

- **F10. A cell must reach the helper as an integer** (resolved)
  - Plan: design D6 passes the scene's `doc` through.
  - Code: the generated `OpenAPIValueContainer` decodes `Bool`, then `Int`, then `Double`. A
    `JSONValue` with one number case would write `48` back as `48.0`. A float setting accepts an
    integer (`schema/check.py`, `_number`), so the risk is one way.
  - Goes to: design D6 and task 1.2, which keep integers and decimals apart.

- **F11. Removals reach more than the Scenes page** (resolved)
  - Plan: task 8.5 removes the sample scene types.
  - Code: `LayoutPlates`' preview builds `SceneStore()` over the sample scenes;
    `SketchSceneSettings` takes a `SketchScene`; `SketchData` decodes `scenes` from `sketch.json`;
    `project-map.md` describes the sample Scenes page. `SketchPanel` stays, used by `SketchPages`.
  - Goes to: tasks 8.5 (the preview, the settings view, `sketch.json`) and 8.6 (the KB).

- **F12. The helper's Dock icon under the sandbox is unseen** (resolved)
  - Plan: audio-vue keeps the helper out of the Dock (`keep_out_of_dock`).
  - Code: measured on audio-vue's side unsandboxed; the probe here ran headless, so no icon was looked
    for.
  - Goes to: task 7.3, which checks the Dock.

- **F13. `product.md` rules the first frame behind a launch screen at launch** (resolved)
  - Plan: the helper starts once paired, and Status says how it is.
  - Code: `product.md`, "The decision", ruled 2026-11-07: "The first frame is made behind the
    console's launch screen". The maintainer's answers to F2 and F6 move it to once paired, with no screen.
  - Goes to: `product.md`, which only the maintainer approves.
  - Resolution: replaced, with the helper's place in the app beside it (maintainer, 2026-11-07).

- **F14. The bundle names no interpreter** (resolved)
  - Plan: the app carries the interpreter audio-vue's code runs under.
  - Code: `local/render-bundle/` holds no interpreter version; `pyproject.toml` gives only a floor; the
    checkout's `.venv` runs one exact version.
  - Goes to: design D1, task 2.2, which reads it from the `.venv` at refresh.

- **F15. User script sandboxing is on for the project** (resolved, measured at apply)
  - Plan: a Run Script phase copies the runtime and the bundle into the app.
  - Code: `ENABLE_USER_SCRIPT_SANDBOXING = YES` at the project level; a sandboxed script phase reads
    only declared inputs.
  - Goes to: design D1a, task 2.3, which measures it first and stops if it is refused.

- **F16. The bundle's requirements carry no hashes, and its mirror is not committed** (resolved during
  apply, 2026-11-07; the hashes are a handoff ask)
  - Plan: the runtime installs the requirements with hashes required (`render-runtime`); the mirror is
    committed as `RenderBundle/` (design D1).
  - Code: audio-vue's `local/render-bundle/requirements.txt` pins seven versions with no hashes. The
    quality gate checked the committed mirror's Python as this repository's code, reporting findings
    in audio-vue's files, which the mirror must not change.
  - Goes to: design D1, tasks 2.1 to 2.5; the handoff to audio-vue.
  - Resolution: the tool requires hashes once the file carries them; audio-vue is asked to write them.
    The mirror lives in `local/render-bundle/`, ignored by git like the runtime, since a build needs
    the checkout for the runtime anyway.

- **F17. Found during apply** (resolved, 2026-11-07)
  - A script phase in the readable project format needs an `"id"`; without one Xcode loads the
    project with no targets, though `xcodebuild` runs it (`pitfalls.md`).
  - `xcodebuild -derivedDataPath` deletes `Package.resolved`, the committed project too; it is
    restored after each such build (`pitfalls.md`).
  - Foundation reports a decimal read as an integer with its own error, so `JSONValue` treats any
    failed probe as "another type" (`pitfalls.md`).
  - The per-plate state compares each layer with the cells it was drawn for
    (`PlateChanges.needed`), not two layouts, so stale and cancelled draws settle themselves.
  - Task 2.3's checkpoint was reached: Xcode's script sandbox refused the folder copy. The design's
    fallback, `ENABLE_USER_SCRIPT_SANDBOXING = NO` for the app target, is applied so builds work;
    the task stays open for the maintainer's ruling (Q1 below).

## Questions for the maintainer

None open. Q1 (task 2.3) answered 2026-11-07: keep `ENABLE_USER_SCRIPT_SANDBOXING = NO` for the app
target alone.

- **F18. A draw under way survived the card-code verdict** (resolved, the maintainer's first run,
  2026-11-07)
  - The first launch drew scenes although shared code differed: a render in flight when
    `apply(.differs)` cleared the layers wrote them back on its answer. `SceneRendering.draw` now
    drops an answer once drawing has stopped (`CardCodeCheckTests`, the held draw).
  - The relaunch drew nothing, as ruled: the bundle had been refreshed after audio-vue committed a
    comment edit to `src/frame.py`, which the panel did not run yet. The gallery now says why above
    the scenes, not only the canvas footer.
  - The Renderer row said Ready while no card could be drawn, since the comparison ran only on the
    Scenes page (maintainer: a bug; it must not say Ready, and the warning is orange). The window
    now compares once the helper is ready, the renderer holds the verdict, and `panel-window`'s
    Status requirement says Ready only on a match (requirement changed with the maintainer's ruling).

## Confirmed

- Rows count from 0 at the top in the scene format, as `GridGeometry` counts them; the panel's GL
  rows are converted inside `layout.span`.
- `Grid.region` is the largest centred rectangle at the grid's aspect, which is how `SceneCanvas`
  fits the region, so layers placed by their rects meet the grid's outlines.
- An unset grid is 64 by 36 and an unset span covers the grid (`scene-grid`; `scene_model.parse`),
  and both defaults are in the exported schema's `block.grid` and the placement's declaration.
- A minimum scales by the scene's rows, rounded up (`layout.min_span`), as task 4.2 says.
- Naming one member of a group in `plates` returns the group's layer (`scene_layers.render`).
- The display's size is null while the panel is down (`control-api`); the plan draws at 1920 by 1080
  then and says so.
- A fixed scene is not offered to pick or duplicate (`SceneDocument.fixed`), as the gallery leaves it
  out.
- An image id has a fixed form, checked before a file is named by it (`images.FORM`, `is_id`).
- `HostIdentity` already carries the display's size; no new host read is needed for it.
- A minor rise of the contract leaves the major check as it is (`SavedContract`, `APIVersion`).
- Previews run a copy of the app (`pitfalls.md`), which design D9 keeps from starting a helper.
- `ConsoleCore` may run a child process; `app-boundaries` forbids only UI frameworks there and
  networking in the app target.
