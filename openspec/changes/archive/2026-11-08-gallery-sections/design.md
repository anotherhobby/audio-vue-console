# Design

## Context

See `proposal.md` for why. The state today, read on 2026-11-07:

- **The gallery.** `SceneGallery` (app target) builds an `Item` per scene with `fits`, computed from
  `ScenesPage.laidOut(_:facts:)`'s grid, or `facts.defaultGrid` where the scene cannot be laid out,
  matched to the panel's `DisplayShape`. It shows two sections, "For this panel, 8:3" and "Other
  shapes". `SceneRow` dims a scene that does not fit by `SceneMetrics.mismatchOpacity` and shows a
  lock on a built-in. The menu offers Duplicate for a scene that fits and a disabled Duplicate for
  This Panel otherwise. The split is not tested: it lives in a view.
- **The listing.** `ScenesPage` hands the gallery `store.drafts.listing(scenes.scenes)`: the host's
  scenes in its order, fixed ones left out (`PanelScenes.load()`), then the app's copies.
- **The panel's shape.** `ScenesPage.shape(of:)` reads `scenes.context.display`, which is the
  16:9 stand-in where the host gives no display size (maintainer's ruling, `working-notes.md`).
- **Read-only by shape.** `SceneEditorView.make()` sets `ReadOnlyReason.shape(scene:panel:)` for a
  scene of another shape. It stays.
- **scene-save.** Archived (2026-11-08, `df53b13`). It left `SceneGallery` with the two sections,
  the dimming, an unsaved dot, and Rename… and Delete… for any scene not built in. In
  `SceneEditorView`'s toolbar, Apply is `.disabled(editor == nil || isOtherShape)` with the help
  "This scene is shaped for another panel.", and Duplicate is disabled by the same `isOtherShape`.
- **The library.** `SchemaFacts.init?(schema:)` reads each `card.<name>` in `$defs` into a
  dictionary (`x-min-cells`, `x-placeable`), so the schema's order is lost; `placeable` sorts by
  name. `SceneEditorView` hands `placeable` to `CardLibrary`, which filters it by a search on
  `CardTile.title`, and also walks it to draw the library tiles (`drawTiles`, in that order).
- **card-categories.** audio-vue's change, archived 2026-11-08, adds `x-category` (the id) to each
  `card.<name>` and `x-categories` at the schema's root: `{id, label, cards}` in display order, the
  cards in the panel's order, as `card-order-handoff.md` asked (read from audio-vue's own
  `json_schema()`, task 1.1).

## Goals / Non-Goals

**Goals:**

- The split into sections is a pure function in `ConsoleCore`, tested there.
- A scene of another shape is shown and applied like any other, and still not edited.
- The library's grouping and order are read from the schema and tested in `ConsoleCore`; the app
  holds no list of categories or cards.

**Non-Goals:**

- Editing a scene of another shape, or making Duplicate for This Panel work.
- Collapsing categories, or showing a category's label anywhere but the library.
- Changing how the shape is matched (`DisplayShape.matches`, its tolerance) or the stand-in shape.

## Decisions

**D1. A `GallerySections` value in `ConsoleCore` splits the listing.** Given the listing, each
scene's grid and the panel's shape, it gives `mine` (the panel's shape, not built in), `builtIn`
(the panel's shape, built in) and `otherShapes` (every other scene), each in listing order. The
view only lays the three out. The grid is taken as the gallery takes it now: the laid-out scene's,
or the schema's default where the scene cannot be laid out. Alternative: keep
filtering in `SceneGallery`. Rejected, since the section rules are the change and a view cannot be
unit-tested.

**D2. Listing order is kept within each section.** Stored scenes in the host's order, then copies,
as `SceneDrafts.listing` gives them. Alternative: sort by name. Rejected: a new copy would jump away
from where the user made it.

**D3. Empty sections.** "My Scenes" with no scene says a built-in scene is duplicated to make one;
"Built-in Scenes" with none says no built-in scene has this panel's shape. Both are secondary text
under the heading. "Other Shapes" is left out when empty, since there is nothing to point the user
at. Alternative: hide every empty section. Rejected, since "My Scenes" empty is the first thing a
new user sees and should point at Duplicate.

**D4. The built-in lock and the unsaved dot stay.** The lock is in "Built-in Scenes" and in "Other
Shapes", where built-ins and stored scenes mix and the lock is the only mark that tells them apart.

**D5. Apply's only shape condition goes.** Apply's `isOtherShape` condition and its help go, so
Apply is enabled for every scene opened. The toolbar's Duplicate keeps `isOtherShape`.
A scene of another shape is read-only, so it is never unsaved and Apply only switches. Save,
Versions, Rename and Delete keep their rules as `scene-save` leaves them.

**D6. The `scene-apply` delta replaces the archived requirement whole.** It was written from
`scene-save`'s plan; `alignment.md` pass 4 checked it against `openspec/specs/scene-apply/spec.md`
as archived, which is the same text.

**D7. `SchemaFacts` gives the library grouped and in order.** It reads the root's `x-categories`,
a list of `{"id", "label", "cards"}` in display order, each `cards` naming the category's cards in
the panel's order (audio-vue `card-categories`, archived 2026-11-08). That list alone gives both the
grouping and the order, so each card's `x-category`, the same fact, is not read. A `library`
property gives the placeable cards as `(category, [Card])` pairs, leaving out a category with none;
`placeable` becomes that list flattened, so the tiles are drawn top to bottom as the library shows
them. Alternative: group in `CardLibrary`. Rejected for the same reason as D1: the rules are the
change, and a view is not unit-tested.

**D8. Plain headings, search across them.** Each category is a heading over its tiles in the one
scrolling list, as the gallery's sections are. A search filters cards by title, as now, and leaves
out a heading with no match. The app holds no category of its own and no fallback order: the
schema's categories and order are the only ones. Alternative: a disclosure group per category.
Rejected for now: nine short groups scroll fine, and collapse state would need keeping.

## Risks / Trade-offs

- [A scene of another shape applied to the panel fills only part of it, with backdrop either side]
  → That is what the panel does (audio-vue `scene-grid`), and the user chose it.
- [Where the host gives no display size, the gallery takes the 16:9 stand-in, so an 8:3 panel's own
  scenes are listed under "Other Shapes"] → They stay visible and can be applied. The editor already
  says when the display size is not known (`SceneRendering+Messages`).
- [`card-categories` changes every card's `manifest.py`, and any difference in shared code between
  the render bundle and the panel draws no card] → Before the run in the app, audio-vue is deployed
  to the panel and the bundle refreshed (`tools/refresh-render-bundle.sh`, `commands.md`).
