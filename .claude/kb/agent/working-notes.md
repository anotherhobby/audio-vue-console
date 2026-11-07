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

## Scene rendering, pivoted (maintainer, 2026-11-06)

The console renders scenes locally from audio-vue's real card code; the host renders nothing for it.
The three rulings are in `product.md`, "The decision". audio-vue builds the renderer as its
`console-render` change (design read 2026-11-07); its reply handoff `render-dependencies-reply.md`
answered this side's `render-dependencies-handoff.md`, and both can go. Agreed, 2026-11-07:

- The runtime is a bundled CPython plus the render path's wheels, not a frozen binary.
- **The console makes its frames itself** (maintainer, 2026-11-07): the helper runs the panel's own
  analysis over 32 s of music generated in code, under each scene's analysis block and rate, and keeps
  the frames for its life. So the bundle holds the analysis, numba and scipy included: about 445 MB
  uncompressed, performance weighed above size. A frame costs about 3.7 s on the Mac with numba's cache
  empty and 1.6 s warm, paid only when an analysis block or rate is new to the helper.
- **The first frame is made behind the console's launch screen** (maintainer, 2026-11-07): the
  audio-vue screen with "console" under it and a status line while the frame is made. Launch time is
  not optimised.
- **numba's cache must live outside the bundle.** The helper reads `NUMBA_CACHE_DIR`; the app sets it
  to a directory of its own under Application Support, or every launch pays the empty-cache cost.
- The console's first change is read-only: real scenes, the fonts block and the display size read from
  the host, real layers on the existing canvas, with the helper run from `../audio-vue/.venv`. Editing
  and Apply follow.
- Backdrop images are fetched from the host (`/v1/images/{image_id}` serves shipped and uploaded
  alike) into a directory the helper is given; the bundle carries none.
- Asks to audio-vue travel as handoff files in its root. The helper's protocol (`hello`, `prepare`,
  `render`, length-framed JSON with the layers' bytes after it, over the child's standard streams) gets
  a handoff of its own once built; `make render-bundle` writes `local/render-bundle/` for the console
  to mirror, with `manifest.json` and a `requirements.txt` at `uv.lock`'s versions.
- The host reports only `width_px`/`height_px`, and a display's EDID can lie: the maintainer's panel
  claims a 12.3-inch diagonal and is nearly 10 inches. A true-size view needs a diagonal the user enters
  in the Panel window, with a mm/inch choice. Not yet planned.
