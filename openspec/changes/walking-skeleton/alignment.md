# Code alignment

## Read

Pass 1, 2026-11-03.

- `proposal.md`, `design.md`, `tasks.md` and both spec deltas, re-read from disk.
- `audio-vue:control-api`, in full (`openspec show control-api --type spec --store audio-vue`): "The
  API states its version", "The API serves no browser", "The API is one published contract", "The
  announcement is part of the contract".
- `audio-vue:control-service`, in full: "Reads are open and changes take a token", "A client pairs by
  a code on the panel".
- `audio-vue:host-store`, "What the store holds": the port takes a default, unnamed.
- audio-vue's open changes (`openspec list --store audio-vue`): `settings-store` only. Its deltas
  (`--deltas-only`) to `control-api` and `control-service`, and its proposal's Impact.
- The host's contract, saved from the proving host on 2026-11-02 (`openapi.json` in the session
  scratchpad): `/v1/version` and its `Version` schema.
- `../audio-vue/src/host_store.py:36`: `DEFAULT_PORT = 19200`. `../audio-vue/installer.md:105`
  uses the same port.
- `AudioVueConsole.xcodeproj/project.xcproj`: deployment target, sandbox and outgoing network,
  `GENERATE_INFOPLIST_FILE`, no `INFOPLIST_FILE`, the synchronized `AudioVueConsole` folder, and
  main-actor default isolation with approachable concurrency on the app target.
- `AudioVueConsole/`: `MyApp.swift` (shows `SketchShell`), `ContentView.swift` (template, unused),
  `Sketches/` (nine Swift files and `sketch.json`).
- Searched `AudioVueConsole/`, the Xcode project, the KB and the change for `URLSession`,
  `import Network`, `import AppKit`, `ContentView` and `MyApp`.
- `.claude/kb/agent/`: `open-questions.md` (empty), `pitfalls.md`, `project-map.md`,
  `commands.md`, `host-contract.md`, and `product.md` on version checks and the quality gate.
- A probe package in the scratchpad, built and tested with `swift test` on Swift 6.4.2: tools 6.2,
  `.macOS("27.2")`, `.treatAllWarnings(as: .error)`, `swiftLanguageModes: [.v6]`, Swift Testing,
  and a `@MainActor @Observable` class in the library. All of these passed.
- Xcode 27.2's bundled project prototypes and `DevToolsCore` strings, looking for how
  `project.xcproj` writes a local package. No example was found.
- Every task, 1.1 through 6.2, was read against the code as the tasks before it leave it.

## Findings

- **F1. The proposal's Impact named no referenced spec by id** (resolved)
  - Plan: Impact said the app relies on `control-api`, in prose.
  - Code: the project rule asks for `<store>:<spec-id>`.
  - Goes to: proposal.
  - Resolution: Impact now names `audio-vue:control-api` and `audio-vue:control-service`.

- **F2. `settings-store` changes both referenced specs** (resolved)
  - Plan: relies on the version being an open read, its fields, and the `Origin` refusal.
  - Code: `settings-store` modifies `control-service`'s token requirement to "Everything but pairing
    and the version takes a token". It keeps `/v1/version` open, by name. It modifies `control-api`'s
    contract requirement (the OpenAPI document is served only to a paired client) and its
    announcement requirement. It does not touch "The API states its version" or "The API serves no
    browser".
  - Goes to: no change to the plan.
  - Resolution: nothing the skeleton relies on moves. The served contract going behind a token
    matters to the panel client change, and is already in `host-contract.md`. `settings-store`'s
    Impact names this app but none of its specs, and there are none yet, so the second rule raises
    nothing.

- **F3. The contract does not require `schema`** (resolved)
  - Plan: the client decodes `{api, schema}`.
  - Code: the `Version` schema requires only `api`, types `schema` as integer or null, and allows
    more fields.
  - Goes to: design and task 3.1.
  - Resolution: `schema` is decoded as optional, and a missing field reads as null. Unknown fields
    are ignored. Task 3.1 tests a body without `schema`.

- **F4. No spec states the default port** (resolved, Q3)
  - Plan: the `host-connection` requirement uses 19200 as "the host agent's default".
  - Code: `audio-vue:host-store` says the port "takes defaults" without naming one. The value is
    `DEFAULT_PORT` in `src/host_store.py` and appears in `installer.md`.
  - Goes to: requirement (its source), and audio-vue's spec.
  - Resolution: the maintainer kept 19200 (2026-11-03). The requirement's Source cites the code
    and `installer.md`, and the maintainer asks audio-vue's session to name the default in
    `host-store`.

