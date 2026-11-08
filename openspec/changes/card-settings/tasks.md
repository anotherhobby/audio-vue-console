# Tasks

Groups 1 to 3 build on the code as it stands and can be done before audio-vue answers the handoff.
Group 4 waits on audio-vue exporting `x-step` and `x-settings` (design D7), deployed to the panel,
with the render bundle refreshed. Run the core suite with
`cd ConsoleCore && xcrun swift test --disable-xctest` (`commands.md`).

## 1. Ask audio-vue

- [x] 1.1 Write `../audio-vue/card-settings-handoff.md` (design D7): ask for `x-step` on each
  exported setting (`Param.step`, null where none) and `x-settings` on each `card.<name>` and
  `block.<name>` (its keys in declared order; blocks for `scene-settings`), say why (an inspector's control steps; `JSONValue` loses object order), cite
  `vu_meter` (channel declared before alignment) and `peak_rms` (floor steps by 10 dB), and say the
  saved contract's `/v1/schema` body is untyped so the contract does not change. Add alignment F7
  as a note: `settings-schema`'s "A scene sets no measured value" names chain settings, while the
  validation accepts a card's (`vu_meter.channel`). Verify the file
  exists and names both keywords, and record the ask in `working-notes.md`.

## 2. Settings in the core

- [ ] 2.1 Give `LayoutCard` (`ConsoleCore/Sources/ConsoleCore/SceneLayout.swift`) `settings:
  [String: JSONValue]`, default empty; read it in `LaidOutScene.card(_:on:id:)` from the entry's
  `params` (an entry whose `params` is not an object throws `.unreadableCard`), and write it in
  `entry(for:)`, setting `params` when non-empty and removing it when empty (design D1). Verify with
  `LaidOutSceneTests`: the RTA fixture's `rta_bars` reads its six params; `doc(for:)` of the
  unchanged layout equals the fixture's `doc`; a card with settings changed writes them and keeps
  `plate` and `alternate`; emptying a card's settings drops `params`; a copy keeps settings.
- [ ] 2.2 Add `SceneLayout.setting(_:to:on:)` and `unsetting(_:on:)` (design D4). Verify with
  `SceneLayoutTests`: setting a key on two ids changes both and nothing else; unsetting removes the
  key from both; the result is a valid layout with the same cells.
- [ ] 2.3 Add `SceneEditor.set(_:to:label:on:)` and `useDefault(_:label:on:)`, for the selection or
  one selected card, through `commit` with the names "Change <label>" and "Use Default for
  <label>", the label as declared; refused on a
  read-only editor by `preview`, as other edits are. Verify with `SceneEditorUndoTests`: a change is
  one step named "Change Lamp hold"; undoing it restores the value and leaves `Draft.isUnsaved`
  false when it was the only edit (`SceneDraftsTests`); setting the current value adds no step; a
  two-card change undoes as one; a change on one card of a selected group changes that card alone.
- [ ] 2.4 Add `PlateState` and `PlateChanges.drawn(of:)`, a plate's cells plus its members'
  settings, and have `needed(drawn:for:)` compare it; keep `cells(of:)`. Give
  `SceneRendering.PlacedLayer` the settings it was drawn with, set in `take(_:drawnFor:cardIDs:)`,
  and pass that state at `show(_:)`'s call to `needed` (design D6). Verify
  with `PlateChangesTests`: a settings change on one grouped card redraws that group alone; a move
  still redraws by cells; and with `SceneRenderingTests`: a settings change sends one request for
  that plate, with the changed `params` in the request's scene.

## 3. Reading declarations

- [ ] 3.1 Add `SettingGroup` and `SettingDeclaration` (`ConsoleCore/Sources/ConsoleCore/
  SettingGroup.swift`, design D2): from a `card.<name>` definition, each setting's key, label,
  help, unit, class, standard and default, and its `Shape` (boolean, number or integer with range
  and step, choice, colour by its `pattern`, other), ordered by `x-settings`. Parse them in
  `SchemaFacts.init?(schema:)` into `settings: [String: SettingGroup]`. Extend
  `Fixtures/schema-trimmed.json` from audio-vue's `json_schema()` with `rta_bars` (palette colours,
  integers) and `peak_rms`, `dynamics_gauge` (shared keys), and add `x-step` and `x-settings` in the
  shape asked. Verify with `SchemaFactsTests`: `vu_meter` reads five settings in declared order with
  their shapes; `rta_bars`'s colours have no default; a card with no `properties` reads none; an
  unknown type reads `.other`.
