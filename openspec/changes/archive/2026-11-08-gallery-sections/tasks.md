# Tasks

`scene-save` is archived (2026-11-08, `df53b13`); groups 2 to 4 build on the code it left, read in
`alignment.md` pass 4. Groups 1 and 5 wait on audio-vue's `card-categories` being archived with an
answer to `../audio-vue/card-order-handoff.md`; groups 2 to 4 can be built first.

## 1. Read the categories as audio-vue built them

- [x] 1.1 Once `card-categories` is archived in audio-vue, read its spec in full
  (`openspec show card-categories --type spec --store audio-vue`) and a real export
  (`GET /v1/schema` from the proving host, after audio-vue is deployed to it): the keyword on each
  card, the root list of categories with labels, and where the card order within a category is
  given, as the handoff was answered. Bring this change's `scene-canvas` delta (its Source line),
  design D7 and task 5.1 up to that shape. Delete `../audio-vue/card-order-handoff.md` if audio-vue
  has not, and record the answer in `working-notes.md`. Verify with
  `openspec validate gallery-sections --strict` and that design D7 names the archived keywords.

## 2. Split the listing in the core

- [x] 2.1 Add `GallerySections` in `ConsoleCore/Sources/ConsoleCore/GallerySections.swift`
  (design D1, D2): from the listing's `SceneDocument`s, each with its grid (from
  `ScenesPage.laidOut`, or the schema's default where it has none, as `SceneGallery.rows` takes it
  now), and the panel's `DisplayShape`, `mine`, `builtIn` and `otherShapes`, each in listing order.
  Verify with `GallerySectionsTests` (`cd ConsoleCore && xcrun swift test --filter
  GallerySectionsTests`): the spec's 8:3 scenario ("My RTA" mine, RTA built in, Default and "Wide"
  in other shapes); a copy lands in `mine` after the stored scenes; a scene that cannot be laid out
  is placed by the default grid; a 16:9 panel puts Default in `builtIn`, "Wide" in `mine`, and RTA
  and "My RTA" in `otherShapes`.

## 3. Show the three sections

- [x] 3.1 In `AudioVueConsole/Scenes/SceneGallery.swift`, build the rows from `GallerySections` and
  replace the two `section(...)` calls in `sections` with "My Scenes", "Built-in Scenes" and "Other
  Shapes", the first two with their empty text and the third left out when empty (design D3). Drop
  `.opacity(item.fits ? ...)` in `SceneRow` and remove `SceneMetrics.mismatchOpacity`
  (`AudioVueConsole/Scenes/SceneMetrics.swift`). Keep the lock and the unsaved dot (D4), and the
  menu as it is: Duplicate for a scene of the panel's shape, the disabled Duplicate for This Panel
  otherwise, Rename… and Delete… for any scene not built in; `Item.fits` may stay for that. Update
  the doc comments of `SceneGallery`, its `sections`, and `ScenesPage` ("this panel's shape
  first"). Give `GalleryPreview` a stored scene of each shape alongside the two built-ins, and add a
  `#Preview` with only built-ins of the panel's shape, for the empty "My Scenes" and no "Other
  Shapes". Verify the app target builds (`mcp__xcode__BuildProject`), `SceneGallery.swift` stays
  within the gate's 400-line file and 300-line type limits, and both previews render
  (`mcp__xcode__RenderPreview`): the 8:3 one shows one scene in each of the first two sections and
  two in "Other Shapes", none dimmed.

## 4. Apply on another shape

- [x] 4.1 In `AudioVueConsole/Scenes/SceneEditorView.swift`'s toolbar, change Apply's
  `.disabled(editor == nil || isOtherShape)` to `.disabled(editor == nil)` and remove its
  `.help("This scene is shaped for another panel.")` (design D5). Keep `isOtherShape` for the
  toolbar's Duplicate, and change its doc comment from "neither duplicated nor applied here" to
  "not duplicated here". Leave `ReadOnlyReason.shape`, and Save's, Versions', Rename's and Delete's
  rules, as they are. Verify the app target builds, `cd ConsoleCore && xcrun swift test` passes, and
  a search of `AudioVueConsole` for "shaped for another panel" finds nothing.

## 5. Group the card library

- [x] 5.1 In `ConsoleCore/Sources/ConsoleCore/SchemaFacts.swift` (design D7), read the root's
  `x-categories` in order, each with its id, label and `cards` in the schema's order; add `library`, the placeable cards grouped by category in that order with an
  empty category left out, and make `placeable` that list flattened. Update
  `ConsoleCore/Tests/ConsoleCoreTests/Fixtures/schema-trimmed.json` from the real export's keywords
  (its cards in two categories, one category holding only a card not placeable) and the doc
  comment. Verify with `SchemaFactsTests` (`cd ConsoleCore && xcrun swift test --filter
  SchemaFactsTests`): the categories and labels in the schema's order; the cards within one in the
  schema's order, not by name; a category with no placeable card left out of `library`; `placeable`
  in library order.
- [x] 5.2 In `AudioVueConsole/Scenes/CardLibrary.swift` (design D8), take `library` and show each
  category's label as a heading over its tiles, the search filtering by `CardTile.title` as now and
  leaving out a heading with no match. Keep each `CardTile`'s own `.id("\(card.name) \(store.drops)")`
  so ids stay unique across the headings (`pitfalls.md`, "A refused drop leaves its library tile
  undraggable"). Hand it `scenes.facts?.library` from `SceneEditorView`; leave `drawTiles` on
  `placeable`. Update the type's doc comment and the "Card library" `#Preview` to two categories.
  Verify the app target builds, the preview renders with both headings and every card, and a
  preview with the search set shows only matching headings.

## 6. Check in the app

- [x] 6.1 Deploy audio-vue with `card-categories` to the panel and refresh the render bundle
  (`tools/refresh-render-bundle.sh`, `commands.md`), so the card code matches and cards are drawn.
  Run the app against the proving host (the `run` skill): the Scenes page shows "My Scenes"
  with the stored 8:3 scenes, "Built-in Scenes" with RTA, and "Other Shapes" with Default, "Card
  check jpg" and "Card check png", none dimmed. Duplicate RTA and see "RTA copy" under "My Scenes".
  Open Default, see the canvas refuse a drop, then Apply it and see the panel show it with backdrop
  either side. In the editor, see the library grouped under the panel's category labels in its
  order, with no "Calibration" heading, every tile drawn, and a search hiding headings with no
  match. Drag a card after a refused drop to check the tiles still drag. Send the maintainer
  screenshots of the gallery and the library.
- [x] 6.2 In `.claude/kb/agent/project-map.md`, change `SceneGallery`'s note "(this panel's shape
  first, thumbnails or boxes, Duplicate)" to the three sections, name `GallerySections` in
  `ConsoleCore`, and change `CardLibrary`'s "(the schema's placeable cards)" to say it groups them by
  the schema's categories. In `host-contract.md`'s Settings section, add the category keywords as
  audio-vue built them. In `working-notes.md`, replace the gallery-sections note with a dated line:
  three sections, none dimmed, Apply on another shape (maintainer, 2026-11-07), and the library
  grouped by the panel's categories and order (maintainer, 2026-11-08). `product.md` is not
  changed. Verify each changed entry is dated and names its files.

## Workflow follow-up

- Verify the change against its specs (`openspec-verify-change`), then archive it after the
  maintainer's run.
