# Code alignment

## Read

2026-11-22:

- `openspec/specs/scene-rendering/spec.md`, "A library tile is the card's plate as the helper
  draws it" (797 characters before its first scenario), and "Library tiles sit on the scene's
  backdrop".
- References to the requirement's header: `AudioVueConsole/Scenes/CardLibrary.swift` and
  `ConsoleCore/Sources/ConsoleCore/LibraryTiles.swift` cite it in doc comments; the header is
  kept, so neither changes. `.claude/kb/agent/project-map.md` describes the tile's size, unchanged
  in meaning.
- No code path changes: the change is wording only.

## Findings

- **F1. The plate-over-backdrop requirement sits beside "Library tiles sit on the scene's
  backdrop"** (resolved)
  - Plan: the behavior split out is a requirement of its own.
  - Code: the existing requirement says a tile shows the helper's backdrop, not a stand-in, and how
    an empty scene gets one; the new one says which part of it lies under the plate, and what
    shows with none. They do not overlap in what they require.
  - Goes to: none.

## Questions for the maintainer

None.

## Confirmed

- Every sentence of the old description is in exactly one of the three requirements, unchanged in
  meaning, and the six scenarios are kept whole.
