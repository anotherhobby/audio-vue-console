# Code alignment

## Read

Pass 1, 2026-11-07, against `dev` at `1908424` with `library-render` groups 1 to 3 built in the
working tree:

- `tools/refresh-contract.sh --check`: the saved contract matches audio-vue's as the refresh writes
  it.
- Saved contract (`ConsoleCore/Sources/HostAPI/openapi.json`): `POST /v1/scenes` (201
  `SceneWritten`, 422 `Invalid`), `PUT /v1/scenes/{id}` (`Edit` with `doc` and `base_rev`; 200, 409
  `Stale` with `current_rev`, 422, 404), `DELETE /v1/scenes/{id}` (204, 409 `Refusal`, 404),
  `SceneSummary` and `SceneDocument` with `rev` and `name`, and `Failure` with `place` and `message`
  only.
- audio-vue `src/host_store.py` `_name`: a stored scene's listed name is its document's `name:`, or
  empty. `src/control_service/settings.py` `SceneDocs.delete`: refused with "the scene is on screen"
  or "the panel is recorded to start on this scene".
- audio-vue `settings-store` and `control-api`, in full. `openspec list --store audio-vue`: no
  active changes.
- `SceneDrafts.swift`: `layouts` by id, `copies`, `duplicate(_:)` building its doc from the
  `LaidOutScene` it is handed and a kept layout from another parse.
- `LaidOutScene.swift`: a fresh `UUID` per card on each `init`, and `doc(for:)` finding entries by
  those ids.
- `LayoutCard` and `SceneLayout` (`SceneLayout.swift`): `Hashable`, including the card id.
- `SceneEditorView.swift` `make()`, `follow`, `drawTiles`, `duplicate()`: the editor and
  `SceneRendering` are built from a new parse, with the kept layout.
- `ScenesPage.swift` `load()`, `drawThumbnails()`, `PanelKey`: `store.forget()` on every key change,
  thumbnails paired with fresh parses.
- `SceneGallery.swift` `menu`, `SceneRow.thumbnail`: Duplicate from the gallery's parse, and boxes
  from `drafts.layout(for:)`.
- `SceneInspector.swift` `kept`: "In this app until it quits" for a copy.
- `SceneStore.swift`: drafts, thumbnails, tiles, `forget()`.
- `PanelScenes.swift` `load()`, `fail`: `scenes` `private(set)`, `.tokenRefused` handled by `fail`.
- `HostClient.swift` `HostFailure`, `call`: 401 is mapped centrally (`HostRules.TokenRefused`).
- `HostClient+Scenes.swift`: reads only, and `SceneDocument` built without `rev`.
- `HostConnection.swift` `isPaired`, `host`, `connect(at:announcedID:)`: `isPaired` is nil while
  connecting, and `host?.id` is the paired host's id.
- `PanelWindow.swift` `picker`: the found-panel choice calls `connection.connect(to:)`.
  `AddPanelSheet.swift`: its `connect` closure calls `connection.connect()`.
- `AudioVueConsoleApp.swift` `AppDelegate`: only `applicationShouldTerminateAfterLastWindowClosed`.
- `ConsoleCore/Tests/ConsoleCoreTests/`: `SceneDraftsTests`, `PanelScenesTests`,
  `HostClientScenesTests`, `SceneRenderingTests`, `SceneThumbnailsTests` exist. `FakeTransport`
  answers by method and path.
- `pitfalls.md`, `open-questions.md`: read for scene, draft, undo and title items.
- Apple documentation, `navigationTitle(_:)` with a `Binding<String>` (via Xcode's documentation
  search).
- Each task in groups 1 to 6 was read against the code above.

Pass 2, 2026-11-07, for Apply, Revert, Versions, the panel-behind note and Reset:

- Saved contract: `POST /v1/commands/switch` (`Switch` with `scene`; `Outcome` with `status` of
  `done`, `refused`, `expired`, `unknown` or `no panel` and `reason`; 200, 409, 503, 504),
  `POST /v1/commands/reload`, `GET /v1/scenes/{id}/revisions` (`Revision` with `rev`, `saved_at`,
  `doc`, newest first, none for a built-in), `POST /v1/scenes/{id}/revert`, and the state's `Scene`
  section declaring `spec`.
