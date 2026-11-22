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

- The grid comes from the connected panel's state (`PanelState.grid`, held by `SceneStore.grid`);
  with none there is no editing. 96x36 at 8:3 is only the maintainer's display; most users are
  expected to be 16:9.
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
scene of another shape, and the canvas refused edits by shape. All of that went with `host-grid`
(2026-11-21): two sections, and a scene too wide for the panel is edited and saved, not applied. Ruled 2026-11-08: the editor's card library is grouped by
audio-vue's card categories (its change `card-categories`), the categories and the card order both
from the panel. The handoff `card-order-handoff.md` was answered and `card-categories` archived
(2026-11-08): the schema's root `x-categories` lists `{id, label, cards}` in display order, the
cards in the panel's order. Built 2026-11-08; `LiveGalleryTests` passed against the panel
(Favorite under My Scenes, RTA built in, Default and both card checks under Other Shapes; every
category but Calibration in the library). The maintainer's run passed every item (2026-11-08); a rule
now divides the library's categories, at the maintainer's ask.

## Card, scene and style settings (planned 2026-11-08)

Three changes, built in this order (maintainer, 2026-11-08):

1. `card-settings` (planned, valid): the inspector reads and sets the selected cards' settings from
   `/v1/schema`. The per-setting button is Use Default, which removes the key; never call it Reset,
   which is the panel's measurement reset. Cards selected together edit the settings they declare
   alike, then each card has a collapsed section of its own. A card's own chain setting carries no
   calibration warning. Colours use the system colour panel, stored as sRGB `#RRGGBB`. The
   information page comes later.
   Built 2026-11-09; the maintainer ran task 5.1 on the proving host with no issue found, and it
   was archived as `openspec/changes/archive/2026-11-09-card-settings` (its spec `card-settings`;
   `scene-canvas` and `scene-rendering` updated). A card the app had not seen (`loudness_scope`'s
   band colours, added to audio-vue that day) showed its settings with no app change. An unset
   card colour showed a black swatch; audio-vue's `card-colours` (archived 2026-11-09) made it
   resolvable by lookup (`host-contract.md`, Colours), and `scene-settings` now shows the colour and
   its element (maintainer, 2026-11-09).
