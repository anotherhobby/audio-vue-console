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
- `AudioVueConsole/`: the app target's sources (`panel-client`, 2026-11-05). `AudioVueConsoleApp.swift`
  (the `App`: its `init` makes the one `PanelDiscovery` and the `HostConnection` given it, starts the
  browse, and browses again on activation while denied (`discovery`, 2026-11-06); it owns the
  `SceneStore`, so closing the window keeps them; the single panel window; an app delegate that
  keeps the app running with no window),
  `PanelWindow.swift` (the window: the sidebar of pages, the picker in the Panel page's toolbar,
  the connect at launch, and the `LiveState` it watches while open; pages other than Panel still
  read `SketchData`), `PanelPicker.swift` ("Panel:" and a menu named for the panel held, marked
  discovered until paired: the panel held, the other panels found by address, or the denial line,
  then Add Panel…; `PanelPickerItems` is the menu), `PanelPage.swift` (the page once called
  Overview: a pairing prompt while unpaired, then Status, Capture and Calibration from `PanelRows`,
  then the Pairing section; `PanelForm` takes plain values for previews), `AddPanelSheet.swift`,
  `ConnectionStatus.swift`, `ClientsList.swift` (the inline clients list, `ClientRows` for previews),
  `PanelMetrics.swift` (the window's sizes), `PairingSheet.swift`, assets, and `Sketches/`, the
  sample pages (Input, Calibration, Display) and their panels (`SketchData`, `sketch.json`).
  The App also makes the one `Renderer` (`scene-render`, 2026-11-07), which `PanelWindow` starts
  once paired and the Panel page's Status shows as its Renderer row.
- `AudioVueConsole/Scenes/` (`scene-render`, 2026-11-07): `ScenesPage` (reads the paired panel's
  `PanelScenes`, compares the card code once the renderer is ready, draws the thumbnails, and opens
  scenes), `SceneGallery` and `SceneRow` (this panel's shape first, thumbnails or boxes, Duplicate),
  `SceneEditorView` (library, canvas and inspector over a `SceneEditor` and a `SceneRendering`),
  `SceneInspector` and `SceneSettingsPanel`, `CardLibrary` (the schema's placeable cards), and
  `SceneMetrics`.
- `AudioVueConsole/Canvas/`: the scene canvas, built to keep (`canvas-spike`, 2026-11-04).
  `SceneCanvas` draws a `SceneEditor`'s layout in the panel's outline and turns clicks, drags, the
  marquee and keys into editor calls, asking its `SceneRendering` to draw again what the layout
  changed; `LayerStack` draws the helper's layers there, sliding or stretching a plate from the cells
  it was drawn at; `CanvasHandles`, `CanvasDropDelegate` and `ArrangeCommands` (the Debug-only
  Arrange menu) are its parts. `SceneStore`, owned by the App, holds the `SceneDrafts` (edits and
  copies until quit) and the `SceneThumbnails`; `LayoutPlates` draws any layout as boxes;
  `CanvasMetrics` holds the palette. It holds no layout rules.
- `ConsoleCore/`: the local Swift package holding the app's logic (`Sources/ConsoleCore`) and its
  Swift Testing suite (`Tests/ConsoleCoreTests`). Tools 6.2, Swift 6 mode, macOS 27.2, warnings as
  errors. It must not import SwiftUI or AppKit.
  Its scene layout (`SceneLayout`, `SceneLayoutEdits`, `LayoutRefusal`, `GridGeometry`,
  `SceneEditor`) holds every canvas rule: a layout value is always one the panel would load, each
  edit returns a new one or a refusal, and the editor owns selection and undo.
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
  cards, minimums, the grid's defaults), `DisplayShape`, `PanelScenes` (made by
  `HostConnection.makeScenes()`), `ImageStore`, `SceneDrafts`. The helper: `HelperLocation`,
  `HelperProcess` (`FoundationHelperLauncher`, `ChunkChannel`, `LineSplitter`), `HelperFrame`,
  `RenderHelper` (the actor), `RenderQueue` (two lanes), `Renderer` (phases). Drawing:
  `RenderRequest`/`RenderContext`, `RenderedLayer`, `PlateChanges`, `SceneRendering` (+`Messages`),
  `Thumbnail`, `SceneThumbnails`. The code check: `CardDrift`, `CardCodeCheck`. Tests script the
  helper with `ScriptedLauncher`/`ScriptedHelper` and `FakeRender`; `LiveHelperTests` runs the real
  one when asked.
- `tools/`: `refresh-contract.sh` and `optional_nullables.py`, which writes the contract's nullable
  fields as optional for the generator (`commands.md`); `refresh-render-bundle.sh`, which mirrors
  audio-vue's render bundle and builds the Python runtime into `local/`, and `embed-render-runtime.sh`,
  the app target's build phase that copies both into the app (`scene-render`, 2026-11-07).
- `local/` (ignored by git): `render-bundle/`, the mirror of audio-vue's `local/render-bundle/`;
  `python-runtime/`, the relocatable CPython with the bundle's libraries; `python-downloads/`.
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
