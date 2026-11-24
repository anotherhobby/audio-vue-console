## MODIFIED Requirements

### Requirement: A saved scene declares no grid size

A scene the app writes SHALL carry no `cols` or `rows` in its `grid:` block. A stored scene that
holds either SHALL need a repair (`scene-repair`), which removes them.

Source: audio-vue `scene-grid`, "`grid:` holds the layout grid and nothing else": a scene that sets
`cols` or `rows` is refused. Decision (maintainer, 2026-11-21): such a scene is opened and resaved.
Decision (maintainer, 2026-11-23): the console asks before repairing a scene, and a grid size is
repaired as any undeclared key is.

#### Scenario: Saving a new scene

- **WHEN** the user saves a new scene made for a 96-column panel
- **THEN** the document sent holds no `cols` and no `rows`

#### Scenario: A scene stored with a grid size

- **WHEN** the user opens a stored scene whose `grid:` holds `cols`, `rows` and `gap`, chooses
  Repair, and saves it
- **THEN** it opens offering Repair and not marked unsaved, and the document sent holds `gap` alone