2. `scene-settings` (built 2026-11-09; rebuilt 2026-11-19 on audio-vue's `scene-styles`, tasks
   6.1 to 6.5; task 5.1, the maintainer's run on the proving host, is next, then verify and
   archive): the scene's blocks in the inspector when nothing is selected, in the tabs Scene
   (Backdrop, Glass, Grid, Display), Style (Typeface, Colours, Text Sizes) and Analysis
   (maintainer, 2026-11-19); rows compact for card and scene settings alike, help on hover, Use
   Default a small button; the backdrop as one source (Default, Colour, Gradient, Image) with
   gradient stops and image upload, a source chosen again coming back as it was; grid gap and
   density at the scene's aspect; a calibration warning only where no calibration holds at the
   scene's rate. Since the rebuild: colours by role group and meaning scale, a size per text role,
   the typeface, a card's colour as a well beside a menu of the scene's roles with its colours
   under one disclosure, and a render request carrying `viewing` and `styles`
   (`host-contract.md`, Colours, Type and typeface, Styles). The app cannot reach the proving
   host until it is paired again: the host's store was rebuilt, so install blocks, images and
   stored scenes are entered again.
   The maintainer's review of 2026-11-20 is built as tasks 7.1 to 7.5: no Kept row, Glass titled
   Cards, the typeface at the head of Text, a slider for a number from 0 to 1, Use Default
   Gradient (the built-in `default` style's stops and angle), an unset display setting showing the
   panel's value, and New Scene (an empty unsaved scene on a grid of the panel's shape, the app's
   alone until it holds a card: Save and Apply disabled, its backdrop asked for by `LibraryTiles`
   around one library card, tasks 7.6 and 7.7; tiles sit on the scene's backdrop). audio-vue
   answered the round's hand-off the same day with its `scene-editor-settings` (`x-inherits`,
   steps, opacity 0.6, a scene's screensaver, the silence reset in analysis); the app follows it
   in task 7.8, and the answering hand-off is deleted.
   Drawing ahead (tasks 8.1, 8.2, same day): the window reads the scenes once paired and
   `SceneStore.drawAhead` draws thumbnails then each scene's library tiles; `LibraryTiles` keeps
   a set per settings key. Thumbnails are kept on disk (`ThumbnailCache`, task 8.3) since the
   helper's first drawing after a start takes 2 to 3 s.
   The scope-preview hand-off (2026-11-20: the loudness scope's preview shows a full lap and all
   four bands; the panel keeps its trace across a look-only reload) was answered by audio-vue's
   `loudness-scope-target` on 2026-11-21. The app needed only a render-bundle refresh: the
   scope's new settings (preset, target, speed, resolution and so on) are choices with labels
   and an `x-unused-when`, which the card inspector already reads. Both hand-off files are gone.
   `host-grid` (2026-11-21), the console's change following audio-vue's of the same name, is
   built, and the maintainer's run on the proving panel passed with `scene-settings`' (2026-11-21,
   everything as expected): the grid is
   the panel's, from the state (`SceneStore.follow(grid:)`); `LaidOutScene(_:panel:)` lays a
   scene out on it, or on its reach where a card ends past the last column, which makes it too
   wide: listed with a note, edited and saved, drawn as boxes, not applied. An unset span is
   written back unset while its card covers the grid from column 0. Grid density, display
   shapes and scaled minimums are gone. Ruled by the maintainer the same day; both hand-off files
   are deleted. Both changes are archived (2026-11-21: `scene-settings`, then `host-grid`), and
   the standing specs pass `--strict`. A stored scene that still sets `cols` or `rows` is refused by the host; the app
   opens it without them, marked unsaved, so Save removes them (maintainer, 2026-11-21).
3. `styles` (proposal only, rewritten 2026-11-19 on what audio-vue built): each look category in
   the scene inspector says where it comes from (This Scene, a style, Default); a style is edited
   from a scene, where it is seen, with no Styles sidebar section (maintainer, 2026-11-19); Save as
   New Style, Rename, Delete; the viewing asked at setup. Three questions are open in its proposal
   (one undo history or two; when other scenes redraw; where the viewing is asked). Specs, design
   and tasks wait on those.

4. `input-channels` (built and archived 2026-11-20 as
   `openspec/changes/archive/2026-11-20-input-channels`; `capture-input` updated; the maintainer
   ran it on the proving host with no issue found): the Capture page reads what each capture
   device streams, offers only the formats and rates the installed device takes and Left and Right
   Channel over more than two channels, fits a chosen input to its device before asking about the
   restart, and shows the host's sentences for a refused input and the panel's while it waits on a
   capture it cannot open (`host-contract.md`, Capture devices; `pitfalls.md`).

audio-vue asks, placed in its root 2026-11-08: `card-settings-handoff.md` was answered by
audio-vue's `schema-step-and-order` (`x-step` on every setting, `x-settings` on every card, block
and install definition; the chain wording in "A scene sets no measured value" now accepts a card's
channel choice), and the file is gone; the live panel's export matched on 2026-11-09.
`scene-settings-handoff.md` was answered by `GET /v1/calibration` (see input-and-rates below).
`meter-colours-handoff.md` (placed 2026-11-09 for `scene-settings` task 4.5) was answered the same
day by audio-vue's `unused-settings` (`x-unused-when`, `host-contract.md`), built in task 4.5.
`styles-handoff.md` was answered by audio-vue's `scene-styles` (deployed 2026-11-19), whose
`scene-styles-handoff.md` sits at this repo's top level until `styles` is planned from it; then
delete it and tell the maintainer. audio-vue's open `loudness-scope` change renames
`loudness_radar` to `loudness_scope` (a trademark), with nothing touching these asks. `narrowband` is a calibration card,
not placeable.

## Input and calibration across rates (archived 2026-11-09)

