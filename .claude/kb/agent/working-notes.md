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
a token, `/v1/host` and `/v1/openapi.json` included. 4. Panel client (archived 2026-11-06; client generator decided first,
from a saved contract; `/v1/events` hand-written). 5. Discovery (archived 2026-11-06 as `openspec/changes/archive/2026-11-06-discovery`, after the
maintainer's run; its spec is `host-discovery`). Scene editing
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

## Panel client (2026-11-06)

Built and run against the proving host by the maintainer (2026-11-06): connected at launch, live
values, a scene switch followed at once, an agent restart shown not live then live, the inline
clients list with revoke, Add Panel…. Verified and archived as
`openspec/changes/archive/2026-11-06-panel-client` (2026-11-06); its specs are now `host-client` and
`panel-window`, with `host-connection` updated. Pages other than Panel (the Overview, renamed 2026-11-06) still show sample values until their own
changes (maintainer, 2026-11-05). The panel window has no Access page; pairing and the clients list
are in the Panel page's Pairing section (maintainer, 2026-11-05).

## Scene rendering (maintainer, 2026-11-06 and 2026-11-07)

The console renders scenes locally from audio-vue's real card code and analysis; the host renders
nothing for it. The rulings are in `product.md`, "The decision". Built and archived as
`scene-render` (2026-11-07, `openspec/changes/archive/2026-11-07-scene-render`); the maintainer's
run passed every item after deploying audio-vue to the panel.

- The app carries a relocatable CPython with the bundle's pinned, hash-checked libraries
  (`local/python-runtime/`) and a mirror of audio-vue's `local/render-bundle/`
  (`local/render-bundle/`), both ignored by git, built by `tools/refresh-render-bundle.sh` and copied
  in by the build phase (`commands.md`).
- The helper starts once paired, prepares its first run at a fixed preview rate, and keeps numba's
  and Python's caches in the container. A first start after the code changes takes about 7 s, later
  ones about 2 s. The Renderer row under Status says Ready only when the card code matches the
  panel's, and otherwise warns in orange.
- **Any difference in shared code, a comment included, draws no card.** The bundle and the panel
  must come from the same audio-vue code: after audio-vue changes, deploy it to the panel and refresh
  the bundle (2026-11-07: a comment edit to `src/frame.py` stopped all drawing until deployed).
- Asks to audio-vue travel as handoff files in its root. Answered so far: the render dependencies,
  the helper's protocol, and `card-entries` (each card's family in the manifest, hashes in the
  requirements).
- A true-size view needs a diagonal the user enters in the Panel window, with a mm/inch choice, since
  a display's EDID can lie (the maintainer's panel claims 12.3 inches and is nearly 10). Not yet
  planned.

## Scene saving (archived 2026-11-08)

`scene-save` and `track-audio-vue` were built, run by the maintainer and archived on 2026-11-08; their
rulings are in `openspec/specs/scene-saving`, `scene-apply`, `host-connection` and `render-runtime`.
`gallery-sections`, which waited on `scene-save`, may now be built.
- Untested outside the maintainer's run: the quit prompt with the window closed, and Save All during
  `.terminateLater`.

## Gallery sections (2026-11-07, 2026-11-08)

Built and archived as `openspec/changes/archive/2026-11-08-gallery-sections`. Ruled (maintainer,
2026-11-07): "My Scenes", "Built-in Scenes", then "Other Shapes", none dimmed; Apply works on a
scene of another shape (the panel fits it with backdrop either side, audio-vue `scene-grid`), and
the canvas still refuses edits by shape. Ruled 2026-11-08: the editor's card library is grouped by
audio-vue's card categories (its change `card-categories`), the categories and the card order both
from the panel. The handoff `card-order-handoff.md` was answered and `card-categories` archived
(2026-11-08): the schema's root `x-categories` lists `{id, label, cards}` in display order, the
cards in the panel's order. Built 2026-11-08; `LiveGalleryTests` passed against the panel
(Favorite under My Scenes, RTA built in, Default and both card checks under Other Shapes; every
category but Calibration in the library). The maintainer's run passed every item (2026-11-08); a rule
now divides the library's categories, at the maintainer's ask.
