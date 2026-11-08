# Design

## Context

See `proposal.md` for why. The state today, read on 2026-11-08:

- **The page.** `PanelSection.calibration` routes to `SketchCalibrationPage` (`Sketches/`), sample
  values and a Calibrate… button that does nothing. The Panel page's Calibration section shows the
  status and age from `PanelState`, which keeps only `calibrationStatus` and `calibrationAgeDays` of
  the contract's `Calibration` section (`status`, `run_id`, `age_days`, `schedule_version`,
  `detector_schedule_version`, `trim_db`, `noise_floor_dbfs`, `lifecycle`).
- **The contract.** `GET /v1/runs` answers `Runs` of `RunEntry` (`run_id`, `has_report`), newest
  first. `GET /v1/runs/{id}` is the record as an open object, and `GET /v1/runs/{id}/report` is
  `text/html`. `POST /v1/commands/arm` takes `Arm` (`stated`, an object of numbers and words, `kind`
  the one word) and `POST /v1/commands/cancel` takes nothing. Both answer `Outcome`. `HostClient`
  calls `switch` and `reset` through `HostClient+Commands`, with `CommandOutcome`. Nothing serves a
  stimulus or a run's audio; `control-api` rules out serving audio today.
- **The lifecycle.** The `lifecycle` word is the calibration product's state, read in audio-vue's
  `src/products/calibration.py` and `src/scene.py`: `off`, `arming`, `waiting`, `running`,
  `analysing`, `done`, `failed`, `expired`. The contract declares it as a plain string.
- **Records.** A run's id is its UTC start, `2026-10-25T23-16-08Z`. A record's top level has
  `applied`, `rate`, `role`, `run_id`, `schedule_version` and more, but the listing carries none of
  them. A checkout's copy of the runs holds about 800 (1,599 files in `calibration/runs/`, measured),
  so the host holds at least that many.
- **The rate.** A calibration runs at the installed capture rate by default (audio-vue
  `calibration-stimulus`), the install's `input.rate`, else the analyser's default inside the host
  (`scene_model.installed_rate`). A scene can capture at its own rate (`capture_rate_for`), so the
  live `capture.rate_hz` is not always the installed rate.
- **Reports** are one self-contained HTML file each, about 77 KB, with no script, stylesheet or image
  loaded from elsewhere (measured on `2026-10-25T23-16-08Z.html`).
- **cal-play** (`../audio-vue/cal-play/`, Rust, no dependencies) takes `devices`, `rate <name> [hz]`
  and `play <name> <wav> [n]`. A device is the one whose name contains `<name>`, case-insensitively.
  Every failure exits 1 with its reason on standard error. `rate` holds `SETTLE_S`, 12 s, after a
  change. Built with `~/.cargo/bin/cargo build --release`; `cargo` is not on `PATH`.
- **Children.** `HelperProcess` runs the render helper behind `HelperLauncher` and `RunningHelper`,
  so tests script one. A sandboxed app's child inherits its sandbox and sees only the app and its
  container (`pitfalls.md`). The app is sandboxed with user-selected files read-only.
- **Sizes** (computed from the WAV headers, 2026-11-08): a calibration's file is 7.0 MB and 12.2 s
  at 96 kHz (24-bit stereo), 19.8 s at 48 kHz; a characterization's was 197.5 MB and 342.9 s at
  96 kHz on 2026-11-01, and renders at 219.9 MB today, so its length has moved since.
- **The writer.** `tools/calibrate.py --write` calls `calibration.make_schedule(rate=,
  maximum_dbfs=, internal_folding_hz=, kind=)` then `calibration.write_wav(path, schedule)`, with
  `PRESUMED_MAXIMUM_DBFS` where no maximum is stated. `src/calibration.py` is in the render bundle
  (`local/render-bundle/manifest.json`), so under its digest; `tools/` is not. The output is
  deterministic: a calibration at 96 kHz rendered today is byte-identical to `local/calibration-96k.wav`.
  Timed on this Mac from the checkout's venv: 1.3 s for a calibration, 5.9 s for a characterization,
  interpreter start included. From the sandboxed app through the bundled helper (task 6.2,
  2026-11-08): 1.4 s for a calibration, helper start included, and 6.2 s for a characterization,
  each file byte-identical to `--write`'s (7,027,244 and 219,915,734 bytes).