Archived as `openspec/changes/archive/2026-11-09-input-and-rates`; its specs are now `capture-input`
and `calibration-pass`, with `calibration-run`, `calibration-history` and `panel-window` updated. Ruled (maintainer, 2026-11-08):
- There is no Input page. The Calibration page is renamed Capture and gains an Input section that
  sets `install.input.device` and `rate`, and Input leaves the sidebar.
- The runs section is renamed Calibration History, and each run shows its rate (an audio-vue ask:
  `/v1/runs` gives none).
- Calibrate… gains "at every rate", calibration only, lowest rate first.
- The rate list comes from the host's schema, not the app.
- A failed or expired rate does not stop the pass; only Cancel does.
- The Mac's output is left at the last rate, unless Synchronize Rates is on (`mac-output`, 2026-11-09).
An arm stating `file_rate` captures at that rate and arms back to back during the hold, so a pass
writes no install settings. Its handoff, `../audio-vue/input-and-rates-handoff.md`, was placed
2026-11-08, awaiting a reply. It asks for: `input.rate`'s rates declared in the schema; `rate` on
`/v1/runs`; the install write's 409 refusal declared in the contract; and other-rate report
wording.
Built 2026-11-08. audio-vue answered both handoffs the same day (its `input-and-rates`, deployed to
the proving host): the rates as an integer `enum`, `rate` on each run, the
install 409 as `Stale | Refusal`, and `GET /v1/calibration`, which also answers
`scene-settings-handoff.md`. Read live 2026-11-08: the panel is installed at 96 kHz on
`hw:CARD=m2x4HD,DEV=0`, calibrated at 96 kHz only. The maintainer ran a pass of every rate (2026-11-09): five runs
completed, each with its report and rate, starting 27-28 s apart (render, settle, arm, play; about
2.5 min for five, as the maintainer expected). Afterwards `/v1/calibration` listed all five rates
calibrated for the m2x4HD, and once the hold ended the panel captured at its installed 96 kHz. Ruled the same day: after a run the Input section words
the panel's hold (the last run's rate until audio returns) and offers Return to Scene, the panel's
cancel, which keeps the record (task 4.6, design D11). Rate changes from the Input section work on the panel (2026-11-09).

## This Mac's output on the Capture page (archived 2026-11-09)

Archived as `openspec/changes/archive/2026-11-09-mac-output`. Its spec is now `mac-output`, with
`capture-input`, `calibration-run` and `calibration-player` updated. The maintainer ran it on the
proving host: a pass of every rate, and a calibration taking the D10s from 24 to 32-bit with
`cal-play` 0.2.0. Ruled (maintainer, 2026-11-09):
- The Input section shows Capture Device, Rate and Format (audio-vue), Output Device, Rate and
  Format (this Mac), and Synchronize Rates.
- The capture rate leads, and a change made elsewhere is shown as a mismatch, never followed.
- Bit depth is shown and flagged below 24 bits, never synchronized.
- The output is chosen in the Input section, not Calibrate….
- A synchronized output returns to the capture rate after a pass.
Its handoff, `../audio-vue/mac-output-handoff.md`, was answered 2026-11-09 by
`mac-output-reply-handoff.md` at this repo's root (delete once read): `cal-play` 0.2.0 sets the
deepest integer format and settles on either change, and `settings-schema` states that choices
export as an `enum`.

## Card minimums and the readout's picker (archived 2026-11-21)

- The console reads card minimums (`x-min-cells`), sizing and aspect (`x-sizing`, `x-aspect`) and picker
  labels (`x-choice-labels`) from the schema; no minimum is a literal in production code.
- Not yet verified: the readout and meter at 8 × 4 under default type show TOO SMALL on the canvas. Tiles
  now draw at the size that fits the scene's fonts, so the library no longer shows the notice.
- The spec examples (`scene-layout`, `scene-canvas`) still use 17 and 17 × 10 as illustrations. Raised
  with the maintainer; left unchanged.
- The archived change is `openspec/changes/archive/2026-11-21-tile-fitting-size`.
