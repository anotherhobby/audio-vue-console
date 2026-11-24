# Design

## Context

See proposal.md, "Why". The state today:

- **The schema** is read once per host by `PanelScenes`, from `/v1/schema`, into `SchemaFacts`.
  `SchemaFacts` keeps settings, blocks and colours, but not the raw `$defs`.
- **A draft** (`Draft`) is a parse (`LaidOutScene`) plus the editor's content (`SceneContent`).
  `SceneContent` holds the blocks, which are every root key but `cards` and `name`, and the cards'
  cells, groups and settings. Each card's other fields stay in `LaidOutScene.entries` and are
  written back untouched: `plate`, `alternate` and any key the app does not model. The editor's
  undo history covers `SceneContent` alone.
- **Loading an earlier version** (`SceneDrafts.load`, `SceneSession.load`) makes a new parse. The
  editor starts afresh (`newParse()`), and the draft is unsaved because `source != rev`.
- **The grid size** is dropped from a stored scene's content as it is read
  (`LaidOutScene.dropGridSize`). `Draft.isUnsaved` counts `laidOut.declaresGridSize`, so such a
  scene opens unsaved. This change folds that case into the repair.
- **The helper** refuses a scene the panel would refuse, with the panel's failures. The canvas draws
  plain boxes and shows "The panel would refuse this scene: …"
  (`SceneRendering+Messages.swift`).
- **The export's keywords**, counted on 2026-11-23:
  - in use: `type`, `enum`, `const`, `pattern`, `minLength`, `minimum`, `maximum`, `properties`,
    `additionalProperties`, `required`, `$ref`, `anyOf`, `allOf` with `if`/`then`, `items`,
    `minItems`, `maxItems` and `uniqueItems`;
  - closed with `additionalProperties: false`: every object the scene, a placement, an alternate, a
    block and a card declare.

## Goals / Non-Goals

**Goals:**
- A pure function in `ConsoleCore` from a scene document and the schema to a repair: the repaired
  document and the list of changes.
- Applying it reuses the version-load path, so the editor, rendering and saving need nothing new.

**Non-Goals:**
- Judging what validation checks beyond the export's shape. That covers the grid's reach, images,
  style sources and a keyed table's `x-rules`.
- Repairing styles.
- Writing anything without the user choosing Repair.

## Decisions

### D1. The repair walks the document against the exported JSON Schema

`SceneShape`, a new `ConsoleCore` type, is built from the `/v1/schema` body next to `SchemaFacts`, and
`SchemaFacts` holds it as `shape`. `SceneShape.repair(of: JSONValue) -> SceneRepair?` answers nil
where the document passes. It starts at `$defs/scene` and resolves `$ref`. It picks a card's
settings definition through `allOf`'s `if`/`then` on the entry's `card` `const`.

Alternatives considered:
- **Parse the host's or the helper's failures.** These are prose, such as "unknown key 'rta_hold_s';
  have (…)". They break on rewording and name no fix.
- **`/v1/scenes/validate`.** It answers failures, not fixes, and needs a round trip per scene.
- **Ask audio-vue for a repair route.** That is a host change, and the host would then rewrite a
  user's documents. The schema already carries what a repair needs.

### D2. The rules, by keyword

- **A closed object** loses every key outside `properties`.
- **Numbers:** a number past `minimum` or `maximum` is set to that bound. An `integer` bound stays
  an integer.
- **A value that does not fit:** a value failing `type`, `enum`, `const`, `pattern` or `minLength`
  is removed. Where every `anyOf` branch fails, the value is removed.
- **Arrays:** each item of an array is repaired on its own, and an item that cannot be made whole is
  removed. A repeat under `uniqueItems` is removed, as are items past `maxItems`. Where fewer than
  `minItems` remain, the array itself is removed.
- **Required keys:** an object that would lose a key in `required` cannot be made whole. Its parent
  removes it, whether it is an array item or an optional key. At the root, or for `cards`
  (`minItems: 1`), it cannot be removed, so there is no repair and the scene is said to hold no
  card the host has.
- **Unknown keywords:** a keyword the walker does not know judges nothing. Whatever it would refuse
  stays with the helper's refusal.
- **Annotations** judge nothing by design: `default`, `$schema`, and every `x-` key.

Unsetting, not writing the default, follows `x-inherits` and the host's later defaults. A step is
never a constraint (audio-vue `settings-schema`), so nothing is rounded.

