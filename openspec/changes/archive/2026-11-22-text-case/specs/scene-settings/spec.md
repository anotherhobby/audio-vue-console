# Spec Delta

## MODIFIED Requirements

### Requirement: The inspector shows the scene's settings when no card is selected

With no card selected, the inspector SHALL show tabs: Scene (Backdrop, Cards, Grid, Display), Style
(Colours, then Text: the typeface, then the sizes, then Text Case), Analysis, and Other for any
other block or setting, by its name. Cards is the `glass` block. Settings SHALL behave as
`card-settings` says.

Source: `product.md`: every scene setting through the app. Maintainer, 2026-11-08 to 2026-11-20:
the tabs; Cards, not Glass; the typeface with the sizes. audio-vue `text-case`: the case too.

#### Scenario: Opening a scene

- **WHEN** the user opens a scene and selects nothing
- **THEN** the inspector shows the tabs Scene, Style and Analysis, with no Other tab, and Scene
  lists Backdrop, Cards, Grid and Display

#### Scenario: The typeface is with the sizes

- **WHEN** the user opens the Style tab
- **THEN** Text lists Typeface first, then a size for each kind of text

#### Scenario: The case follows the sizes

- **WHEN** the user opens the Style tab
- **THEN** Text Case follows Text, with a case for titles, labels, captions and the notice, each
  offering ALL CAPS and Title Case, and ALL CAPS shown while the scene sets none

#### Scenario: Captions in Title Case

- **WHEN** the scene sets no case and the user sets Caption case to Title Case
- **THEN** the scene's `case` block sets `caption: title_case` alone, every card's captions are
  drawn again as written, and Caption case offers Use Default

#### Scenario: A colour

- **WHEN** the scene sets no colours and the user sets Title to `#00FF88` in the colour panel
- **THEN** the scene's colours set `title` alone, every card's title is drawn again in it, and Title
  offers Use Default

#### Scenario: A text size

- **WHEN** the user sets Title size to 60
- **THEN** every card's title on the canvas is drawn at 60 reference pixels

#### Scenario: The typeface

- **WHEN** the user chooses Oxanium as the typeface
- **THEN** the scene sets `typeface` to `oxanium`, and every card's text is drawn in it

#### Scenario: A block the app does not know

- **WHEN** the schema declares a scene block no build of the app has seen
- **THEN** an Other tab shows it under its name, with its settings
