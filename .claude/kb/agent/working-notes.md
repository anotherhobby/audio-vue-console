# Working Notes

Record short-lived but useful task context here. When touching `working-notes.md`, remove stale task notes that no longer help future work.

- 2026-11-02: The Swift quality gate 0.3.0 is installed and enabled at user scope. Its rules:
  `product.md`, "The quality gate".

## First change: walking skeleton (2026-11-02)

Ruled by the maintainer: full Xcode owns the project, at the repo root; Claude Code is the agent,
using Xcode's tools over MCP (`.mcp.json`, approved and working). Do not let the gate drive the
layout; if it forces a bad path, change the gate (asked first).

Ruled for the first change (maintainer, 2026-11-02): option B, the walking skeleton. The app
launches, takes a host address, calls `GET /v1/version` with no `Origin` header, and shows connected
and the API version, or a version mismatch. A `Core` local Swift package that cannot import
SwiftUI, from the start; views stay in the app target for now. The OpenAPI client generator and
`/v1/events` are change 2's first decision.

Done (2026-11-03): built, run against the proving host, and archived as
`openspec/changes/archive/2026-11-03-walking-skeleton`; its specs are now `host-connection` and
`app-boundaries`. Open: audio-vue is naming the default port in `host-store` (archived
`alignment.md` F4). Once it lands, update `host-connection`'s Source line, which says no spec names it.

## Change order after the walking skeleton (maintainer, 2026-11-02)

1. `walking-skeleton` (archived 2026-11-03). 2. Canvas spike (archived 2026-11-04).
3. Pairing (archived 2026-11-05), moved ahead of the client (maintainer, 2026-11-03): once audio-vue's `settings-store` lands, every route but pairing and the version takes
a token, `/v1/host` and `/v1/openapi.json` included. 4. Panel client (client generator decided first,
from a saved contract; `/v1/events` hand-written). 5. Discovery (the host side is built). Scene editing
on a real host waits on audio-vue's settings documents and card tiles.

## Canvas rulings, pending `product.md` (maintainer, 2026-11-02)

Built and archived as the specs `scene-layout` and `scene-canvas` (2026-11-04), still pending in
`product.md`, which only the maintainer edits. UI quirks from the spike's manual run are held by the
maintainer for when the editor is built out, not recorded.

- The grid's shape comes from the connected panel: `/v1/host`'s `width_px`/`height_px` and the scene's
  `grid` in `/v1/state`. When it cannot be told, 16:9 (64x36) is the default. 96x36 at 8:3 is only the
  maintainer's display; most users are expected to be 16:9.
- Cards never overlap.
- A card is refused on drop unless its cells are free; no push and no swap.
- A resize stops at the neighbouring card's edge, by the same rule as a drop.
- Grouping: select cards (click, shift-click, marquee), then Group (⌘G), enabled only when the
  selection tiles a rectangle, saying why when not; a group moves and is removed as one; Ungroup ⇧⌘G.

## Pairing (2026-11-04)

Built, run against the proving host by the maintainer, and archived as
`openspec/changes/archive/2026-11-05-pairing` (2026-11-05); its specs are now `host-pairing` and the
updated `host-connection`. Tokens are in a container file, not the Keychain (`decisions-log.md`). Next is the panel
client (change order item 4). For it: the panel window's Overview should show paired or not with a
Pair button, and its Access page should hold the clients list, as the UI sketch lays out
(maintainer, 2026-11-04); the connect window's Pairing section and the Host menu
(`HostCommands.swift`) hold pairing until then.