- **The render helper's protocol** (`src/render_service.py` `handle`) has `hello`, `prepare` and
  `render`, answered one at a time; anything else answers `no such request`.
- **The installed rate.** The app already reads `GET /v1/install` and `GET /v1/schema` in
  `PanelScenes.load()`. The Panel page's Rate row is the live `capture.rate_hz`. The schema declares
  `install.input.rate` with no `default`; its help says "unset is 48,000 Hz", though
  audio-vue's `settings-schema` says every setting is exported with its default.
- **The host's identity.** `HostConnection.host` (`HostIdentity`) carries the host's `id` once
  connected; no `GET /v1/host` call exists in `HostClient`.

## Goals / Non-Goals

**Goals:**

- One run's steps, its cancel and its endings decided in `ConsoleCore`, held by tests with a scripted
  player, a fake transport and scripted states.
- Nothing large held in memory: the stimulus is written to a file by the helper and played from it.

**Non-Goals:**

- Deleting runs, or their audio. Records are the instrument's history and not the agent's to change
  (`control-api`).
- Reading a record's figures in native views. The report is the reading.
- Saving a run's audio. audio-vue serves none (`control-api`, "A run is named, never pathed"), and
  the maintainer keeps that ruling (2026-11-08); `make cal-fetch-audio` fetches it from the host.
  Re-analysing it stays `tools/calibrate.py --reanalyse`'s.
- The chain-setting warning that calibration no longer applies (`product.md`). It belongs with the
  Input page.
- Windows. `cal-play` has no Windows backend yet.

## Decisions

### D1. cal-play is built by a build phase and run like the render helper

A build phase, "Build and embed cal-play", runs a script that builds `../audio-vue/cal-play` in
release with `~/.cargo/bin/cargo` (or `CARGO`), into this repo's `local/cal-play-target`, and copies
the binary to `Contents/Helpers/cal-play`, where Xcode signs it with the app. It fails with how to
fix it when the checkout or `cargo` is missing. Its `input-paths` name `cal-play/src` and
`Cargo.toml`, so Xcode reruns it only when they change.

In `ConsoleCore`, a `CalibrationPlayer` runs it through a `PlayerLauncher` seam, as `HelperProcess`
does the helper: arguments in, the exit status and standard error out, ended by terminating it. One
runs at a time. The app quitting terminates it.

*Alternative:* reimplement playback in Swift on CoreAudio. Rejected: the maintainer ruled the app
does not reimplement it, and only `cal-play`'s float32 path was measured bit-perfect. *Alternative:*
link `cal-play` as a library. Rejected: it has no library surface, and making one is audio-vue's.

### D2. The app lists output devices itself and passes cal-play the full name

The Calibrate sheet lists this Mac's output devices by name, read from CoreAudio behind an
`OutputDevices` seam in `ConsoleCore`, not by parsing `cal-play devices`, whose output is for people.
The device chosen is remembered per panel, by `HostConnection.host`'s `id`, as its CoreAudio UID
and its name. A remembered UID not present chooses nothing. The full name is what `cal-play`
receives.

*Alternative:* parse `cal-play devices`. Rejected: its layout is not a contract, and a change to its
wording would break the sheet.

### D3. A run is a state machine in ConsoleCore