- [ ] 3.2 Add `SettingGroup.shared(_:)` and the selection's values, `.same(value, isSet)` or
  `.mixed` (design D3), labelled from the card first in layout order. Verify with a
  `SettingGroupTests` suite: `dynamics_gauge` with `peak_rms` shares `show_readout` and `show_scale`
  and not `floor_db` or `max_db`; `peak_rms` with `rta_bars` shares no `floor_db`; differing values
  read `.mixed`.
- [ ] 3.3 Add effective values and notes (design D5): set, default, or palette; `.offStandard` for a
  measurement value outside its standard's `values`; no note for any other class, chain included.
  Add the value writing rules (design D4): a whole number as `.integer`, a number setting's
  included, a fraction as `.decimal`, clamped and rounded to the step from the minimum and to the
  step's decimal places; a colour as upper-case `#RRGGBB`. Verify with `SettingGroupTests`:
  `alignment` custom is off ITU-R BS.1726 and EBU is not; `reference_dbfs` (governed by none) is
  never flagged; `vu_meter.channel` (chain) has no note; an unset `alignment` reads SMPTE as the
  default; typing 9 into `lamp_hold_s` writes `.integer(5)`; 2.4 with step 1 from minimum 1 gives
  2; `floor_db` set to -80 writes `.integer(-80)` and 0.9 writes `.decimal(0.9)`; 0.15 stepped up
  three times by 0.05 writes `.decimal(0.3)`.

- [ ] 3.4 Add `HexColour` (`ConsoleCore/Sources/ConsoleCore/HexColour.swift`, design D8): parse
  `#rrggbb` either case into sRGB components 0 to 1, refusing anything else, and format components
  back as upper-case `#RRGGBB`, each rounded to the nearest of 255 steps and clamped. Verify with
  `HexColourTests`: `#2a3550` round-trips to `#2A3550`; every one of 4,096 sampled hex values
  round-trips unchanged; components 0.999 and -0.01 format as FF and 00; `#2a355` and `2a3550` are
  refused.

## 4. The inspector

- [ ] 4.1 Once audio-vue answers the handoff and is deployed: read a real export from the panel
  (`GET /v1/schema`), confirm `x-step` and `x-settings` are as task 3.1 assumed, correct the parse,
  fixture and design D2/D7 where they differ, delete `../audio-vue/card-settings-handoff.md` if
  audio-vue has not, and update `working-notes.md` and `host-contract.md`'s Settings section.
  Verify with `openspec validate card-settings --strict` and the core suite.
- [ ] 4.2 In `AudioVueConsole/Scenes/SceneInspector.swift`, show settings from
  `scenes.facts?.settings` and the editor's selection (design D3, D5), in the inspector's existing
  `Form` (`pitfalls.md`, the List crash in the editor). One card: its settings, or "This card has no
  settings.". Several: Group/Ungroup, then the shared settings (none where they share none), then a
  collapsed `DisclosureGroup` per selected card in layout order with all its settings, editing that
  card alone. Controls: a `Toggle`, a `Picker` of the choices, a `ColorPicker(supportsOpacity: false)`
  converting through `NSColor.usingColorSpace(.sRGB)` and `HexColour`, with changes coalesced into
  one undo step (design D8) and "Uses the palette" when unset, a number `TextField` with its unit plus a `Stepper` by the step, committing
  on submit or release; each with its help as a caption, "Default" or a Use Default button, "Mixed"
  where values differ, and the off-standard note in orange. Nothing is labelled Reset. Controls are
  disabled on a read-only editor. Verify by building the app (`BuildProject` over Xcode MCP) with no
  new warnings and the quality gate clean.

## 5. Integration

- [ ] 5.1 Against the proving host (`commands.md`, live tests): open a stored scene, change a VU
  meter's alignment to custom (flagged), set a peak meter's floor to -80 (canvas redraws that plate
  alone), choose Use Default on an `rta_bars` colour (palette; the panel's measurement is not
  reset), edit two peak meters' Peak hold together, set the Channel of a VU meter in a group from
  its own section (no calibration warning), type a hex colour in the colour panel and pick one with
  its eyedropper (stored as typed; a drag on the wheel is one undo step), undo each, then Save and re-open: the scene is not
  marked unsaved and the stored entries hold exactly the changed keys (design D4). On a built-in,
  settings show and cannot change. Record the run in `working-notes.md`.

## Workflow follow-up

- The maintainer's run of the app, then verify and archive the change and sync its specs.
- Before the pull request, review agent-maintained KB updates (`host-contract.md`, `project-map.md`,
  `working-notes.md`).
