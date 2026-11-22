# Project Map

Record repository structure, main behavior locations, and concise architecture notes explaining what is being built and why. This is not a junk drawer.

## What this is

audio-vue-console is the SwiftUI macOS desktop app that is the console and control plane for
audio-vue (`../audio-vue`). The host is an appliance and this app is its companion: all truth is
on the host, and the app knows only the API. The product statement is `product.md`; what the app
relies on from the host is `host-contract.md`.

## Intended structure

Recommended in `product.md`, not built (2026-11-02). Replace this section with the real map once code
exists.

- **`Core`**, a Swift package that cannot import SwiftUI. Built as `ConsoleCore` (2026-11-03).
- **A client generated from the host's `/v1/openapi.json`.**
- **A UI layer that cannot touch the network.** It talks to `Core` only.
- **A thin Xcode app shell.** Everything else builds and tests with `swift test`, which is also all
  the quality gate's type check builds (`pitfalls.md`).
- **`cal-play`**, bundled as a helper binary, built from `../audio-vue/cal-play/`.
- The boundaries are held by tests, not by convention.

## Repository structure

Xcode 27's App template, moved to the root and set to macOS only, Swift 6 and the real bundle ID
(2026-11-02, `decisions-log.md`), plus the `ConsoleCore` package (2026-11-03, `walking-skeleton`).

