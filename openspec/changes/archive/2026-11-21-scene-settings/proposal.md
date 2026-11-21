# Proposal

## Why

`card-settings` lets the editor set a card's own settings, but a scene's look and behaviour live in
its own keys: the backdrop behind the plates, the plates' glass, the grid, when the display sleeps,
the typeface, the colour of each thing cards draw, the size of each kind of text, and the analysis
the cards read. The product promises every scene setting through the app (`product.md`, "The
decision"). All of them are declared in the host's schema, and the routes to store a scene, upload
an image and read the calibrated rates already exist.

audio-vue's `scene-styles` (deployed 2026-11-19) reworked the colour and type models this change
first read: one layer of roles and two meaning scales in place of a palette and elements, a size
per text role in place of four named sizes, a typeface, card colours that take a role or a colour,
and a render request carrying the viewing and styles. The app follows it here, since nothing it
drew or stored before still stands (maintainer, 2026-11-19).

## What Changes

- **The inspector shows the scene's settings when no card is selected** (maintainer, 2026-11-08),
  below the scene's name and kind, in tabs (maintainer, 2026-11-09, 2026-11-19): Scene (Backdrop,
  Glass, Grid, Display), Style (Typeface, Colours, Text Sizes) and Analysis, then Other for any
  block or setting the schema declares that the app does not know, by its name. Rows are compact,
  card settings' too: help on hover, Use Default as a small button. Within a block, settings come
  in the order audio-vue declares them (`x-settings`). Each setting is generated from the schema
  with the controls, defaults, Use Default, undo, standard flags and read-only rules
  `card-settings` defines.
- **The backdrop is one source**: the default, a colour, a gradient or an image, chosen by a
  segmented control, since the host refuses a backdrop with none or more than one (audio-vue
  `scene-backdrop`). A gradient edits its stops (add, remove, reorder, each through the system
  colour panel) and its angle. An image is picked from the host's images or uploaded from a file
  (PNG or JPEG). Blur applies to any source. Default removes the backdrop, so the scene draws the
  default one.
- **The scene's colours**, one per role under its group (Background, Text, Lines, Signal), then the
  steps of each meaning scale (Warnings, Stereo phase), are edited through the system colour panel,
  each with Use Default; the shadow is an amount.
- **A size for each kind of text**, a number in reference pixels within the role's own bounds, and
  **the typeface**, a choice shown by each face's name.
- **A card's colour takes one of the scene's colours or its own** (audio-vue `card-colours`): a
  colour well beside a menu of the scene's roles, each in this scene's colour. Unset, it shows the
  scene's colour for the role it draws, or a colour of the card's own at its default, and says
  which role. A card's colours are listed together, closed until opened. An unset shadow shows the
  scene's.
- **A card setting with no effect is greyed out, saying why** (maintainer, 2026-11-09): the meter's
  bar colours on a field coloured by its thresholds. audio-vue declares when, so the console
  copies no list.
- **Analysis settings carry their class.** A measurement setting off its standard is flagged.
- **The scene says when no calibration holds at its rate** (maintainer, 2026-11-08). A scene may
  capture at any rate the host is calibrated at, as audio-vue applies the newest valid record for
  the device and rate in use. The Analysis section warns only where none holds at the scene's rate,
  its capture rate or the installed one, from the host's calibrated rates (`GET /v1/calibration`).
- **The grid's gap** (maintainer, 2026-11-08) is a setting like any other. The grid's density, first
  planned here, left this change on 2026-11-21: the grid becomes the panel's (`host-grid`).
- **Every redraw follows.** A backdrop change draws the backdrop again; any other scene setting draws
  every plate, the library's tiles and the scene's thumbnail again.
- **A render request carries the host's viewing and the styles a scene names**, in place of its
  fonts and a fallback backdrop (audio-vue `scene-render`).
- **The maintainer's review of 2026-11-20.** No row says where the scene is kept; Glass is titled
  Cards; the typeface heads the text sizes; a number from 0 to 1 is a slider; a gradient returns
  to the default backdrop's stops; an unset display setting shows the panel's own value, since a
  scene's display block overrides the install's; and New Scene makes a scene with no cards.
- **Scenes and tiles are drawn ahead** (maintainer, 2026-11-20): the window reads the scenes
  once paired and draws every thumbnail, then each scene's library tiles, before the Scenes page
  is shown; tiles are kept per scene's settings.
