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

## Questions for the maintainer

None open. Three rulings were taken before the plan was drafted (2026-11-07): a copy stays in the app
until its first Save, Rename writes at once, and a quit or switch with unsaved scenes asks. F1 changes
behaviour the maintainer has seen (reopened scenes, thumbnails, Duplicate) and is reported with the
plan for review, not as a question.

The plan's own recommendations, open to correction in review rather than asked: a stale save offers
Save Over It and Discard Mine (D5); a stale rename retries once without asking (D5); Delete is
confirmed; an empty name is refused; Apply is out of scope.

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
- Card deletion on the canvas (`scene-canvas`, "Delete removes the selection") is a key in the
  editor. Scene deletion is a gallery menu item, so the two do not collide.