### D3. A change says where it is and what becomes of it

`SceneRepair` holds `doc`, the repaired document, and `changes: [RepairChange]`. Each change has a
place and an outcome.

- **The place** is a block by the name the inspector gives it (Analysis, Grid), or a card by its
  canvas label and its number in the scene's order, then the key.
- **The outcome** is one of `removed`, `clamped(from:to:)`, `unset(was:)` and `removedCard(kind:index:)`.

The canvas words each change, for example "Analysis: rta_hold_s removed" or "RTA bars (card 3):
hold_s 20 → 10".

### D4. What is checked is what a save would write

A draft is checked as `Draft.doc`, and a scene with no draft as the host's document. Built-ins are
never checked. `SceneDrafts.repair(of:shape:)` answers the shape's repair on demand. The drafts
know each scene's draft, and the caller passes the shape: `SceneWrites.repair(of:)` for the
session, and the app's `SceneStore` for the gallery. Both hold the panel's scenes and the drafts.

The repair is not stored on `Draft`. Doing so would mean passing the schema to each of the seven
places a `Draft` is made. Task 4.1 measured a full walk over the proving host's 5 scenes at 5 ms
in debug and 2 ms in release, over the millisecond allowed. So `SceneDrafts` holds each scene's last
repair with the document it checked and the shape's identity, and walks again only when either
changes. Keying by scene id and revision instead would go stale when an edit removes an unknown
card from a draft. Held, a gallery pass takes about 2 µs.

### D5. Repair is a new parse, as loading a version is

`SceneDrafts.repair(_ id:, with:)` lays the repaired document out on the draft's panel. Surviving
cards keep their ids by position, since `removedCard` carries the card's index and a removed card's
id is dropped, so selection and plates carry over. It keeps `rev`, and sets a new `Draft.repaired`
flag that `isUnsaved` counts. `relaid` carries the flag across a change of panel, as it carries
`source`. `SceneSession.repair()` takes the repair from `SceneWrites`, calls this, then
`newParse()`.

Undo cannot reach across a parse, so the repair starts the undo history afresh. Revert to Saved
reads the host's document again, and the scene again needs a repair.

Alternative: one undoable content edit. A repair can change `plate`, `alternate` and unknown entry
keys, which live in `LaidOutScene.entries`, outside `SceneContent`. Bringing them under undo means
moving each card's whole entry into `SceneContent`, a larger change than the repair itself. This
departs from "a single undoable edit" as first proposed (alignment, Q1).

### D6. The grid size is one more undeclared key

`LaidOutScene.dropGridSize` and `declaresGridSize` are removed, and `LaidOutScene.content` keeps the
blocks as read. `Draft.isUnsaved` counts `repaired` in place of `declaresGridSize`. A scene stored
with `cols` and `rows` now needs a repair, like any other, and its plates are not drawn until it is
repaired, since the helper refuses it.

### D7. Saving is not blocked

Save and Apply on a scene that needs a repair stay as they are. The host refuses the write and the
app shows each failure (`scene-saving`). Blocking would duplicate the host's refusal for a case the
canvas already explains.

Rename writes the host's current document with a new name (`PanelScenes`, rename), so it too is
refused while the host's document needs a repair, even after Repair and before Save. Until now,
rename dropped the grid size to get past this one case. A rename then needs a Save first
(alignment, Q2).

### D8. Where the repair is offered

- **Canvas:** the editor shows a banner over the library and the canvas, like `EditorBanner`. It
  reads "This scene holds N settings the panel no longer takes", with Repair, and Show Changes
  opens a popover listing every change.
- **No repair possible:** the banner says the scene holds no card the host has, with no button.
- **Read-only scene:** the banner shows no button.
- **Gallery:** the gallery's card carries a note beside the too-wide note.

## Risks / Trade-offs

- **The walker can miss a check.** A keyword added to the export could refuse something the walker
  never removes. → It judges nothing it does not know, the helper's refusal still names the fault,
  and a test asserts the walker knows every keyword the fixture uses.
- **A moved setting's value is lost.** For example, Primary's analysis hold of 1 s becomes each RTA
  card's default of 2 s. → The change list names every removed key, so the user can set the card's
  own setting by hand after repairing.
- **Opening a stored scene with a grid size now shows plain boxes until it is repaired,** where it
  was drawn before. → The banner offers Repair at once, and one click restores the drawing.