- **Scene settings are scene edits**: kept in the open scene, marked unsaved, undone and redone in
  the same history as layout edits, and stored by Save or Apply, as `card-settings` does for cards.

Out of scope: styles themselves (the `styles` change: listing, linking, creating and editing them,
and reading the stored styles a scene names), asking for the host's viewing at setup, and a grid of
another aspect.

## Capabilities

### New Capabilities

- `scene-settings`: the inspector's view of the open scene's own settings: its blocks and its
  typeface generated from the host's schema, the backdrop's one source with its gradient and image,
  and the colours by group.

### Modified Capabilities

- `scene-canvas`: "Edits are kept until saved or discarded" keeps the scene settings the user
  changed, as well as the cards' settings.
- `card-settings`: "A setting shows the scene's value or the card's default" shows an unset colour
  as the scene resolves it; "Use Default removes a setting from the scene" says so for a colour;
  "Selected cards are edited together where they share a setting" also matches the role; "The
  inspector shows the selected card's settings" lists the colours last; and "A setting with no
  effect says why", "A card's colour takes one of the scene's colours or its own" and "A card's
  colours are listed together" are added.
- `scene-gallery`: "New Scene makes an unsaved scene with no cards" is added.
- `scene-rendering`: "An edit draws again only what it changed" draws the backdrop again on a
  backdrop change and every plate on any other scene setting change; "Library tiles follow the
  scene's settings, not its cards" follows the open scene's settings as edited, not as read; "A
  request carries the host's scene, viewing and styles" replaces "A request carries the host's
  scene and settings"; and "Backdrop images are fetched before they are drawn" has no fallback's
  image to fetch.

## Impact

- **Code:** The editor's undoable state grows from a `SceneLayout` to the layout plus the scene's
  blocks, so one history holds both; `Draft`, `SceneDrafts`, `SceneEditor` and the renderer build
  the document from it. `ConsoleCore` reads each `block.*` declaration and the scene's own settings
  with `card-settings`'s reader, reads the roles and scales and resolves a card's colour in a scene
  (`SceneColours`), and lists and uploads
  images (`HostClient`, `/v1/images`). `RenderRequest` and `PanelScenes` carry the viewing and
  styles. In the app target, `SceneSettingsPanel` grows the tabs and block sections, a backdrop
  editor and a gradient stop list; the card inspector grows the role menu; library tiles and
  thumbnails draw from the edited document.
- **Sequencing:** builds on `card-settings`, built and archived: the declaration reader, the
  controls, Use Default and the colour panel are its. `styles` follows this change.
- **Host:** audio-vue's `scene-editor-settings` (2026-11-20) answered this change's hand-off:
  `x-inherits` on a scene's display settings and a card's shadow, steps on the sizes and other
  pixel settings, the plates' opacity at 0.6, a screensaver choice per scene, and the silence
  reset in a scene's analysis in place of a signal threshold. A new scene asks nothing of the
  host: it is the app's alone until it holds a card.
- **Host:** `scene-styles-handoff.md` (2026-11-19) told the console what audio-vue's `scene-styles`
  changed; this change follows the part that reaches a scene's own settings and its drawing.
  Earlier asks: `meter-colours-handoff.md`, answered by `x-unused-when`; `scene-settings-handoff.md`,
  answered by `GET /v1/calibration`. Referenced specs relied on: `audio-vue:card-colours` (roles in
  groups, meaning scales, a card's own colours, shadow as an amount, resolution by lookup),
  `audio-vue:type-scale` (a size per text role in reference pixels), `audio-vue:typefaces` (the
  declared faces), `audio-vue:settings-schema` (every block declared, classes, standards, one
  validation, a colour setting naming its role or its own default, a setting saying when it has no
  effect), `audio-vue:settings-store` (a scene written whole on its revision; images uploaded,
  named by id, and not deleted while a stored scene names them; a write leaves the screen),
  `audio-vue:scene-backdrop` (one source; a gradient of two or more stops at a CSS angle; no
  backdrop is the default style's), `audio-vue:scene-grid` (a scene declares its grid; placements
  stay on it; the gap), `audio-vue:card-layout` (each card's minimum on a 36-row grid) and
  `audio-vue:scene-render` (a request carries the scene as the store holds it, the viewing and the
  styles it names).
