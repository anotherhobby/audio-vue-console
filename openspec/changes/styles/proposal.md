# Proposal

## Why

A scene's look is spread over its palette, type roles, backdrop and glass, and each scene holds its
own copy (`scene-settings`). Making several scenes look alike, or changing a colour everywhere,
means editing each one. The typeface is fixed as Inter, though more are coming. A style names a
look once, and every scene that uses it follows it.

## What Changes

- **A style is à la carte** (maintainer, 2026-11-08): a named document holding any of five
  categories, at least one: a palette, a typeface, the type roles (which size titles, labels and
  values use), a backdrop and glass. A style may be a typeface alone, or a typeface and a palette.
  The install's font sizes stay host-wide, set for the panel's viewing distance.
- **Scenes link to styles, several at once** (maintainer, 2026-11-08). A scene names a list of
  styles by id, as it names a backdrop image; each category comes from at most one of them, and the
  scene sets itself only the categories none of its styles hold. The panel and the console's
  renderer take each linked category from its style. Editing a style changes every scene that
  names it, at the panel's next reload or switch. A style a stored scene names is not deleted.
- **No category is set twice.** Linking a style removes the scene's own blocks for the categories it
  holds, as one undoable step, and is refused where another linked style holds one of them, saying
  which; the console offers to unlink that style instead. The scene inspector shows linked
  categories from their style, read-only, with Edit Style…. Detach copies a style's categories into
  the scene and drops the link. Make Style from Scene saves the categories the user picks from a
  scene's own look as a new style.
- **A style edit that would set a category twice is refused** (maintainer, 2026-11-08). Adding a
  category to a style that a scene naming it already gets from its own blocks or another style is
  refused by the host, naming the scenes. The console offers to remove that category from those
  scenes first, then saves the style.
- **Built-in styles** (maintainer, 2026-11-08). audio-vue ships read-only styles, at least Default
  (today's palette, Inter, the default type roles, backdrop and glass), duplicated to edit, as
  built-in scenes are. A scene with no style keeps its own blocks, as today.
- **Typefaces ship with audio-vue** (maintainer, 2026-11-08). The maintainer adds font files to
  audio-vue; every panel and the console's render bundle carry them, and the schema lists them as a
  style's choices. No font is uploaded.
- **A scene may set its own typeface** (assumed; asked of audio-vue in the handoff), so every
  category can be set on the scene or linked from a style, and a typeface never needs a style.
- **A Styles section in the sidebar** (maintainer, 2026-11-08) lists Built-in Styles and My Styles.
  Its editor turns each of the five categories on or off for the style and shows the ones held with
  `scene-settings`'
  controls, previewed on a scene the user picks, the scene on the panel by default, at the panel's
  shape. New, Duplicate, Rename, Delete, Save, Revert and Versions work as they do for scenes.
- **A handoff asks audio-vue for the host side** (`handoff.md` in this change, placed as
  `../audio-vue/styles-handoff.md` on 2026-11-08): the style document and its schema, typefaces, the store and routes, scenes
  naming a style, deletion rules, and the render request carrying the style.

Specs, design and tasks for this change are written once audio-vue answers the handoff, since they
rest on the routes and document shapes it settles.

## Capabilities

### New Capabilities

- `styles`: the Styles section: listing, editing, previewing and storing styles.
- `scene-style`: a scene's link to a style: choosing, showing, detaching and making a style from a
  scene.

### Modified Capabilities

- `scene-settings`: a styled scene shows its palette, type, backdrop and glass from its style,
  read-only.
- `scene-rendering`: a request carries the style its scene names, and a style edit draws again the
  scenes open that name it.
- `panel-window`: the sidebar gains Styles.

## Impact

- **Code:** `HostClient` gains the style routes; `ConsoleCore` gains a styles store and drafts like
  `PanelScenes` and `SceneDrafts`; the render request carries the style. In the app target, a
  `StylesPage` in `PanelWindow`'s sidebar, and the scene inspector's style picker.
- **Sequencing:** after `card-settings` and `scene-settings` (its editors), and after audio-vue
  builds the handoff's asks, deployed to the panel with the render bundle refreshed.
- **Host:** audio-vue's styles work, as the handoff asks. Referenced specs relied on, to be
  confirmed against what audio-vue builds: `audio-vue:settings-store`, `audio-vue:settings-schema`,
  `audio-vue:scene-backdrop`, `audio-vue:type-scale`, `audio-vue:scene-render` and
  `audio-vue:render-bundle`.
