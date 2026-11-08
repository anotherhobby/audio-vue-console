# The product

The product statement for audio-vue-console: what the app is, why it is native, and the rulings
behind it. Worked through in audio-vue on 2026-11-01 and moved here on 2026-11-02. The host side, the
agent, the store, the settings schema and what the console's rendering needs, is `../audio-vue/.claude/kb/agent/host-platform.md`.
What the app relies on from the host is `host-contract.md`.

**Edited only with the maintainer's approval.** Almost every line is a ruling. Propose the exact entry
at the moment it is needed, and wait.

Each claim says what it rests on:

- **Ruled**: the maintainer decided it.
- **Accepted**: a recommendation the maintainer went along with in general, without ruling on it by
  name. Check before leaning hard on one.
- **Measured** or **Read**: run, or read at a line, on the date given.
- **Recommended** or **Inferred**: this project's reasoning, not proven.
- **From memory**: general knowledge, not checked here.

## The decision

Ruled, all (maintainer, 2026-11-01):

- The control surface is a desktop app, not a web UI. The network API stays, because the app still
  has to reach the host. Only the browser front end is gone.
- audio-vue is 100% configurable through the app: new scenes, every scene setting, and adding,
  removing and arranging cards by drag and drop on a customizable grid. No text editing, manual SSH
  or uploading in daily operation. Install, setup and initial configuration may still need them.
- The app is SwiftUI, in its own repository.
- Host-side settings live in a SQLite store on the host, under a versioned schema.
- Cards were rendered by the host (2026-11-01); replaced 2026-11-06 by the three rulings below.
- Modern drag and drop is a hard requirement. A literal flip between panel and console is not: it
  was a mental picture, not a requirement.

Ruled, all (maintainer, 2026-11-06), replacing the line on cards:

- **The console renders the scene locally, from the real card code. The host renders nothing for
  it.** Rendered on the host, every canvas edit was a round trip to the panel, and a scene-wide type
  change re-rendered every card there before anything showed. The desktop app was chosen partly to
  run audio-vue's Python locally, which a browser cannot.
- **The card code is bundled into the app when it is built, never downloaded from a host.** The app
  runs no code it received over the network.
- **The card code's version is a checksum manifest**: a SHA-256 for each card's directory, each
  shared module the render path imports, each font and each asset, plus one SHA-256 over the whole
  manifest. The handshake compares that one digest with the host's, as it compares the API version;
  only on a mismatch does the app fetch the host's manifest and name each entry that differs. A card
  whose own entry differs is drawn as a plain box with its name, and the rest render. A shared entry
  that differs renders no card. So the console never presents a picture the panel's code did not
  produce, and even an edit to a comment counts as drift until the app is rebuilt. SHA-256, not MD5:
  the host's store names images by it, audio-vue's Sonar gate flags `hashlib.md5`, and CryptoKit has
  MD5 only as `Insecure.MD5`.

Porting cards to Swift or Metal stays ruled out: two renderers drift, and the card carries the
standard.

Ruled (maintainer, 2026-11-07):

- **The console makes each scene's frame itself.** The helper runs the panel's own analysis over 32 s
  of music generated in code, under the scene's analysis block and rate, and keeps the frames for its
  life. More card text will follow analysis settings, so no fixed frame would do. The bundle therefore
  holds the analysis, performance weighed above its size.
- **The render helper starts once the app is paired, and makes its first frame at a fixed preview
  rate** (replacing, the same day, "the first frame is made behind the console's launch screen"; the
  rate does not matter to a preview). A Renderer row under the Panel page's Status says it is
  starting, with a working indicator, until its first frame is made. There is no launch screen.
- **The app carries a portable CPython and audio-vue's render bundle**, and runs the helper as its
  child process, out of the Dock. The helper keeps its compiled-code cache in the app's container.

## The model: an appliance and its companion

The panel's host is an appliance, and the app is its companion, in the manner of Sonos or UniFi
(Accepted). All truth is on the host, and the app holds almost none. Two rules follow, and most
decisions are one of them applied:

- **If it would need porting to Windows, it belongs on the host** (Accepted). This keeps the app
  thin, so a port is mostly a generic inspector and a canvas.
- **The app knows only the API.** It reaches a panel by address and the API alone, and never
  assumes which panel it is talking to or where that panel runs (Ruled). A separate repository
  enforces this mechanically.

## Why not a web UI

- **Calibration decides it.** `cal-play` sets the device's rate and verifies it took, which is
  what stopped the D10s resampling a 48 kHz file at 192 kHz (`../audio-vue/.claude/kb/agent/cal-play.md`).
  Its float32 path was measured bit-perfect, and that holds only at unity gain. A native app can
  bundle it. No browser API that sets the device's rate turned up in a quick search, which is an
  absence from a search and not a reading of the Web Audio spec. This is the argument an audio
  engineer would accept.
- **A web UI gives no special powers.** The hosts run a desktop OS anyway, and a page is the more
  constrained of the two.

What the web UI would have given, and the app gives up:

- **Phones and tablets.** Ruled out: no browser front end and no phone surface. A page could be
  added later, since the API stays.
- **Automatic version matching.** A page ships with its host. The app can fall behind the host, so
  it checks versions on connect.
- **No install.** The app has to be packaged and allowed past Gatekeeper.

## What runs where

```
App (Swift) ── HTTP/WS /v1 ── agent ─┬─ link ──── panel (capture / analysis / drawing)
                                     ├─ supervisor
                                     ├─ store ←── panel reads at start and on a switch
                                     ├─ calibration/ files
                                     └─ workers (validation)
```

