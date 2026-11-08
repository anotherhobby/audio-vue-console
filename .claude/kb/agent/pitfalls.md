# Pitfalls

Record recurring mistakes, broken assumptions, environment quirks, and sharp edges.

## Calibration: set the rate, wait, then arm (2026-11-02)

`cal-play` holds `SETTLE_S`, 12 s, after any change of the device's rate; a chain was measured settling
in 9.9 to 10.5 s. An armed panel waits 10 s for the stimulus. So a `play` that changes the rate spends
the whole arm deadline settling, and the calibration fails. Run `cal-play rate` first, then arm, then
play, as `make calibrate` does. `../audio-vue/.claude/kb/agent/cal-play.md`, "A rate change holds for
the chain".

## The host refuses any `Origin` header (2026-11-02)

The agent answers a request carrying an `Origin` header with a 403, and closes such a WebSocket with
1008, whatever the origin (`host-contract.md`). From memory, not checked: some Swift WebSocket
libraries add an `Origin` by default. Check what the chosen client sends before blaming the token.

## Identify scenes by spec, never by name (2026-11-02)

A scene's `name` is a label (`Glass check`); its spec is the filename stem the host resolves. In
audio-vue this hid on macOS, where a case-insensitive filesystem resolved labels that differed only in
case, and failed on the Pi. Anything the app hands back to the host as a scene's identity uses the
spec. `../audio-vue/.claude/kb/agent/pitfalls.md`, "A scene's `name` is a label".
Since `settings-store` (2026-11-04), a stored scene's identity is the UUID the host assigned, and a
built-in's is still its stem; the rule holds for both.

## A token can stop working without a revocation (2026-11-02)

audio-vue is unreleased, and a host store on another version is deleted and made again, so its clients
must pair again. Treat a 401 on a stored token as "pair again", not as a fault.

## Start Claude from the repository root (2026-11-02)

Started in a subfolder, Claude Code still finds `.claude/CLAUDE.md` by walking up, but loads no
project skills, so the `openspec-*` skills are missing (Measured, from the old `AudioVueConsole/`
subfolder). This is why `AudioVueConsole.xcodeproj` sits at the root: an agent started in the
project's folder, Xcode's included, lands where `.claude/` is.

## Xcode's agent does not run the quality gate (2026-11-02)

Xcode 27 runs its own bundled `claude` with `CLAUDE_CONFIG_DIR` set to
`~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig` (Measured, `xcrun mcpbridge run-agent
--dry-run claude`). Nothing in `~/.claude` loads there, including the user-scope `quality-gate`
plugin, so Swift that Xcode's agent writes goes unchecked. Project files in `.claude/` are not tied to
the config dir. Xcode's tools reach Claude Code instead through `xcrun mcpbridge`, its MCP server.

## The gate's type check builds SwiftPM packages only (2026-11-02)

The quality gate's Stop-hook type check does not build an Xcode project, so code in the app shell goes
unchecked there. Keep logic in packages and the shell thin.

## Xcode MCP quirks (2026-11-02)

- `UpdateTargetBuildSetting` cannot delete a conditional setting such as `KEY[sdk=iphoneos*]`
  ("Unknown build setting"). Edit `project.xcproj` directly for those; Xcode reloads it.
- After an on-disk edit to `project.xcproj`, the workspace ID returned by `XcodeOpenWorkspace`
  goes stale ("No active scheme"). Call `XcodeListWorkspaces` and use the window's `windowtab-*` ID.

## A SwiftUI List crashed inside the scene editor (2026-11-02)

`List(selection:)` with two sections of thumbnail rows, in an `HSplitView` with an `.inspector` and
a toolbar, crashed at 1280x760 with `fatalError in TableViewListCore_Mac2.swift:5556` (macOS 27.2),
in previews and the running app. Each part alone rendered; the cause was not isolated (not the tag,
`onAppear` selection, title or row height). The scene strip became a `ScrollView` of tiles, which
suits a Keynote-style navigator anyway. Bisect with probe `#Preview`s and `RenderPreview`.

## No Local Network prompt when Xcode launches the app (2026-11-03)

Run from Xcode (`RunProject`), the sandboxed app reached the proving host by FQDN, short name and IP
with no Local Network prompt (Measured, `walking-skeleton` task 6.1). Likely cause, unverified:
macOS credits the access to the responsible process, Xcode, which already has it. A user launching
the built app from Finder should see the prompt once. Test the prompt, or a denial, with a
standalone launch (`open` the built `.app`), not from Xcode. A denial reports unreachable.

