# Proposal

## Why

`scene-rendering`'s "A library tile is the card's plate as the helper draws it" states three
behaviors in one description: what a tile shows, the size it is drawn at, and what lies under its
plate. At 797 characters it fails `openspec validate --strict`, the only spec that does.

## What Changes

- The requirement keeps its header and every scenario, and its description keeps one behavior: a
  tile is the helper's plate for its card alone, in the open scene's settings, scaled to fit.
- The size a tile is drawn at becomes its own requirement: the smallest size on the panel's grid
  that shows the card's reading, never below the declared minimum.
- What lies under the plate becomes its own requirement: the scene's backdrop as it lies under the
  plate, or the library's plain ground with no backdrop drawn.
- Nothing the app does changes, and no wording changes meaning.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `scene-rendering`: the library tile requirement is split into three, each one behavior.

## Impact

- Code: none.
- Referenced specs relied on: none beyond those the requirement's source lines already cite
  (`audio-vue:scene-render`, `audio-vue:card-layout`), unchanged.