- **F5. The window now shows the UI sketch, which the plan does not know about** (resolved, Q1)
  - Plan: task 5.1 replaces `ContentView` with the connect view. The design says "the app target holds
    only the `App` and one view", and a risk says it "holds two small files".
  - Code: `MyApp` shows `SketchShell` and sizes the window from `SketchMetrics`. The app target holds
    nine sketch files. The gate's type check does not build them; SwiftLint and swift-format do check
    them.
  - Goes to: design and task 5.1.
  - Resolution: the maintainer ruled (2026-11-03) that the connect view is the window and the sketch
    a second window, under `#if DEBUG`, opened from the Window menu. The design and task 5.1 say so,
    and the risk now separates the real shell from the throwaway sketch.

- **F6. How `project.xcproj` writes a local package is unknown** (resolved, Q2)
  - Plan: task 1.2 adds the package in Xcode, or by editing `project.xcproj` "once its package
    format has been checked against a real example".
  - Code: no example exists on this machine. Xcode MCP has no tool that adds a package. The strings
    in Xcode show related keys (`package-product-members`, `up-to-next-major-version`) but not the
    structure. Editing by guesswork would leave apply waiting on a decision mid-build.
  - Goes to: task 1.2.
  - Resolution: the maintainer adds the package in Xcode once task 1.1 has made it (ruled
    2026-11-03). Task 1.2 is that hand-off, then a build through MCP, then recording the format in
    `project-map.md`. It is the one planned pause in apply.

- **F7. The package's default isolation differs from the app's** (resolved)
  - Plan: unsaid.
  - Code: the app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION` to `MainActor` with approachable
    concurrency. A package defaults to nonisolated.
  - Goes to: design.
  - Resolution: the core keeps the default. The model is marked `@MainActor`, and its value types are
    `Sendable`. The probe confirmed that a `@MainActor @Observable` class builds and tests in such a
    package.

- **F8. Task 1.1 named the platform loosely** (resolved)
  - Plan: "macOS 27, warnings as errors".
  - Code: the app's deployment target is 27.2. The probe showed the exact forms that build.
  - Goes to: task 1.1.
  - Resolution: task 1.1 names tools 6.2, `.macOS("27.2")`, `.treatAllWarnings(as: .error)` and
    `swiftLanguageModes: [.v6]`.

- **F9. The local network prompt may outlast the 5 s timeout** (resolved)
  - Plan: the first connection's prompt was a risk, with a denial reported as unreachable.
  - Code: a 5 s request timeout can expire while the prompt waits for the user.
  - Goes to: design risk.
  - Resolution: recorded. Connecting again after answering the prompt is expected to work, and task
    6.1 records what happens.

- **F10. Unsaid: text with a scheme** (resolved)
  - Plan: "host[:port]".
  - Code: none yet. A user may paste `http://audio-vue:19200`.
  - Goes to: design.
  - Resolution: whitespace is trimmed, and a scheme or path makes the address invalid. That falls
    under the spec's "text that is not a hostname or IPv4 address".

- **F11. Renames reach the KB** (resolved)
  - Plan: task 5.1 removes `ContentView` and renames `MyApp`.
  - Code: the only references outside the files themselves are in `project-map.md`. Task 1.2's
    `import ConsoleCore` in `MyApp.swift` comes before the rename.
  - Goes to: task 5.1.
  - Resolution: task 5.1 updates `project-map.md`.

## Questions for the maintainer

All three were asked and answered on 2026-11-03, each with the recommended position.

- **Q1 (F5).** When the connect view arrives, what does the window show?
  - Ruled: the connect view is the window. The sketch is a second window, opened from the Window
    menu in Debug builds only.
- **Q2 (F6).** Who adds `ConsoleCore` to the Xcode project?
  - Ruled: the maintainer, in Xcode, after task 1.1. The agent records the format.
- **Q3 (F4).** The default port 19200 is in audio-vue's code and `installer.md`, not in a spec.
  - Ruled: keep it, cite the code, and ask audio-vue's session to name it in `host-store`.

## Confirmed

- `GET /v1/version` is an open read giving `api` and the state's schema, null where the panel does
  not answer (`control-api`, "The API states its version"; the contract's `Version` schema; measured
  `{"api":"1.0.0","schema":1}` on 2026-11-02).
- It stays open under `settings-store`'s token ruling (F2).
- Any `Origin` header is refused with 403 (`control-api`, "The API serves no browser").
- The app target is sandboxed with outgoing network connections allowed, and generates its
  Info.plist with no `INFOPLIST_FILE` set. A partial plist is therefore free to add.
- `AudioVueConsole/` is a synchronized folder. A plist kept outside it is not copied as a resource.
- No app-target source, sketches included, imports Network or AppKit or uses `URLSession`. The
  boundary test of task 1.3 starts green.
- Nothing outside `ContentView.swift` refers to `ContentView`.
- A package with the settings in task 1.1 builds and runs Swift Testing on this machine (probe).
- `pitfalls.md`'s held items have been checked against this change:
  - The `Origin` item is covered by the "Requests carry no Origin header" requirement.
  - The gate's SwiftPM-only type check is the reason for the design's package layout.
  - The rest (tokens, scene identity, the List crash) do not touch it.
- `open-questions.md` holds nothing.
