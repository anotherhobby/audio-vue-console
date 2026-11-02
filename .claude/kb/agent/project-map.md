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

- **`Core`**, a Swift package that cannot import SwiftUI.
- **A client generated from the host's `/v1/openapi.json`.**
- **A UI layer that cannot touch the network.** It talks to `Core` only.
- **A thin Xcode app shell.** Everything else builds and tests with `swift test`, which is also all
  the quality gate's type check builds (`pitfalls.md`).
- **`cal-play`**, bundled as a helper binary, built from `../audio-vue/cal-play/`.
- The boundaries are held by tests, not by convention.

## Repository structure

Xcode 27's App template, moved to the root and set to macOS only, Swift 6 and the real bundle ID
(2026-11-02, `decisions-log.md`). No Swift package or test target yet.

- `AudioVueConsole.xcodeproj`: the Xcode project. Xcode 27 stores it as a readable
  `project.xcproj`, not `project.pbxproj`. Its one folder entry is `AudioVueConsole`, relative.
- `AudioVueConsole/`: the app target's sources (`MyApp.swift`, `ContentView.swift`, assets).
- `.claude/`: the KB, plus the twelve `openspec-*` skills under `skills/`.
- `openspec/`: OpenSpec planning (`config.yaml`, `specs/`, `changes/`). Stock `spec-driven`
  schema, no project rules yet.
