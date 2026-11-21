# Spec Delta

## ADDED Requirements

### Requirement: A saved scene declares no grid size

A scene the app writes SHALL carry no `cols` or `rows` in its `grid:` block. A stored scene that
holds either SHALL open marked unsaved, drawn without them, so that saving it removes them.

Source: audio-vue `scene-grid`, "`grid:` holds the layout grid and nothing else": a scene that sets
`cols` or `rows` is refused. Decision (maintainer, 2026-11-21): such a scene is opened and resaved.

#### Scenario: Saving a new scene

- **WHEN** the user saves a new scene made for a 96-column panel
- **THEN** the document sent holds no `cols` and no `rows`

#### Scenario: A scene stored with a grid size

- **WHEN** the user opens a stored scene whose `grid:` holds `cols`, `rows` and `gap`, and saves it
- **THEN** it opens marked unsaved and is drawn, and the document sent holds `gap` alone

### Requirement: An unset span is kept until its card is resized

A card read with no `colspan` SHALL be written with none while it starts at column 0 and spans every
column of the panel's grid, and likewise a `rowspan` by rows. Once it does not, the span SHALL be
written.

Source: Decision (maintainer, 2026-11-21): an unset span stays unset until the card is resized, so a
copy of Default still fills any panel.

#### Scenario: A copy of Default, saved untouched

- **WHEN** the user duplicates the built-in Default, changes its backdrop, and saves
- **THEN** its card is written with no `colspan` and no `rowspan`

#### Scenario: Resized

- **WHEN** the user makes that card 48 columns wide on a 96-column panel and saves
- **THEN** its card is written with `colspan` 48

### Requirement: Only stored scenes and copies are renamed and deleted

The app SHALL NOT offer Rename or Delete for a built-in scene. Rename and Delete SHALL be offered
for every stored scene and for a copy never saved.

Source: audio-vue `settings-store`: a built-in is refused for a write or a delete. `product.md`:
built-in scenes are read-only.

#### Scenario: A built-in's menu

- **WHEN** the user opens the gallery menu of the built-in RTA
- **THEN** it offers neither Rename… nor Delete…

#### Scenario: A stored scene too wide for the panel

- **WHEN** the user opens the gallery menu of a stored scene too wide for the panel
- **THEN** it offers Rename… and Delete…

## MODIFIED Requirements

### Requirement: Only an editable scene is saved

Save SHALL be enabled only for a scene the canvas may edit that is unsaved. It SHALL NOT be offered
for a built-in scene. A scene too wide for the panel SHALL be saved like any other.

Source: `scene-canvas`, "A read-only scene can be looked at, not edited". audio-vue
`settings-store`: a built-in is refused for a write; `scene-grid`: a scene write is accepted however
wide the scene is.

#### Scenario: A built-in scene

- **WHEN** the user opens the built-in RTA
- **THEN** Save is disabled

#### Scenario: Nothing to save

- **WHEN** the user opens a stored scene and makes no edit
- **THEN** Save is disabled

#### Scenario: A scene too wide

- **WHEN** the user edits a stored scene too wide for the panel
- **THEN** Save is enabled

### Requirement: Versions lists the scene's kept revisions

The editor's Versions menu SHALL list a stored scene's current version and each earlier revision
the host keeps, newest first, each by its local date and time. It SHALL be disabled for a built-in
and for a copy never saved.

Source: audio-vue `settings-store`: each document's earlier revisions are kept up to a designed
count. Decision (maintainer, 2026-11-07): a menu of every dated version in the store.

#### Scenario: A scene saved three times

- **WHEN** the user opens Versions on a stored scene saved three times
- **THEN** it lists the current version and the two earlier ones, each by date and time

#### Scenario: A built-in

- **WHEN** the user opens a built-in scene
- **THEN** Versions is disabled

## REMOVED Requirements

### Requirement: Built-in scenes are neither renamed nor deleted

**Reason**: Its scenario spoke of a scene's shape, which a scene no longer has. Replaced by "Only stored
scenes and copies are renamed and deleted".
**Migration**: None.
