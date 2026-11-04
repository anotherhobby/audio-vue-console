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
- `AudioVueConsole/`: the app target's sources. `AudioVueConsoleApp.swift` (the `App`: the connect
  window, and in Debug builds a second "UI Sketch" window from the Window menu), `ConnectView.swift`
  (binds `HostConnection`; `ConnectForm` takes a state so previews show each), assets, and
  `Sketches/`, the throwaway clickable UI sketch, whose scene editor now hosts the kept canvas.
- `AudioVueConsole/Canvas/`: the scene canvas, built to keep (`canvas-spike`, 2026-11-04).
  `SceneCanvas` draws a `SceneEditor`'s layout in the panel's outline and turns clicks, drags, the
  marquee and keys into editor calls; `CanvasHandles`, `CanvasDropDelegate` and `ArrangeCommands`
  (the Debug-only Arrange menu) are its parts. `SceneStore`, owned by the App, keeps each scene's
  layout until quit; `LayoutPlates` draws any layout, thumbnails included; `CanvasMetrics` holds the
  palette. It holds no layout rules.
- `ConsoleCore/`: the local Swift package holding the app's logic (`Sources/ConsoleCore`) and its
  Swift Testing suite (`Tests/ConsoleCoreTests`). Tools 6.2, Swift 6 mode, macOS 27.2, warnings as
  errors. It must not import SwiftUI or AppKit.
  Its scene layout (`SceneLayout`, `SceneLayoutEdits`, `LayoutRefusal`, `GridGeometry`,
  `SceneEditor`) holds every canvas rule: a layout value is always one the panel would load, each
  edit returns a new one or a refusal, and the editor owns selection and undo.
- The boundaries are held by `Tests/ConsoleCoreTests/BoundaryTests.swift`, which reads source text:
  no SwiftUI or AppKit import under `ConsoleCore/Sources`, and no `import Network` or `URLSession`
  under `AudioVueConsole/`. It finds the repository from `#filePath`, so moving the test file
  moves the root it scans.
- `.claude/`: the KB, plus the twelve `openspec-*` skills under `skills/`.
- `openspec/`: OpenSpec planning (`config.yaml`, `specs/`, `changes/`). The `code-aligned` schema
  (`openspec/schemas/`), with audio-vue registered as a referenced store and rules that check its
  specs. Main specs: `host-connection` and `app-boundaries` (from `walking-skeleton`,
  2026-11-03); `scene-layout` and `scene-canvas` (from `canvas-spike`, 2026-11-04).
