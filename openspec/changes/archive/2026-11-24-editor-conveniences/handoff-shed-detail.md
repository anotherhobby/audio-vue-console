# Hand-off to audio-vue: report shed detail in the render answer

From the console's `editor-conveniences` change, 2026-11-24.

## What the console needs

The console sizes library tiles by asking the render helper for a card's plate at growing sizes
and taking the first whose layer's `unfit` is empty. A user can now set a library card up before
placing it, such as a meter with tick marks and its value to the right of its name, and the tile
and the cards dropped from it should be sized so that what the setup asks for is shown.

`unfit` names only a card laid out to the too-small notice (`scene_layers._unfit`). Before that, a
card sheds its drop steps (`cards/base.fit`, `Layout.level`): the meter its inner scale labels, end
labels, then tick marks. Nothing in the answer says a step was shed, so the console cannot tell a
meter drawn without its ticks from one drawn whole.

## The ask

Each plate layer in a `render` answer reports, per card, how many of its drop steps were shed at
the size drawn, beside `unfit`; zero where the card is drawn whole. A shape such as
`"shed": {"meter": 2}`, or a per-card list, is audio-vue's to choose and state in its spec.

## What the console will do with it

Grow a set-up tile, and the size a set-up card is dropped at, until its card sheds nothing.
Plain tiles keep sizing for the reading alone, as the maintainer ruled (2026-11-21).
