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
