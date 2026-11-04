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