`CalibrationSession` (`@MainActor`, `@Observable`) owns one run. It is the app's, held beside the
renderer in `AudioVueConsoleApp` and handed to `AppDelegate`, so closing the window does not stop a
run and a quit can reach it. Its step is one of `rendering`, `settling`, `arming`,
`armed`, `playing (time left)`, `measuring`, `analysing`, then `ended` with an ending:
`completed (run id, applied)`, `failed (reason, run id?)`, `expired`, `refused (reason)`,
`stimulusRefused (reason)`, `playerFailed (reason)`, `cancelled`. The app
shows the step. A second run is refused while one is under way.

Its order is the specs': render at the installed rate (D4), `cal-play rate <device> <rate>` to its
end, arm stating that rate, and on `done` `cal-play play <device> <file>`.
While `cal-play` plays, the step stays `playing` whatever the panel says, since the time left is the
user's clock, unless the panel's state names the run ended, which stops the player. The time left
comes from the WAV's header, frames over rate.

**The step comes from the lifecycle word; the ending never does.** Per audio-vue's reply and
`src/frame.py`'s `Calibration.state`: `waiting` is armed and listening, so `armed`; `arming` is the
marker heard, lasting about one 50 ms poll before `running`, so both are `measuring`; `analysing` is
`analysing`. `done`, `failed` and `expired` do not stay: `done` and `failed` hold until audio
returns, a cancel or a scene switch, then read `off`, and `expired` gives the panel back at once, so
the app may see `waiting` then `off`. The ending comes from `state.sections.calibration.ended`
(audio-vue's `calibration-from-the-app`, planned): `arm`, `outcome` (`done`, `failed`, `expired`,
`cancelled`), `kind`, `run_id`, `applicable`, `reason`, standing until the next arm lands. The
session keeps the arm's id from the arm's done answer (`ArmOutcome.arm`) and takes an ending only
where `ended.arm` is that id, so an earlier run's ending is never this run's, with no clock involved.
`done` is `completed (run id, applicable, reason)`: a `reason` there says which stimulus was missing
or that the report failed to write. `failed` and `expired` carry their `reason`; a failed run has no
record. `cancelled` ends the run cancelled, whoever sent the cancel, so a cancel from the panel's own
key does not leave the app waiting.

Cancel is the task's cancellation. Before the arm, it ends the step and arms nothing. From the arm
on, it terminates the player and sends `cancel`. A done answer ends `cancelled`, unless it says
`record_stands`, which means the run had completed: then the ending is `completed`. A refusal, `too
late -- the record is being written`, shows its reason and the session follows the run to its
ending. Every refusal is followed so, `nothing to cancel` included: the run then ended some other
way, and the panel's ended calibration says how.

*Alternative:* end a run on the lifecycle word. Rejected on audio-vue's reply: an expiry can pass
between two reads, and a failed run usually writes no record to find.
*Alternative:* drive the steps from the view. Rejected: the order and the cancel are the risky part,
and a view cannot be tested without the app.

### D4. The render helper writes the stimulus, from the panel's code

