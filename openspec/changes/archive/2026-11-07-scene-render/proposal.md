# Proposal

## Why

The console renders scenes itself, from audio-vue's own card code (`product.md`, "The decision",
2026-11-06 and 2026-11-07), and audio-vue has now built the render helper that does it: a child
process that draws a scene as layers, the panel's render within two 8-bit steps. The Scenes page still
shows sample scenes as coloured boxes. This change bundles that helper into the app, puts the panel's
real scenes on the canvas drawn by it, and checks that the code drawing them is the code the panel
runs.

## What Changes

- **The host's newer contract is saved.** The version read now gives the digest of the code the
  panel draws with, and a new read gives that code's manifest. The app also starts calling the
  routes for scenes, the install's settings, the settings schema and backdrop images, all already in
  the contract.
- **The app carries the helper and a Python to run it.** A tool mirrors the render bundle audio-vue's
  `make render-bundle` writes into this repository, never edited by hand, and builds a relocatable
  interpreter with the bundle's pinned libraries outside version control. Every build, release
  included, copies both into the app. The app runs nothing from outside itself and its container.
- **The helper starts once the app is paired.** With the host's installed rate read, the app starts
  the helper, keeps its compiled-code cache in its container, reads its error output, and makes the
  first run at that rate. A Renderer row under the Panel page's Status says it is starting, with a
  spinning indicator, then that it is ready, or why it could not start.
- **The Scenes page shows the panel's scenes.** It lists the connected host's scenes, leaving out
  the fixed calibration scene, with this panel's shape first and thumbnails drawn by the helper.
- **The canvas draws real layers.** Opening a scene draws its backdrop and each plate as the panel
  would, at the panel's pixel size, scaled to the view. A move slides the plates and draws them again
  once released. A resize draws the plate again at each cell step. The grid, outlines and handles are
  unchanged. A card that cannot show its reading at its size is named.
- **A resize stops at the card's minimum.** The smallest a card can be made is the minimum the host's
  schema declares for it, in place of one cell.
- **The card code is checked.** The helper's digest is compared with the host's on connect. On a
  difference the app reads the host's manifest, compares it with the bundled one, and names what
  differs. A card whose own code differs is drawn as a plain box with its name; a difference in shared
  code draws every card that way.
- **Duplicate makes an unsaved copy.** Built-in scenes stay read-only. Duplicate makes an editable
  copy in the app, kept until quit like every other edit. Nothing is written to the host.
- **The library lists the host's cards.** It lists the cards the host's schema marks placeable, each
  dropped at its declared minimum size.
- The sample scenes and their types leave the Scenes page; the other sample pages are unchanged.

## Capabilities

### New Capabilities

- `render-runtime`: What the app carries to draw scenes, the mirrored render bundle and an
  interpreter with its libraries, how each is refreshed from audio-vue, and the check that the bundle
  is whole.
- `render-helper`: How the app runs the helper it carries: when it starts, its cache, its error
  output, its requests answered in order, and starting it again after it ends.
- `scene-rendering`: What the canvas and the gallery draw from the helper's layers, what each
  request carries from the host, and which edits draw what again.
- `card-code`: How the app checks that the code it draws with is the panel's, and how it draws a card
  or a scene when it is not.
- `scene-gallery`: The Scenes page's list of the connected panel's scenes, their order and thumbnails,
  and Duplicate.

### Modified Capabilities

- `scene-layout`: A resize stops at the card's declared minimum, not at one cell.
- `scene-canvas`: The library lists the host's placeable cards and drops each at its declared minimum
  size, in place of sizes taken from sample scenes.
- `panel-window`: The Scenes page is no longer a sample page; the other pages but Panel still are.
  Status gains a Renderer row.

## Impact

- **Code:** `ConsoleCore` gains the helper's client, the scene documents and their layouts, the
  rendering model and the card-code check; `HostClient` gains the scene, install, schema, image and
  manifest reads; `SceneLayout` takes each card's minimum. The app target gains the Renderer row and
  the layered canvas, and the Scenes page leaves `Sketches/` for real views. `SketchScene`,
  `SketchCardKind` and the sample scenes go.
- **Build:** a build phase copies the mirrored bundle and the interpreter into the app's resources,
  about 350 MB. Builds need the interpreter built first, by the tool.
- **Tooling:** `tools/refresh-render-bundle.sh`, beside `tools/refresh-contract.sh`, with a check
  mode; it uses `uv` to fetch the interpreter and install the pinned libraries.
- **Referenced specs:** `audio-vue:scene-render` (the helper, its protocol, its layers, its frames),
  `audio-vue:render-bundle` (the bundle, the manifest, its digest, the panel stating it),
  `audio-vue:control-api` (the version read, the manifest read, scenes, install, schema and images),
  `audio-vue:scene-grid` (the grid's defaults and an unset span), `audio-vue:card-layout` (each card's
  declared minimum, and the console stopping a resize there).
