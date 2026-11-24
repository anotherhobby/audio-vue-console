## ADDED Requirements

### Requirement: A colour in a scene block takes one of the scene's colours or its own

A colour setting in a scene block, outside the Colours section, SHALL offer the scene's roles, each
shown in the scene's colour for it as edited, and a colour through the system colour panel. Set to
a role, it SHALL show the scene's colour for it and say which. Unset, it SHALL show its own default
and name no role.

Source: audio-vue `screensaver`, "A scene sets `bounce`'s colours". `card-settings`, "A card's
colour takes one of the scene's colours or its own".

#### Scenario: Unset

- **WHEN** a scene's display block sets no screensaver bar foot colour
- **THEN** Screensaver bar body colour shows `#1AD9CC`, the logo's own, and names no role

#### Scenario: A role

- **WHEN** the user chooses Bar body for Screensaver bar body colour on a scene whose Bar body is
  `#FFFF00`
- **THEN** the scene's display block sets `saver_bar_foot_color: bar_body`, the setting shows
  `#FFFF00` and says it uses the scene's Bar body colour, and Use Default is offered

#### Scenario: The role changes

- **WHEN** Screensaver bar body colour is set to Bar body and the user then sets the scene's Bar
  body to `#00FF00`
- **THEN** Screensaver bar body colour shows `#00FF00`

#### Scenario: A colour of its own

- **WHEN** the user picks `#445566` in the colour panel for Screensaver peak hold colour
- **THEN** the scene's display block sets `saver_hold_color` to `#445566`, and the setting names
  no role

### Requirement: The scene's Display section shows the screensaver's look

The Display section SHALL list the host's display settings in declared order: the screensaver and
its timeouts, each showing the panel's value while unset, then the screensaver's four colours, then
whether it uses the scene's backdrop and the scene's plate as switches, off while unset.

Source: audio-vue `screensaver` (`native-logo`); audio-vue `native-logo` design D6: the six
settings sit in the scene's one `display:` block, shown as one Display section beside the saver
they dress.

#### Scenario: Opening Display

- **WHEN** the user opens a scene that sets no display settings and looks at Scene, Display
- **THEN** it lists Screensaver, Screensaver after and Sleep after, each saying it uses the
  panel's, then the four screensaver colours at the logo's own, then Use the scene's backdrop and
  Use the scene's plate, both off

#### Scenario: The scene's backdrop

- **WHEN** the user turns on Use the scene's backdrop
- **THEN** the scene's display block sets `saver_scene_backdrop: true` as one undoable step, and
  the scene is marked unsaved