- audio-vue `src/control_commands.py`: `Command.reply()` spreads a done result into the answer; the
  bus registers `switch`, `reload`, `arm`, `cancel`, `saver`, `outcome` and no `reset`.
  `src/control_service/app.py` `_commands`: the routes answer the reply with its status's code.
- audio-vue `src/scene.py`: the switch result `{"scene", "capture", "why"}` (around line 1573),
  `_why_rebuild` (the capture rate first), `CaptureStack.why_not` (every analysis `Config` field but
  history depth, then a deeper history ring). `src/scene_model.py` `capture_rate_for`, `config`.
  `src/analyzer.py` `Config`, `Analyzer.reset()` (line 372) and its docstring.
- audio-vue `control-commands` ("A command says what happened", "Commands are refused unless a
  scene is drawing", "A switch is refused during a calibration", "A switch names a scene on the
  roster", "The last scene switched to comes back") and `scene-reload` ("A reload re-reads the scene
  on screen", "A reload says what it cost"), in full.
- `SceneEditor.swift`: `commit(_:_:)`, `registerUndo`, `detach()`.
- `PanelState.swift` `init(_:)`: keeps `sections.scene?.name` only. `PanelWindow.swift`: `live` is
  made in a `.task` and handed to `PanelPage` alone. `PanelPage.swift`: Status is built by
  `ConnectionStatus` and the page's rows.
- Tasks 6.1 to 10.2 were read against the code above. `SceneEditorUndoTests` and `PanelStateTests`
  exist. `HostClientCommandsTests` is new.

## Findings

- **F1. Kept edits drop every card's settings** (resolved)
  - Plan: the first draft assumed a kept layout could be turned back into a document from any parse.
  - Code: `LaidOutScene.init` gives cards new ids on each parse, and three callers pair a kept layout
    with a different parse: `SceneEditorView.make` into `SceneRendering`, `ScenesPage.drawThumbnails`,
    and `SceneDrafts.duplicate` from `SceneGallery.menu` and `SceneEditorView.duplicate`. Every card
    then loses all but `card`, its cells and group.
  - Goes to: requirement (the `scene-canvas` delta states that a kept edit keeps each card's entry),
    design D1, and tasks 1.1 and 1.2.
  - Resolution: written into the plan before review. It is a fix to existing behaviour that Save
    would otherwise write to the host. Reported to the maintainer with the plan.
- **F2. The proposal cited `control-api` for refusals it does not state** (resolved)
  - Plan: Impact said `audio-vue:control-api` gives the routes' answers and refusals.
  - Code: `control-api` states only that the routes exist ("Scenes, install blocks and images have
    routes"). The stale and validation refusals are `settings-store`'s, and the codes and bodies are
    in the saved contract alone, which `host-contract.md` ranks level with audio-vue's specs (the
    maintainer's ruling of 2026-11-05).
  - Goes to: proposal.
  - Resolution: Impact reworded.
- **F3. An editable title may write on every keystroke** (resolved in design, measured in the build)
  - Plan: the editor's title renames at once.
  - Code: Apple's documentation for `navigationTitle(Binding<String>)` says the title is editable on
    macOS and puts Rename in the title menu. For iOS it says the binding updates as the user types,
    and it does not say what macOS does.
  - Goes to: design D7 and task 4.2.
  - Resolution: the setter commits once when the field ends editing, if macOS sets it per keystroke.
    Task 4.2 measures it and checks that one rename makes one `PUT`.
- **F4. The unsaved mark cannot be in a bound title** (resolved)
  - Plan: the editor's title reads "*name* — Edited".
  - Code: with F3's binding the title is the name, so a suffix would be written back as part of it.
  - Goes to: design D7 and task 4.1. The spec says "the editor's title" marks it, and the subtitle
    sits in the title area.
  - Resolution: `navigationSubtitle("Edited")`.
- **F5. `SceneDraftsTests` already exists** (resolved)
  - Plan: task 1.1 called it new.
  - Code: three tests use `keep`, `layout(for:)` and `duplicate(_:)` as they are today.
  - Goes to: task 1.1.
  - Resolution: task 1.1 updates them.
- **F6. The found-panel choice is in `PanelWindow`, not `PanelPicker`** (resolved)
  - Plan: design D6 and task 5.1 named `PanelPicker`.
  - Code: `PanelPicker` takes a `choose` closure, and `PanelWindow.picker` supplies it.
  - Goes to: design D6 and task 5.1.
  - Resolution: both name `PanelWindow.picker` and `AddPanelSheet`'s `connect` closure.
- **F7. The inspector says a copy lasts until quit** (resolved)
  - Plan: none of the tasks touched it.
  - Code: `SceneInspector.kept` returns "In this app until it quits" for a copy.
  - Goes to: task 4.1.
  - Resolution: "In this app until saved".
- **F8. A reconnect to the same panel drops every draft today** (resolved)
  - Plan: the spec says connecting to the same panel again keeps unsaved scenes.
  - Code: `ScenesPage.load()` calls `store.forget()` on every `PanelKey` change, and `isPaired` passes
    through nil on any connect.
  - Goes to: design D6 and task 3.3.
  - Resolution: `SceneStore` forgets only when `HostConnection.host?.id` differs.

- **F9. The switch's result is not in the contract** (answered by audio-vue, not yet built)
  - Plan: Apply reports whether capture was kept or rebuilt, and why (maintainer, 2026-11-07).
  - Code: audio-vue sends `scene`, `capture` and `why` in a done answer (`Command.reply()`,
    `scene.py`), but `contract.Outcome` declares only `status` and `reason`. `control-commands` says
    the caller hears them, and names no fields.
  - Goes to: audio-vue (the console's handoff, ask 1), design D8 and task 9.1.
  - Resolution: audio-vue answered on 2026-11-07, decided and not yet built, in its change
    `command-results-and-reset`. `switch` and `reload` get answer models of their own (planned as
    `SwitchOutcome` and `SceneOutcome`), not optional fields on `Outcome`. A done switch also carries
    `recorded`. The report mentions `recorded` only when false (maintainer, 2026-11-07). D8, task 9.1
    and the `scene-apply` spec are updated. The handoff was deleted after reading.
- **F10. Apply needs no reload** (resolved)
  - Plan: `product.md` describes Apply as saving and calling reload.
  - Code: `control-commands`, "A switch names a scene on the roster": a switch to a stored scene's id
    puts up its current revision. `scene.py` builds the scene on every switch, with no check for the
    scene already on screen (read 2026-11-07).
  - Goes to: design D8.
  - Resolution: Apply is a save, then a switch. The app needs no on-screen state to choose a command.
- **F11. `product.md`'s line on Apply** (resolved)
  - Plan: Save stores, Apply saves and switches, Revert discards unsaved edits, Versions restores
    kept revisions (maintainer, 2026-11-07).
  - Code: `product.md`, "The app", said Apply saves a revision and calls reload, with revert one
    click away (Recommended).
  - Goes to: `product.md`, edited only with the maintainer's approval.
  - Resolution: the maintainer approved the new wording on 2026-11-07, and the line was edited.
- **F12. There is no reset command** (deferred to audio-vue)
  - Plan: a Reset button in the editor and on the Panel page (maintainer, 2026-11-07).
  - Code: `Analyzer.reset()` exists and its docstring names a future manual control, but no command
    or route reaches it. Reload is not a reset: it keeps capture and history wherever a switch would
    (`scene-reload`, "A reload says what it cost").
  - Goes to: audio-vue, through the handoff (ask 2, with what a reset clears, whether a calibration
    refuses it, and whether it wakes the display), and task 9.2.
  - Resolution: asked 2026-11-07. Task 9.2 waits on the route. What a reset restarts is audio-vue's
    to state. The maintainer expects history to be dumped as well, which the handoff passes on.
- **F13. Undo across a change of parse would lose card settings** (resolved)
  - Plan: Revert is undoable, and a version loads like an edit.
  - Code: `SceneEditor` registers bare layouts for undo (`commit`, `registerUndo`). A layout only
    turns back into a document through the parse it came from (F1), so undoing past a version load
    would pair one version's cards with another version's document.
  - Goes to: requirement (`scene-saving`: Revert is undoable unless it leaves an earlier version, and
    choosing a version starts the undo history afresh), design D9, tasks 6.1 and 6.4.
  - Resolution: written into the plan the maintainer asked for on 2026-11-07, and reported with it.

- **F14. audio-vue's coming change touches specs this plan relies on** (open until group 9)
  - Plan: Apply and Reset rely on `control-api`, "A command says what became of it",
    `control-commands`, "A command says what happened" and "The last scene switched to comes back",
    and `scene-reload`.
  - Code: audio-vue's `command-results-and-reset` will add contract lines beside those requirements,
    and the reset command. `openspec list --store audio-vue` showed no active change on 2026-11-07,
    so there are no deltas to read yet.
  - Goes to: tasks, group 9's opening line.
  - Resolution: before group 9, read that change's deltas, or the archived specs, against D8, D11
    and tasks 9.1 and 9.2.

## Questions for the maintainer

None open. The rulings taken on 2026-11-07: a copy stays in the app until its first Save; Rename
writes at once; a quit or switch with unsaved scenes asks; Save stores and Apply saves and switches;
Apply covers this panel's shape, built-ins included, asks nothing first and reports after; Revert
discards unsaved edits only; Versions loads a kept revision as an edit under the current name; saving
the scene on screen notes that the panel is behind; Reset sits in the editor and on the Panel page;
one change; the asks to audio-vue go as a handoff. F1 and F13 change or limit behaviour the maintainer
has seen, and are reported with the plan for review, not as questions.

The plan's own recommendations, open to correction in review rather than asked: a stale save offers
Save Over It and Discard Mine (D5); a stale rename retries once without asking (D5); Delete is
confirmed; an empty name is refused; Reset asks nothing first; the Reset button is hidden until the
route exists (D11).

## Confirmed

- Create, write and delete are in the saved contract with the bodies and refusals the plan maps
  (D2). Delete's 409 carries a `Refusal` whose detail is worded for people.
- A stored scene's name is its document's `name:`, so a rename is a write (audio-vue `_name`,
  `settings-store` "Scenes the host stores never shadow a built-in").
- The host accepts a name another scene has, so the app need not refuse duplicates
  (`settings-store`, its scenario on a built-in's display name).
- Writing never changes the screen (`settings-store`, "A write leaves the screen as it is").
- A stale write is refused with the current revision, and a delete is refused for the scene on
  screen and the boot scene (`settings-store`).
- audio-vue has no open change that could move these under the plan, and none names a spec this
  change modifies.
- 401 reaches `.tokenRefused` centrally for any new call (`HostClient.call`, `HostRules`).
- `FakeTransport` answers by method and path, so the write tests can tell POST, PUT and DELETE
  apart.
- `HostConnection.host` is public and holds the paired host's id (D6).
- `SceneLayout` equality includes card ids, so "unsaved is `layout != laidOut.layout`" holds only
  within one parse, which D1 guarantees.
- Held items: `pitfalls.md`, "Identify scenes by spec, never by name". The plan writes and deletes by
  id alone. `pitfalls.md`, "SwiftUI's undo manager is not there in `init`": `detach()` clears undo
  when the editor closes, so "undo back to saved" applies within one opening. This matches D3's
  note that undo does not survive a reopen. `open-questions.md` holds nothing on scenes.
- A switch is refused during a calibration and on the audio-vue screen, each with a reason, and the
  `Outcome`'s five statuses map to four codes (`control-commands`, `control-api`, the saved contract).
- The last scene switched to becomes the panel's boot scene (`control-commands`), so an applied scene
  is refused for delete until another is applied. The spec's delete refusal covers it.
- The revisions route gives whole documents in one request, newest first, so the Versions menu
  needs no read per entry.
- The contract's `Scene` section declares `spec`, so `PanelState.sceneSpec` reads a declared field
  (D10).
- `SceneEditor` is 204 lines and `PanelScenes` 126. With D8 to D11 each stays under the gate's
  300-line type limit, by the tasks' scope.
- Card deletion on the canvas (`scene-canvas`, "Delete removes the selection") is a key in the
  editor. Scene deletion is a gallery menu item, so the two do not collide.
