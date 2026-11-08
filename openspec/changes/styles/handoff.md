# Styles: what the console needs from audio-vue

From the console (audio-vue-console, change `styles`), 2026-11-08. The maintainer's rulings are
marked; everything else is a proposal for audio-vue to settle in its own change. Where audio-vue
decides otherwise, say so in the reply and the console follows.

## What a style is (maintainer, 2026-11-08)

A named look that scenes link to:

- **À la carte.** A style holds any of five categories, at least one: a palette (as
  `block.palette`), a typeface, the type roles (as `block.type`), a backdrop (as `block.backdrop`)
  and glass (as `block.glass`). A style may be a typeface alone. The install's font sizes (`fonts`,
  S to XL in px) stay host-wide: they are set for the panel's viewing distance.
- **Scenes link to styles, they do not copy them,** and a scene may link several, such as a typeface
  style and a colour style. Editing a style changes every scene that names it.
- **No category is set twice.** Each category a scene draws comes from exactly one place: one of its
  styles, or the scene's own block. A scene may not set a category one of its styles holds, and two
  of its styles may not hold the same category.
- **A style edit that would set a category twice is refused**, naming the scenes; the console then
  offers to remove that category from those scenes before saving the style.
- **Built-in styles ship with audio-vue**, read-only, at least `default`, holding exactly what a
  scene with no style draws today, so nothing changes on screen.
- **Typefaces ship with audio-vue.** The maintainer adds font files; nothing is uploaded.

## Asks

1. **The style document, in the schema.** `$defs/style` with `name`, `palette`, `typeface`,
   `type`, `backdrop` and `glass`, reusing the existing block definitions, every category optional
   and at least one required. Within a category held, unset keys take the scene's defaults. Each setting carries the usual `x-` keywords, and `x-settings` and
   `x-step` (asked in `card-settings-handoff.md`) apply here too.
2. **Typefaces.** A declared list, each with an id, a label and its file under `vendor/`, at the
   weight the cards draw (Inter is Medium today). `typeface` in a style is an enum of the ids, with
   the labels exported (for example `x-choice-labels`). The render bundle carries every typeface
   file, as it carries Inter now (its manifest's `entries`), so the console draws what the panel
   draws. A scene with no style draws in the `default` style's typeface.
3. **Built-in styles** from a repository folder (for example `styles/*.yaml`), named by stem,
   read-only, listed with `built_in: true`, as built-in scenes are (`settings-store`, "Every
   repository scene is a read-only built-in").
4. **Stored styles and routes**, mirroring scenes: `GET /v1/styles` (each style's `id`, `name`,
   `built_in`, the categories it holds, and the ids of the stored and built-in scenes that name it), `POST /v1/styles`,
   `GET`/`PUT`/`DELETE /v1/styles/{id}`, `GET /v1/styles/{id}/revisions`,
   `POST /v1/styles/{id}/revert` and `POST /v1/styles/validate`. A stored style is named by a UUID
   the host assigns. Revisions, stale-write refusal and validation-with-every-failure as for
   scenes. All with a token.
5. **Scenes name styles.** A scene's top-level `styles: [<id>, ...]`, order without meaning. A scene
   is refused, naming the category and the styles, where two of its styles hold the same category,
   or where it sets a block (`palette`, `type`, `backdrop`, `glass`, or the typeface) that one of its
   styles holds. A built-in scene may name built-in styles. A scene naming a style the host does not
   hold is not refused: the categories that style would give take the scene's defaults, and the
   state says which style is missing, as a missing backdrop image falls back (`scene-backdrop`).
   Since a scene can now hold no typeface of its own while it has no style, ask too: may a scene set
   a typeface itself (a top-level `typeface`), so a style is never needed for one? The console
   assumes yes, so every category can be set on a scene or linked from a style.
5a. **A style write that would set a category twice is refused** (maintainer, 2026-11-08): adding a
   category to a style that a scene naming it already sets, or gets from another style, is refused
   as invalid, naming each scene and the category, storing nothing. Validation checks it too.
6. **Deletion.** A style that a stored scene names is not deleted, the refusal naming the scenes;
   a built-in style is never deleted. An image a stored style names is not deleted, as for scenes
   (`settings-store`, "An image a stored scene names is not deleted").
7. **The screen.** Writing a style never changes the screen; the panel takes it at the next reload
   or switch, as for a scene write (`settings-store`, "A write leaves the screen as it is"). The
   console's Apply for a style saves it, then reloads where the scene on screen names it.
8. **The render helper.** The `render` request gains an optional `style`: the document the scene
   names, as the store holds it, which the helper resolves exactly as the panel does, one shared
   resolution, so the console sends the scene as stored and never a merged copy. Refused with the
   panel's own failure where the panel would refuse the pair.
9. **The contract.** The routes and the `Style`/`Styles` bodies in `/v1/openapi.json`, so the
   console's client is generated from them.

## Not asked

- Fonts per card or per kind of text: one typeface per style.
- Changes to the install's font sizes.
- Styles for card settings: a card's own colours (such as `rta_bars`' line colours) still win over
  the palette for that card, as today.

## Reply

Answer in this file or a reply beside it, naming the change that builds it, the route and keyword
names chosen, and anything asked here that audio-vue does differently. The console writes this
change's specs from the reply.