The app asks the render helper it already runs for the file, with a new `stimulus` request
(audio-vue's to add, `calibration-handoff-2.md`): kind, rate and a path in the
container's temporary directory. The helper runs `calibration.make_schedule` and `write_wav` there,
refusing what `calibration.check_stated` refuses, and answers when the file is whole. The player
reads the file from the container, which its sandbox allows. The session removes the file when the
run ends, however it ends.

Calibrate… is offered only while `CardCodeCheck`'s verdict is that the helper's digest is the
panel's. The whole digest, not the calibration modules' entries: the schedule reaches into shared
modules, and a run measured against another schedule is worse than no run.

The rate is the installed capture rate: `install.input.rate` from `GET /v1/install`, else the
schema's `default` for it (48,000 Hz, declared by `calibration-from-the-app`), both already read by
`PanelScenes`. The app holds no default of its own. The helper answers a stimulus refusal as
`refused`, with `calibration.check_stated`'s message, and any other failure as `error`, the shapes
`RenderHelper` already reads as `RenderFailure.refused` and `.failed`.

Nothing is cached. A render costs 1.3 to 5.9 s against a run of 12 s to about 6 min, and a cache
would need its own key and pruning.

*Alternative:* the host renders and serves the file (the earlier ruling). Replaced by the maintainer
(2026-11-08): the bundle already holds the writer, the digest check already proves it is the
panel's, and local rendering avoids a 220 MB download and a render on the Pi.
*Alternative:* run the bundled interpreter once per render on a script of the app's. Rejected: it
starts a second interpreter, and puts Python the console owns beside audio-vue's.
*Alternative:* read the live capture rate, as the Panel page shows it. Rejected: a scene can capture
at its own rate, and a calibration at that rate calibrates only it.

### D5. A report shows in a WKWebView that reaches nothing

The report's HTML is fetched by `HostClient` and handed to a `WKWebView` as a string, with no base
URL. A content rule list blocks every load, and a navigation delegate allows only the first load and
cancels every other navigation; a report has no links (audio-vue's reply, 2026-11-08). A report is
never cached.

*Alternative:* load the report's URL in the view. Rejected: the view would make its own request,
without the host's token, and around `HostRules`.

### D6. The runs list reads the listing only

The list shows each `RunEntry`: its date from the id, in the Mac's time zone, else the id; its kind,
from the listing's `kind` (maintainer 2026-11-08); and a report mark. No record is read for the list.
The listing's `applicable` ("fit to apply when written") is not shown; no ruling asks for it. The list is read again
when a run ends, and the run that ended is the one the state's ended-run field names (D3).

*Alternative:* read each record for its kind and outcome. Rejected: about 800 reads to show a list.
*Alternative:* find the new run by the listing's difference before and after the arm, retrying until
it has a report. Rejected on audio-vue's reply: a failed run usually adds no entry, so it waits for
nothing.
*Alternative:* take `run_id` from the live state's calibration section. Rejected: it names the
record in force, and a failed or unapplied run is never in force.

### D7. PanelState keeps the whole calibration section

`PanelState` keeps the run id, trim, noise floor and lifecycle beside the status and age. The
Calibration page's top section reads them, as the Panel page reads its rows, through a rows type
that decides the text and the dashes.

## Risks / Trade-offs

- [`cal-play` cannot set a device's rate from inside the sandbox] → The first task measures it with
  the bundled binary run from the sandboxed app, before anything is built on it. If CoreAudio refuses,
  stop and raise it with the maintainer.
- [A device whose name is contained in another's is refused by `cal-play` as ambiguous] → The app
  shows `cal-play`'s reason. If it happens on a real rig, ask audio-vue for an exact-name match first.
- [The lifecycle's words are read from audio-vue's code, not a contract] → Ask 3, accepted, declares
  them. A word the app does not know shows as the panel's word; no word ends a run (D3).
- [audio-vue's names may move while its change is built] → The plan takes them from its plan
  (`calibration-from-the-app`, 2026-11-08); task 6.1 reads them from the refreshed contract and
  bundle, and audio-vue's final reply names any that moved.
- [Building `cal-play` needs Rust on the build machine] → The phase says so and how to install it.
- [The app crashes while `cal-play` plays] → A crashed parent does not end its child, so the file
  plays on to its end, a characterization's several minutes, into a panel that measures it as usual. Accepted; a quit
  ends it (task 1.4).
- [audio-vue's change is not built] → The runs list and reports are built first on today's routes;
  the stimulus, the ending and the kinds wait for it, brought in by the contract and bundle refresh.
- [A render inside the sandbox is slower than measured, or blocks scenes] → The helper answers one
  request at a time, so a characterization's render holds scene renders for about 6 s; a run is not
  started from the editor, so this is accepted. Task 6.2 times both kinds from the sandboxed app.
- [A characterization's file fills the container's temporary directory] → About 220 MB, removed when
  its run ends; the session removes it on every ending.
