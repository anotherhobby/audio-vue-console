# Agent Decisions Log

Record implementation decisions made by agents.

Format:

- YYYY-MM-DD: Decision. Rationale. Evidence or related files.

- 2026-11-02: OpenSpec delivered as skills only, with no slash commands (maintainer). The two
  overlap heavily and the skills work well. Matches audio-vue's setup.

- 2026-11-02: The app's product statement lives here, in `agent/product.md`, edited only with the
  maintainer's approval. audio-vue keeps the host platform in `host-platform.md` and leaves
  `desktop-app.md` as a pointer. The app is this repository's whole purpose, while the host side
  is still built against in audio-vue, including by its open `settings-schema` and
  `settings-documents` changes.

- 2026-11-02: Template settings fixed (maintainer asked; bundle ID chosen by the maintainer):
  macOS only, Swift 6 with warnings as errors (`product.md`, "The quality gate"), App Sandbox kept
  on with outgoing network added, bundle ID `com.hobbysprawl.AudioVueConsole`, minimum macOS 27.2.
  Default actor isolation MainActor kept for the app target. Hardened runtime left off: it matters
  for notarization, and the app is ad-hoc signed (`product.md`, "Packaging"). Built and checked via
  Xcode MCP.

- 2026-11-02: The app allows plain HTTP to any host (`NSAllowsArbitraryLoads`, maintainer). The proving
  host is named by a fully qualified name that `NSAllowsLocalNetworking` does not cover, the host API
  is HTTP-only until it serves TLS, and a domain exception would write one network into the app.
  Revisit when the host gains TLS. `openspec/changes/walking-skeleton/design.md`.

- 2026-11-04: The quality gate's `no_magic_numbers` allows 2 as well as 0 and 1 (maintainer, raised
  when `size.cols / 2` centred a dropped card): halving and doubling are arithmetic, and naming 2
  would be a constant nobody reuses. Edited in `claude-qualty-gate/baseline/swiftlint.yml`, and
  committed there by the maintainer.

- 2026-11-04: The scene canvas is plain SwiftUI, with no AppKit fallback: a `DragGesture` per card's
  hit target, `highPriorityGesture` handles above it, a marquee surface beneath, and
  `onDrop(of:delegate:)` for the library. Confirmed by the maintainer's manual run (`canvas-spike`
  5.1, 2026-11-04): every `scene-canvas` scenario held. UI quirks were seen but held for a later
  change, since none contradicts a scenario. `openspec/changes/archive/2026-11-04-canvas-spike/design.md`.