## CoreGraphics types need `import CoreGraphics` in the package (2026-11-04)

In `ConsoleCore`, `import Foundation` alone makes `CGSize` and `CGRect` visible without their
conformances or members: `CGRect.maxX` and `Equatable` on `CGSize` do not resolve (Measured, Swift
6.4.2). Import `CoreGraphics`, which is not a UI framework, so the boundary test allows it. With the
app's `MemberImportVisibility`, `.plainText` likewise needs `import UniformTypeIdentifiers`.

## SwiftUI's undo manager is not there in `init` (2026-11-04)

`@Environment(\.undoManager)` is only readable once the view is in a window, so the scene editor
builds its `SceneEditor` in `onAppear` and calls `detach()` in `onDisappear`, which removes its undo
actions from the window's manager. The `onAppear` path renders in `RenderPreview`.

## Dragged text cannot be read while it hovers (2026-11-04)

A drop delegate gets the dragged item only at `performDrop`, but the canvas previews a card's size
while it hovers. The library's tile uses `onDrag` to set `SceneStore.draggedKind` as the drag
starts, in place of `.draggable`, and the drop delegate reads the kind from there.

## A refused drop leaves its library tile undraggable (2026-11-07)

On macOS, once a card's drop on the canvas was refused, SwiftUI never called that tile's `onDrag`
again: later drags of it still reached the canvas, with no kind named, so none could be previewed or
dropped. Other tiles, and tiles whose drops were taken, kept working. Answering `true` from
`performDrop` changed nothing (Measured, with a log of each drag step). Making the tile anew does: each
tile's id carries `SceneStore.drops`, which `CanvasDropDelegate.performDrop` counts up. Ids inside a
`LazyVStack` row must stay unique: one `.id(drops)` on every tile collapsed the library to one card.

## An ad-hoc signed app loses silent access to its Keychain items on every build (2026-11-04)

Measured with a sandboxed, ad-hoc signed probe (the app's entitlements, its own bundle ID), macOS 27.2:

- The data-protection keychain (`kSecUseDataProtectionKeychain`) is closed: `SecItemAdd` gives
  `-34018 errSecMissingEntitlement`, since there is no team and so no access group.
- The login keychain works, from inside the sandbox, and silently within one build. The item's ACL
  and its partition ID are both the build's cdhash.
- A new build (any rebuilt or updated app) reading it gets a dialog asking for the **login
  password**, with Always Allow, Deny and Allow. Allow lasts one read. Always Allow adds that build to
  the ACL and the partition list, so the next build asks again. Deny gives `-128 errSecUserCanceled`.
- `kSecUseAuthenticationUIFail` does not stop the dialog.
- Pinning the designated requirement to the identifier (`codesign -s - -r='designated => identifier
  "…"'`) changes the ACL, but the partition ID stays `cdhash:…`, and the dialog still comes.
- A new build can `SecItemUpdate` or `SecItemDelete` an item it cannot read, silently, and then owns
  what it adds.

## Never ask for a new pairing code while the app's own code stands (2026-11-04)

After a wrong code the host keeps the code for its remaining tries and refuses a new one with 409,
"a pairing is under way". The first build offered "Ask for a New Code" after a typo, and the
maintainer's run was left waiting out the 120 s code and the 30 s wait after it (a wait the host has
since dropped after a lapse). Keep the user on the
code field after a 403 and offer a new code only once the code lapses or the host says none is
showing (`HostPairing.mayAsk(at:)`, `host-pairing`, "A mistyped code is typed again").


## Xcode must trust the OpenAPI generator's plugin once (2026-11-05)

Xcode refuses to build until its build plugin is trusted: "Plugin 'OpenAPIGenerator' from package
'swift-openapi-generator' must be enabled before it can be used". The maintainer chose Trust & Enable
once, from the build error, and the MCP `BuildProject` built clean after it (Measured). `swift build`
and `swift test` need no trust. A new plugin, or perhaps a new version of this one, asks again: a
plain next step for the maintainer.

## Checking that the app's window opened (2026-11-05)

