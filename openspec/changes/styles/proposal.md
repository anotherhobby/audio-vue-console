# Proposal

## Why

A scene's look is its colours, typeface, text sizes, backdrop and glass, and each scene holds its
own copy (`scene-settings`). Making several scenes look alike, or changing a colour everywhere,
means editing each one. A style names a look once, and every scene that names it follows it.

audio-vue built the host side as `scene-styles` (deployed 2026-11-19), answering this change's
hand-off of 2026-11-08: the style document, built-in and stored styles, the routes, scenes naming
styles, the one-source rule, and the render request carrying them. What is left is the app's.

## What Changes

- **A style is à la carte** (maintainer, 2026-11-08; built by audio-vue): a named document holding
  any of the five look categories, at least one: colours, a typeface, text sizes, a backdrop and
  glass, each exactly as a scene declares it.
- **Scenes link to styles, several at once** (maintainer, 2026-11-08, confirmed 2026-11-19: a link,
  not a copy). A scene names styles by id; each category comes from the scene's own key, else the
  one named style holding it, else the built-in Default. Editing a style changes every scene that
  names it, on the panel at its next reload or switch.
- **Each look category says where it comes from** (proposed, 2026-11-19). In the scene inspector,
  Typeface, Colours, Text Sizes, Backdrop and Glass each carry a source: This Scene, a style that
  holds the category, or Default. The canvas, the library tiles and the card inspector's colours
  draw from the look as resolved, so a card's unset colour shows the style's.
- **No category is set twice.** Choosing a style for a category removes the scene's own key for
  every category that style holds, as one undoable step, saying which, and is refused where another
  named style holds one of them, offering to drop that style instead. Choosing This Scene copies
  the style's values for that category into the scene; the style stays named while the scene still
  takes another category from it.
- **A style is edited where it is seen** (maintainer, 2026-11-19: styles belong in the scene
  editor, where a change can be seen, not in a sidebar section of their own). Changing a setting of
  a category that comes from a stored style changes the style, in the same undo history, and the
  inspector says how many other scenes take it. Save stores the changed styles, then the scene. A
  built-in style is read-only: changing it offers to duplicate it first, as the host's refusal
  says.
- **Styles are made, renamed and deleted from the same place**: Save as New Style… lifts the
  categories the user picks from the scene into a new style and names it on the scene; Rename… and
  Delete… act on a stored style, Delete refused while a stored scene names it, naming the scenes.
- **A style edit that would set a category twice is refused** by the host, naming the scenes; the
  app shows the refusal with each scene.
- **A style the host does not hold is said**: the canvas shows the helper's `style_notice`, as it
  shows a missing backdrop image.
- **The app asks for the host's viewing at setup** while the host says it is unset
  (`install.viewing_set`): the viewing distance and the display's diagonal, in inches, written to
  the install's `viewing` block, so text is the size its reader sees on every host.

Not doing: a Styles section in the sidebar (the 2026-11-08 plan), a style's revisions and revert
(the routes exist; a later change), and uploading typefaces, which ship with audio-vue.

## Open, for the maintainer

1. **One history or two.** Proposed above: a style changed from a scene is part of that scene's
   edit, undone with it and saved with it. The alternative keeps style edits apart, saved at once
   as they are made, with no undo across them.
2. **A changed style and the other scenes open in the app.** Proposed: their thumbnails and drafts
   are drawn again once the style is saved, not while it is edited.
3. **Where the viewing is asked.** Proposed: on the Panel page, as a notice with the two fields,
   until both are stored.

## Capabilities

### New Capabilities

- `scene-style`: a scene's look by category and where each comes from: choosing a source, editing a
  style from a scene, making, renaming and deleting styles, and what is refused.
- `host-viewing`: asking for and storing the host's viewing distance and display size.

### Modified Capabilities

- `scene-settings`: each look category shows its source, and its settings are the source's.
- `card-settings`: an unset colour shows the colour of the scene's look as resolved, a style's
  where the scene takes its colours from one.
- `scene-rendering`: a request carries the stored styles its scene names, as edited; a missing
  style is said.
- `scene-saving`: Save stores the styles the user changed with the scene, and a stale style write
  is offered as a stale scene write is.
- `host-client`: the style routes.

## Impact

- **Code:** `HostClient` gains the style routes. `ConsoleCore` gains the look's resolution as
  audio-vue's `src/styles.py` does it (the scene's key, else the one style, else Default), a
  styles store beside `PanelScenes`, and the editor's content grows the styles the scene names, so
  one history holds a scene and its styles. `RenderContext.styles`, already sent, is filled. In the
  app target, a source row per category in `SceneSettingsPanel`, the style sheets, and the viewing
  notice.
- **Sequencing:** after `scene-settings`, which reads the scene's own colours, sizes and typeface
  and sends the request's `styles` and `viewing`.
- **Host:** none outstanding. `scene-styles-handoff.md` (2026-11-19) states what audio-vue built.
  Referenced specs relied on: `audio-vue:styles` (the document, built-in and stored styles, the
  one-source rule, deletion, when the panel takes a style), `audio-vue:settings-store` and
  `audio-vue:control-api` (the style routes and refusals), `audio-vue:settings-schema`
  (`$defs/style`), `audio-vue:scene-render` (a request carries its styles; `style_notice`),
  `audio-vue:type-scale` (the viewing) and `audio-vue:typefaces`.
- **Unconfirmed against the host until planned in full:** the built-in Default's own document is
  in the render bundle (`styles/default.yaml`) and in `GET /v1/styles/default`; which the app reads
  for the resolved look is a design decision of this change.