- `AudioVueConsole.xcodeproj`: the Xcode project. Xcode 27 stores it as a readable
  `project.xcproj`, not `project.pbxproj`. Its one folder entry is `AudioVueConsole`, relative.
  A local package is a top-level `"packages": [{ "kind": "local", "path": "ConsoleCore" }]`, and
  linking its product is the target's `"package-product-members": [{ "product-name": "ConsoleCore",
  "build-phase": { "build-phase": "frameworks" } }]` (written by Xcode's Add Local, 2026-11-03).
  `INFOPLIST_FILE` is `AudioVueConsole-Info.plist` at the root, a partial plist Xcode merges with
  the generated one (ATS only); it sits outside the synchronized folder so it is not a resource.
- App icon (2026-11-10): `Assets.xcassets/AppIcon.appiconset` holds the ten macOS sizes, made
  with `sips -z` from the 1024×1024 `Icon.png` at the root; the target sets
  `ASSETCATALOG_COMPILER_APPICON_NAME` to `AppIcon`. A new `Icon.png` means regenerating them.
- `AudioVueConsole/`: the app target's sources (`panel-client`, 2026-11-05). `AudioVueConsoleApp.swift`
  (the `App`: its `init` makes the one `PanelDiscovery` and the `HostConnection` given it, starts the
  browse, and browses again on activation while denied (`discovery`, 2026-11-06); the single
  panel window with the File menu's `SceneCommands` and `ArrangeCommands`; an `AppDelegate` that
  keeps the app running with no window and owns the `SceneStore`, so closing the window keeps it
  and a quit with unsaved scenes asks first, in the window or in an `NSAlert` when none is open;
  `scene-save`, 2026-11-07),
  `PanelWindow.swift` (the window: the sidebar of pages, the picker in the Panel page's toolbar,
  the connect at launch, and the `LiveState` it watches while open; the sidebar is Panel, Scenes,
  Capture, Display and History, and Display and History still read `SketchData`), `PanelPicker.swift` ("Panel:" and a menu named for the panel held, marked
  discovered until paired: the panel held, the other panels found by address, or the denial line,
  then Add Panel…; `PanelPickerItems` is the menu), `PanelPage.swift` (the page once called
  Overview: a pairing prompt while unpaired, then Status, Capture and Calibration from `PanelRows`,
  then the Pairing section; `PanelForm` takes plain values for previews), `AddPanelSheet.swift`,
  `ConnectionStatus.swift`, `ClientsList.swift` (the inline clients list, `ClientRows` for previews),
  `PanelMetrics.swift` (the window's sizes), `PairingSheet.swift`, assets, and `Sketches/`, the
  sample page (Display) and its panels (`SketchData`, `sketch.json`).
  The App also makes the one `Renderer` (`scene-render`, 2026-11-07), which `PanelWindow` starts
  once paired and the Panel page's Status shows as its Renderer row.
- `AudioVueConsole/Scenes/` (`scene-render`, 2026-11-07): `ScenesPage` (reads the paired panel's
  `PanelScenes`, compares the card code once the renderer is ready, draws the thumbnails, and opens
  scenes), `SceneGallery` and `SceneRow` (My Scenes then Built-in Scenes, split by `ConsoleCore`'s
  `GallerySections`; a "Too wide for this panel" note; thumbnails or boxes, Duplicate; `host-grid`
  2026-11-21),
  `SceneEditorView` (library, canvas and inspector over a `SceneEditor` and a `SceneRendering`),
  `SceneInspector` (a card's place and settings; several cards' Group/Ungroup, shared settings,
  then a collapsed section per card), `CardSettings` (`CardSettingsList`, `KeyedBlockRows`: a keyed block's group of rows, `meter-scales-editor` 2026-11-21,
  `SettingRow`, `SettingControl`) and `SettingControls` (`RoleMenu`, `SwatchChip`, `NumberField`,
  `AmountSlider` for a number from 0 to 1, `ColourWell`; `card-settings`
  2026-11-09; a card's colour is a well beside `RoleMenu`, showing its `DrawnColour`, its colours
  under one Colours disclosure), `SceneSettings` (`SceneSettingsPanel` with the tabs Scene, Style
  and Analysis, `BlockSection`, `BlockSettingRow`, `SceneSettingRow`, `GridEditor`),
  `ColourSettings` (`ColourGroups`, `ColourCell`), `BackdropEditor` (`GradientStops`) and
  `ImagePicker` (`ImageTile`) (`scene-settings`, built 2026-11-09, rebuilt on audio-vue's
  `scene-styles` 2026-11-19),
  `CardLibrary` (the schema's placeable cards under the
  panel's categories, from `SchemaFacts.library`, `gallery-sections` 2026-11-08), and
  `SceneMetrics`. From `scene-save` (2026-11-07): `SceneCommands` (File ▸ Save and Revert to Saved
  through the `sceneFile` focused value), `WriteFailureAlert` (`WriteFailureText`: one alert per
  refused write, Save Over It and Discard Mine for a stale save), `RenameSceneSheet`,
  `VersionsMenu`, `EditorBanner` (`EditorBannerText`: Apply's and Reset's outcome, the panel-behind
  note), and `UnsavedScenes` (Save All, Discard or Cancel before a quit or a switch of panel). The
  editor holds a `SceneSession`; the gallery's menu renames and deletes; the Panel page's Status
  offers Reset (`ResetRow`).
- `AudioVueConsole/Calibration/` (`calibration`, 2026-11-08; `input-and-rates`, 2026-11-08;
  `mac-output`, 2026-11-09): the
  sidebar's Capture page. `CapturePage` (`CaptureForm`: `InputSection`, the calibration in force from
  `CalibrationRows`, `CalibrateSection` with Calibrate… or the pass under way, and Calibration History
  from `CalibrationRuns`; a run opens `RunReport`; the runs are read again as each rate ends, and a
  one-rate pass opens its completed report), `InputSection` (the "Input and Output" section;
  `InputFields` for given values: capture device, rate and format pickers over a `PanelInput`,
  asking before a write unless the panel is down, then `OutputFields`; it applies `RateSync` to
  both sides; disabled while a calibration has the panel), `InputRows` (`CaptureFormatRow`,
  `ShallowRow`, `HoldRow` and `InputNoteRow`: the hold after a run with Return to Scene, and the
  write's note), `OutputFields` (`OutputShown`, `OutputActions`: Output Device, Rate and Format
  (this Mac), Synchronize Rates, and `OutputNotes` for the mismatch, a shallow format and a refused
  set), `CalibrateSheet` (names the output chosen in Input and Output and warns where it plays
  under 24 bits; Calibration or Calibration + Characterization, `RunKindText`; at the installed
  rate or at every rate, naming the rates the output skips), `RunProgress`
  (`CalibrateSection`, `RunProgressRows` with "Rate 3 of 5", `PassSummaryRow`, `EndingRow`,
  `EndingText`), `ReportView` (the report in a `WKWebView` from a string, every load blocked, only
  the first navigation allowed) and `RunUnderWay` (the question before a quit or a panel switch cuts
  off a pass). The `AppDelegate` owns the `CalibrationPlayer` and the `CalibrationPass` around a
  `CalibrationSession`, made with the renderer's stimulus; `PanelWindow` feeds the pass each live
  state and whether it is live.
  In `ConsoleCore`: `CalibrationPass` (one run per rate over the session's awaited `run`, going on
  past a failed rate, then returning a synchronized output to the capture rate), `PassPlan` (+`RateOutcome`, `PassOutcome`), `CalibrationSession` (+`Endings`:
  the run's steps, ending from the ended calibration by arm id), `StatedRun`,
  `CalibrationReadiness`, `CalibrationRuns`, `CalibrationRows`, `PanelInput` and `InputEdit` (the
  `input` install block: device, rate and `fmt`), `RateText`, `FormatText`, `CalibrationLifecycle`, `EndedCalibration`,
  `StimulusSource`/`CalibrationHost`, `HelperStimulus` (the helper's `stimulus` request),
  `WAVHeader`, `OutputDevice` (+`OutputFormat`, `OutputFormatRange`: rates and formats offered),
  `OutputControl` (`CoreAudioOutputControl` over `CoreAudioObject`, `OutputWatch` for listeners:
  reads, sets and follows a device), `MacOutput` (the output's model per panel), `RateSync`
  (+`RateMatch`), `PlaybackDeviceMemory` (the device and Synchronize Rates per panel), `HostClient+Calibration` (runs, report), `HostClient+Install` (install
  blocks with revisions, the install write, capture devices) and the arm and cancel in
  `HostClient+Commands`.
- `AudioVueConsole/Canvas/`: the scene canvas, built to keep (`canvas-spike`, 2026-11-04).
  `SceneCanvas` draws a `SceneEditor`'s layout in the panel's outline and turns clicks, drags, the
  marquee and keys into editor calls, asking its `SceneRendering` to draw again what the layout
  changed; `LayerStack` draws the helper's layers there, sliding or stretching a plate from the cells
  it was drawn at; `CanvasHandles`, `CanvasDropDelegate` and `ArrangeCommands` (the Debug-only
  Arrange menu) are its parts. `SceneStore`, owned by the `AppDelegate`, holds the `SceneDrafts`
  (drafts and copies until saved or discarded, forgotten only when another host is paired), the
  `PanelScenes` last read, `UnsavedScenes`, the ids behind on the panel, the `SceneThumbnails` and
  the `LibraryTiles` (2026-11-07, `library-render`;
  `CardLibrary` shows a tile's image in place of its box); `LayoutPlates` draws any layout as boxes;
  `CanvasMetrics` holds the palette. It holds no layout rules.
- `ConsoleCore/`: the local Swift package holding the app's logic (`Sources/ConsoleCore`) and its
  Swift Testing suite (`Tests/ConsoleCoreTests`). Tools 6.2, Swift 6 mode, macOS 27.2, warnings as
  errors. It must not import SwiftUI or AppKit.
  Its scene layout (`SceneLayout`, `SceneLayoutEdits`, `LayoutRefusal`, `GridGeometry`,
  `SceneEditor`) holds every canvas rule: a layout value is always one the panel would load, each
  edit returns a new one or a refusal, and the editor owns selection and undo. Since
  `scene-settings` (2026-11-09) the editor's undoable state is a `SceneContent` (layout plus the
  scene's blocks), which `Draft`, `SceneDrafts`, `SceneRendering` and `SceneThumbnails` hold too;
  `BackdropSource`, `SceneColours` (roles, scales, the colour lookup) and
  `CalibrationCoverage` are its pure parts, and `HostClient+Images` lists and uploads images.
  Its host side (`panel-client`, 2026-11-05): the `HostAPI` target holds `openapi.json`, the host
  contract as `tools/refresh-contract.sh` writes it, and `swift-openapi-generator`'s build plugin
  generates the client from it at `package` access, so only `ConsoleCore` reaches it; its
  `ContractFile` names the bundled copy. `SavedContract` reads that copy for the supported major and
  the operations with no `security`. `HostClient` is the face: each call builds a generated `Client`
  for its address with `HostRules`, the one middleware that strips `Origin`, adds the Bearer token to
  every operation outside the open set and turns a 401 to it into `tokenRefused`, and maps the
  generated answers to this package's values; the calls by subject are in `HostClient+Pairing.swift`
  and `HostClient+Clients.swift`. `HostConnection` owns the client and the `TokenStore`, says
  whether the app is paired, keeps the paired host's `HostIdentity`, and makes the `HostPairing`,
  `PairedClients` and `LiveState` models. It also connects to a found panel with the token kept for
  the announced id (`connect(to:)`, keeping `foundPanel`), and at launch waits for the remembered
  host's id when its address is unreachable; `AddressStore` keeps the address and that id.
  `PanelDiscovery` (`discovery`, 2026-11-06) keeps the panels announced on the LAN, merged by id
  (`FoundPanels`), each resolved once, through the `ServiceBrowser` seam: `BonjourServiceBrowser`
  browses with Network's `NetworkBrowser` and resolves with dnssd's `DNSServiceResolve`; tests use
  `ScriptedBrowser`. `LiveState` holds the pushed `PanelState` from an
  `EventSource` (`WebSocketEventSource` in the app), reopening after a close or five seconds' silence;
  `PanelRows` turns it into the Panel page's text and `PanelLabel` into the picker's. `TokenStore.swift` holds the protocol and `Pairings`, the rules every
  store follows; `FileTokenStore` writes `pairings.json` in Application Support, owner-only.
  `ClientName` is the name the app pairs under. Tests drive it through `FakeTransport`, a
  `ClientTransport` that answers by method and path and records each request as a `URLRequest`, and
  `ScriptedEvents`; `LiveHostTests` runs against a real host only when asked (`commands.md`).
  Scene rendering (`scene-render`, 2026-11-07): `HostClient+Scenes` and `HostClient+Cards` (scenes,
  install, schema, images, the card manifest), `JSONValue` (documents passed through whole),
  `SceneDocument` and `LaidOutScene` (a document as a layout and back), `SchemaFacts` (placeable
  cards, minimums, each card's `SettingGroup`), `SettingGroup` and
  `KeyedBlock` (a keyed block from `x-keys`, its span check and `edit`, `meter-scales-editor` 2026-11-21),
  `SettingValues` (declarations in declared order, shared settings, effective values, off-standard
  notes, numbers written to range and step; `card-settings`), `HexColour`, `PanelScenes` (made by
  `HostConnection.makeScenes()`), `ImageStore`, `SceneDrafts`. Scene writes (`scene-save`,
  2026-11-07): `Draft` (a scene's parse, its layout and its base revision; unsaved by layout, by a
  loaded version or as a copy), `HostClient+SceneWrites` (create, write, delete; `.stale`,
  `.invalid`, `.conflict`), the revisions read in `HostClient+Scenes`, `HostClient+Commands` (switch
  and reset as `CommandOutcome`, a done switch's `SwitchResult`), `SceneWrites` (each write's outcome
  to the drafts and thumbnails, Save All, Apply) and `SceneSession` (one open scene's Save, Rename,
  Discard Mine, Revert, Versions, Apply and Reset, and its `EditorNote`). The helper: `HelperLocation`,
  `HelperProcess` (`FoundationHelperLauncher`, `ChunkChannel`, `LineSplitter`), `HelperFrame`,
  `RenderHelper` (the actor), `RenderQueue` (three lanes: canvas, library, thumbnails, in that
  order; 2026-11-07, `library-render`), `Renderer` (phases). Drawing:
  `RenderRequest`/`RenderContext`, `RenderedLayer`, `PlateChanges`, `SceneRendering` (+`Messages`),
  `Thumbnail` (`flatten`, and `tile`, a plate over its patch of the backdrop), `SceneThumbnails`,
  `LibraryTiles` (one card's plate per tile, kept by the scene's settings without its cards and
  name; `LibraryTiles.swift`, 2026-11-07; a tile is drawn at the smallest size that shows its reading in
  the scene's font settings, found by `LibraryTiles.Ladder`, archived 2026-11-21). The code check:
  `CardDrift`, `CardCodeCheck`. Tests
  script the helper with `ScriptedLauncher`/`ScriptedHelper` and `FakeRender`; `LiveHelperTests`
  runs the real one when asked.
- `tools/`: `refresh-contract.sh` and `optional_nullables.py`, which writes the contract's nullable
  fields as optional for the generator (`commands.md`); `refresh-render-bundle.sh`, which mirrors
  audio-vue's render bundle and builds the Python runtime into `local/`, and `embed-render-runtime.sh`,
  the app target's build phase that refreshes the mirror and copies both into the app, on every
  build (`scene-render`, 2026-11-07; `track-audio-vue`, 2026-11-08).
  `embed-cal-play.sh`, the build phase that builds audio-vue's `cal-play` with cargo and copies it to
  the app's `Contents/Helpers/cal-play`, on every build (`calibration`, 2026-11-08). In `ConsoleCore`,
  `CalibrationPlayer` runs it behind `PlayerLauncher`/`RunningPlayer`, one call at a time; the app's
  is `AppDelegate.player`, stopped in `applicationWillTerminate`. Tests script it with
  `ScriptedPlayerLauncher` (`CalibrationPlayerTests.swift`).
- `local/` (ignored by git): `render-bundle/`, the mirror of audio-vue's `local/render-bundle/`;
  `python-runtime/`, the relocatable CPython with the bundle's libraries; `python-downloads/`;
  `cal-play-target/`, cargo's build of `cal-play`.
- The boundaries are held by `Tests/ConsoleCoreTests/BoundaryTests.swift`, which reads source text:
  no SwiftUI or AppKit import under `ConsoleCore/Sources`, and no `import Network` or `URLSession`
  under `AudioVueConsole/`. It finds the repository from `#filePath`, so moving the test file
  moves the root it scans.
- `.claude/`: the KB, plus the twelve `openspec-*` skills under `skills/`.
- `openspec/`: OpenSpec planning (`config.yaml`, `specs/`, `changes/`). The `code-aligned` schema
  (`openspec/schemas/`), with audio-vue registered as a referenced store and rules that check its
  specs. Main specs: `host-connection` and `app-boundaries` (from `walking-skeleton`,
  2026-11-03); `scene-layout` and `scene-canvas` (from `canvas-spike`, 2026-11-04); `host-pairing`
  (from `pairing`, 2026-11-05); `host-client` and `panel-window` (from `panel-client`, 2026-11-06);
  `host-discovery` (from `discovery`, 2026-11-06, which also updated `host-connection` and
  `panel-window`); `card-code`, `render-helper`, `render-runtime`, `scene-gallery` and
  `scene-rendering` (from `scene-render`, 2026-11-07, which also updated `panel-window`,
  `scene-canvas` and `scene-layout`). No change is open.
