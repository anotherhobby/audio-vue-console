# Spec Delta

## ADDED Requirements

### Requirement: A scene is laid out on the panel's grid

The app SHALL lay every scene out on the grid the panel's state gives for its display, and SHALL
read no grid size from the scene.

Source: audio-vue `scene-grid`, "The grid is the host's"; `control-state`, "The state says the
display's grid". Hand-off `host-grid-handoff.md`, 2026-11-21.

#### Scenario: An 8:3 panel

- **WHEN** the panel's state gives a grid of 96 columns by 36 rows and the user opens a scene
- **THEN** the scene's cards are placed on 96 columns by 36 rows

#### Scenario: The same scene on a 16:9 panel

- **WHEN** the same scene is opened for a panel whose state gives 64 columns by 36 rows
- **THEN** its cards are placed on 64 columns by 36 rows

### Requirement: A scene too wide for the panel is laid out on its reach

A scene that places a card past the panel's last column SHALL be laid out on the panel's rows and
as many columns as its furthest card reaches, and SHALL be named too wide for the panel while any
card ends past the panel's last column.

Source: Decision (maintainer, 2026-11-21): a scene too wide can be opened and edited on its own
reach, so its cards can be moved in. audio-vue `scene-grid`, "A scene too wide for the display is
refused".

#### Scenario: A card past the last column

- **WHEN** a scene with a card at column 80, 16 columns wide, is opened for a 64-column panel
- **THEN** it is laid out on 96 columns, and named too wide

#### Scenario: Moved in

- **WHEN** the user moves that card to column 48
- **THEN** the scene is no longer too wide

### Requirement: An unset span covers the grid

A card that declares no `colspan` SHALL span every column of the panel's grid, and one that declares
no `rowspan` every row. An unset `col` or `row` SHALL be 0.

Source: audio-vue `scene-grid`: an unset span is resolved on the grid the scene is drawn on;
`settings-store`, "The default scene is one RTA across the grid".

#### Scenario: The built-in default

- **WHEN** the built-in Default, one `rta_bars` with no spans, is opened for a 96-column panel
- **THEN** its card covers all 96 columns and 36 rows

## MODIFIED Requirements

### Requirement: Every card lies on the scene's grid

Every card in a layout SHALL lie wholly within the grid the scene is laid out on, and no edit SHALL
leave a card running off it.

Source: audio-vue `scene-grid`, "Rows are checked without a display" and "A scene too wide for the
display is refused".

#### Scenario: A card at the grid's edge

- **WHEN** a 64 × 36 layout holds a card at column 56, 8 columns wide
- **THEN** the card lies on the grid, ending at its last column

#### Scenario: An edit that would run off

- **WHEN** an edit would place any cell of a card past the grid's last column or row
- **THEN** the card stays on the grid, as the requirement for that edit says