`NSApp.windows` and `CGWindowListCopyWindowInfo` (owner name `AudioVueConsole`) tell whether a window
opened; `screencapture -l` cannot capture it from the agent's shell ("could not create image from
window"), so screenshots come from the maintainer or `RenderPreview`. Launching the app binary
directly from a shell opens no window at all, `Window` or `WindowGroup`: SwiftUI opens the first
window only for a LaunchServices launch (`open`, Xcode, Finder) (Measured). Several `open` and Xcode
launches in a row also came up with no window, then later ones did with the same code; the cause was
not found, and window restoration was ruled out. Check a launch more than once before blaming code.

## A `.task` on a view with nothing to show never runs (2026-11-06)

The Overview's clients list loaded in a `.task` on its rows, which are an empty `ForEach` until the
load: a view with no content never appears, so the load never started and the list never showed
(the maintainer's run, `panel-client` 7.1). Start a load where the model is made
(`PanelPage`'s `.task(id:)`, then `OverviewPage`), not on the content it fills. Likewise, a modifier on multi-row
content in a `Form` is copied onto each row, so a row's confirmation dialog belongs on the row.

## A MODIFIED requirement cannot drop or rename a scenario (2026-11-06)

`openspec validate` refuses a MODIFIED block that leaves out a scenario name the main spec has, and
there is no rename for scenarios (`discovery`). When a scenario's behaviour is gone, as
"Connected and not paired" was, replace the requirement: REMOVED (with Reason and Migration naming
the replacement) and ADDED under a new name. Do not keep the old scenario name over new behaviour.

## `open` can bring up Xcode's preview host instead of the build (2026-11-06)

Rendering a preview of the app target starts a copy of the app under Xcode's preview executor
(`PreviewsInjection`, `XOJITExecutor` in a crash's frames). `open` on the built app then brings that
copy to the front rather than launching the build, and it traps in AppKit once its menu bar comes
up (`NSPopupMenuWindow`, `MenuBarClientCore`): two "crashes on launch" in the `discovery` run were
this. Before a hand run, `pkill -x AudioVueConsole`, then `open` the build.

## A toolbar menu sharing an item with text is drawn over the text (2026-11-06)

In the macOS window toolbar, a `ToolbarItem` holding an `HStack` of a `Text` and a `Menu` gets one
glass capsule, and the menu's button is drawn over the text beside it (the Panel picker's "Panel:").
Previews did not show it; the running app did. Give the text its own `ToolbarItem` with
`.sharedBackgroundVisibility(.hidden)`, and the menu its own item (`PanelPicker`).

## A Local Network denial shows as the browser's waiting state (2026-11-06)

`NetworkBrowser` reports a denial as `.waiting` with `kDNSServiceErr_PolicyDenied` (`discovery`
design D6), and a browse restarted on `didBecomeActiveNotification` picks up access given in System
Settings without a relaunch (maintainer's run). The Local Network prompt shows only to an app never
asked before: one already allowed for a typed LAN address is not asked again for Bonjour.

## The App Sandbox hides everything outside the app and its container, a child included (2026-11-07)

A sandboxed app's child inherits its sandbox. Measured with ad-hoc signed probe apps: the app could
not see `../audio-vue/.venv/bin/python` at all ("doesn't exist"). Read-only temporary exceptions made
it run, but an exception path holding `..` was refused, so it must be canonical. A relocatable
CPython copied into `Contents/Resources` runs with no exception, which is why the render runtime is
bundled. Input that a probe reads must come through a pipe, not a path in the scratchpad.

## cal-play works from inside the App Sandbox, as a helper in `Contents/Helpers` (2026-11-08)

Measured from the sandboxed, ad-hoc signed app (`calibration` task 1.2): the bundled `cal-play`, linker-signed
by cargo and run as a child, set the D10s 96000 -> 48000 -> 96000 Hz (12.2 s each with the settle) and played a
WAV from the container's `tmp/` to its end, all exit 0. No entitlement beyond the sandbox was needed, and the
app still passes `codesign --verify --deep --strict`. The child reads files only from the app and its
container, so a stimulus must be written there. CoreAudio names the D10s `D10s ` (trailing space); `cal-play`
matches a case-insensitive substring, so the full name works.

## Xcode's script sandbox refuses a phase that copies whole folders (2026-11-07)

With `ENABLE_USER_SCRIPT_SANDBOXING = YES`, a Run Script phase may read only the files it declares;
declaring a folder in `input-paths` does not let it read the folder's contents (`deny(1)
file-read-data`). "Embed the render runtime" copies thousands of files, so the app target sets it to
`NO` (pending the maintainer's ruling, `scene-render` task 2.3). In the readable project format
(`project.xcproj`) a script phase is an object in `build-phases`: `"kind": "script"`, `"name"`,
`"shell"`, `"script"`, `"input-paths"`, `"output-paths"` and `"run-on-every-build"`. On 2026-11-07 a
phase without an `"id"` left the Xcode app with no targets; since then Xcode's own save dropped the
`"id"`s, and on 2026-11-08 the project loaded and built with two phases and none (checked through
Xcode's MCP tools). Mirror what Xcode last wrote.

## Foundation reports a decimal read as an integer with an error of its own (2026-11-07)

`singleValueContainer().decode(Int.self)` on `0.6` throws Foundation's own
`numberIsNotRepresentableInSwift`, not a `DecodingError`, so catching only `DecodingError` cases lets
it escape. `JSONValue` treats any failed probe as "another type". `48.0` decodes as the integer 48.

## The quality gate checks every committed Python file, a vendored copy included (2026-11-07)

Committing audio-vue's render bundle made the gate report audio-vue's own findings as this
repository's. The gate skips files git ignores, so the mirror lives in `local/`, which is ignored.


## `xcodebuild -derivedDataPath` deletes `Package.resolved` (2026-11-07)

A command-line build with `-derivedDataPath` deletes
`AudioVueConsole.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, the committed
project as much as an edited one (measured). Restore it with `git checkout --` after such a build,
and never commit its deletion.

## An OpenSpec MODIFIED block cannot drop a scenario (2026-11-07)

`openspec validate --strict` refuses a MODIFIED requirement that omits a scenario the standing spec
has, because archive will not drop it. To retire a case, keep the scenario's name and rewrite it to
say what happens now. MODIFIED against a spec another open change adds is only an INFO until that
change is archived; archiving out of order fails.

## A layout's card ids belong to one parse (2026-11-07)

`LaidOutScene.init` gives every card a fresh `UUID`, and `doc(for:)` finds each card's entry by that
id. A layout paired with another parse of the same document finds no entries, and every card is
written back as `card` and its cells alone, losing its settings (`scene-save` alignment F1). Turn a
layout back into a document only through the parse it came from: a `Draft` keeps both. A scene read
again after a save takes the saved layout's ids in order (`LaidOutScene(_:defaultGrid:ids:)`), so an
open editor keeps pairing; a version loaded from Versions is a new parse, so the editor's undo is
cleared (`SceneEditor.replace(with:)`).

## The compiler gives up on a closure ternary in a view's modifiers (2026-11-07)

`cond ? { … } : nil` passed inline to a modifier or initialiser in a long SwiftUI body made Xcode
fail with "Failed to produce diagnostic for expression" and no location inside the body (measured
twice: `SceneEditorView`, `PanelPage`). Move the closure-valued argument into a named property.

## The panel's host can lack a route the saved contract has (2026-11-08)

The contract is regenerated from `../audio-vue`'s source, and the panel runs whatever host was last
deployed to it. Until 2026-11-08 the app let such a host through on the same
major, and a missing route reached it as an undocumented 404 ("answered in a way this app didn't
expect"). Now the connect refuses any host not at the saved contract's version, saying which. Check without a token or side effects: a GET on a POST route answers 405
where the route exists and 404 where it does not (`curl -o /dev/null -w '%{http_code}'
http://audio-vue.local:19200/v1/commands/<name>`). The fix is deploying audio-vue to the panel. The card code
is the mirror image of this: the panel runs its last deploy's, the app the checkout's at its last
build.

## `windowToolbarLabelStyle(_:)` with a binding does not apply the stored style (2026-11-08)

Measured on macOS 27.2 with the debugger (`window.toolbar.displayMode`): bound to an `@AppStorage`
`ToolbarLabelStyle` defaulting to `.titleAndIcon`, the toolbar opened icon-only, and SwiftUI wrote
`.iconOnly` (stored as 7) back into the default, with or without `.toolbar(id:)`. The `fixed:` form
does set the mode, live as its value changes. So the app keeps its own `showsButtonNames` flag,
passes `fixed: showsButtonNames ? .titleAndIcon : .iconOnly`, and offers View ▸ Show Button Names,
since a fixed style takes the toolbar's own menu choice away. To read the mode without a screenshot
(the agent may not capture windows), run with the debugger and print
`NSApplication.sharedApplication.windows.firstObject.toolbar.displayMode` (1 icon and label, 2 icon).