The app runs on the user's machine, as a client of the agent's API, with `cal-play` bundled.
Everything right of the API is audio-vue's.

## The app

Ruled: SwiftUI, the maintainer reviewing by behaviour and screenshots.

Python in the app is for running cards, as a bundled runtime driving audio-vue's render helper
(2026-11-06; host rendering had removed it for five days). Qt was only for the flip, and the
maintainer dropped it. Tauri was the honest alternative, with one codebase
and strong drag libraries, and was passed over for the native Mac feel. From memory: SwiftUI's canvas
gestures will need custom work for snap, resize and groups, so a two-day canvas spike against a stub
host comes first (Recommended).

- **The app draws** the grid, the handles and the drag, over layers audio-vue's card code renders
  inside the app (2026-11-06). Each card's inspector (generated from the settings schema) and its
  information page still come from the host.
- **Structure** (Recommended): `project-map.md`.
- **HTML reports** stay HTML, shown in a `WKWebView` (Recommended).
- **Finding panels.** Type an address first, and add Bonjour later, since Bonjour is a new thing for
  the host to run (Recommended).
- **Saves are explicit.** Hosts boot from SD cards, so nothing writes per drag (Recommended).
- **No live preview** (Ruled). Nothing follows edits on the panel. The app can have a preview button
  that hands rendering back to the panel to show the scene running (Ruled). That button is Apply: it
  saves the open scene and puts it on the panel. Save stores without changing the panel, Revert
  discards unsaved edits, and earlier versions are restored from the host's kept revisions (Ruled,
  2026-11-07).
- **Scenes are tied to a display shape** (Ruled), the grid's `cols:rows`. The app offers "duplicate
  for this panel" where a scene's shape does not match (Recommended).
- **Built-in scenes are read-only**, shown with "duplicate to edit" (Ruled, 2026-11-02).
- **Backup is the app's job** (Ruled): versioned and dated, a copy of the host's store and its
  calibration records, since a user's scenes otherwise live only on an SD card. A backup leaves out
  paired clients' credentials (Recommended).
- **A setting's class changes what the app says** (Ruled): a measurement setting off its standard's
  values is flagged, and a chain setting warns that calibration no longer applies.
  `host-contract.md`, "Settings".

## Calibration

Ruled end game: open the app, hit calibrate, and it arms the panel and plays the audio itself,
replacing `make calibrate`.

- **Order.** Set the rate, let the chain settle, then arm. `pitfalls.md`.
- **Where it runs.** The app can calibrate only from the machine feeding the panel, and it has to
  say so. This matches audio-vue's rule that the source host triggers the panel.
- **Bundling.** `cal-play` (Rust, `../audio-vue/cal-play/`) goes in the app as a helper binary
  (Recommended).

## Packaging

Ruled: no paid Apple Developer account for now, not ruled out for later, and not a blocker. The app is
ad-hoc signed and `spctl` rejects it, so a downloaded copy needs allowing in macOS's security settings,
and we provide instructions. The maintainer has verified that network, CoreAudio and the other access
the app uses all work without an account. From memory: on Sequoia that is "Open Anyway" per app, so a
downloaded update may need it again.

## The quality gate

Accepted, and built before the first Swift file so all of the app is held to it: the
`quality-gate` plugin's Swift backend (`../claude-qualty-gate`), which holds the rules and wins over
this list. Its philosophy is the Python gate's: checked at edit time, placed against `HEAD`, size
rules that cannot be silenced inline, a written case only the maintainer approves, pinned tools,
fail open. A change to the plugin reaches every project, so it is asked for first.

- **Limits:** cognitive complexity 10; cyclomatic 8, with `switch` cases not counted; function or
  closure body 40 lines; a view's `body` 30; 5 parameters; nesting 2 for types and 3 for functions; a
  type 300 lines; a file 400 (raised from 200 and 300, maintainer, 2026-11-07). Magic numbers are
  allowed in tests and inside a `#Preview` block.
- **Never, and not keepable:** force unwraps, `try!`, `as!`, implicitly unwrapped optionals, any
  `try?` (maintainer, 2026-11-02), `@unchecked Sendable`, `nonisolated(unsafe)`, magic numbers,
  commented-out code, any `swiftlint:disable`.
- **Compiler:** Swift 6 mode, which brings strict concurrency, with warnings as errors.
- **Style:** swift-format at 4 spaces and 100 columns, unless this repository adds a `.swift-format`.
- **Second tier:** the Sonar server has no Swift analyser (Measured, 26.9's language list).
  `swiftlint analyze`, Periphery and the tests stand in for it.

## Later

- **Meter mode** (Ruled: postponed, the console first). A windowed panel on the user's own Mac, fed
  live through CoreAudio: a bundled Python panel and agent at a local address, one "This Mac" entry
  in the panel picker, which is exactly the address rule (Recommended). It is a different instrument
  from the panel, so it carries its own calibration state and says when it has none. The host side
  is `host-platform.md`, "Meter mode".
- **Windows.** The maintainer has a Windows machine to test on. A console there is a second app
  against the same API, ported by agent rather than shared code, since SwiftUI does not cross; the
  host rule is what makes that cheap. Calibration needs a Windows backend for `cal-play`, parked late.
- **Remote live view.** Wanted possible, not promised, and not planned. It needs a ruling on the
  audio path first, on the host (`host-platform.md`, "Remote live view").
- **Touch** is on the panel, not in the app, and needs no network API.

## Open

- Whether software updates go through the app. TLS comes before the API can update software (Ruled).
