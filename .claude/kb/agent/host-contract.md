# The host contract

What the app relies on from the host, as a consumer. This is a view, and it drifts. The authorities,
in order: the running agent's `/v1/openapi.json`; audio-vue's specs `control-api`, `control-service`,
`host-store`, `control-state` and `control-commands` (`../audio-vue/openspec/specs/`); its open changes
`settings-schema` and `settings-documents` (`../audio-vue/openspec/changes/`); and
`../audio-vue/.claude/kb/agent/host-platform.md`. Check them before building against anything here.
The saved contract the app is generated from stands level with audio-vue's specs as a source for host
behaviour: what only it and the code state (the `/v1/events` message shape, 401 and Bearer, 403 and
1008) needs no spec before the app relies on it (maintainer, 2026-11-05).

Each item is **Built** (in audio-vue and running on the proving host) or **Planned** (an open change or
a ruling with no change yet). As of 2026-11-02; settings as of 2026-11-04, pairing as of 2026-11-05.

## Reaching a panel (Built, `control-service`)

- The host agent serves HTTP and a WebSocket under `/v1`, on port 19200 on every IPv4 interface by
  default; the host's own `tools/agent.py set` changes both.
- The contract is `/v1/openapi.json`. State is pushed on `/v1/events`. The agent polls the panel at
  4 Hz only while a client is connected or has just read.
- The panel is `up`, `down`, `stale`, `capture_stopped` or `no_audio`.
- The agent outlives the panel: after a stop it stays up and reports the panel stopped, and can start
  it again. It also gives start, stop, status, logs, run history (calibration runs by id), and the
  host's id, name, display size and capture devices.
- The API states its own version. The app checks it on connect, since it can fall behind its host,
  and takes only the saved contract's `info.version`, by its numeric core: any other is refused,
  newer or older (`APIVersion.compatibility`, `track-audio-vue`, 2026-11-08).
- The proving host runs Pi OS (since 2026-11-02; audio-vue ships an SD image by default, with manual
  install as an option). It answers as `audio-vue.local`, and the LAN's DNS names it
  `audio-vue.cabin.hobbysprawl.com`, or `audio-vue` by the search domain (Measured, 2026-11-03;
  the host was `audio-image` before). `GET /v1/version` answers `{"api": ..., "schema": ...}`
  (Measured, 2026-11-02). The contract requires only `api`, so treat a missing `schema` as null.
- Record no version numbers in this KB; they go stale. The saved contract, `GET /v1/version` and
  `make openapi` in `../audio-vue` say what is current.
- The agent's default port, 19200, is `DEFAULT_PORT` in `../audio-vue/src/host_store.py`; no spec
  names it (2026-11-03).

## Discovery (Built, `control-service`)

- The agent registers DNS-SD type `_audio-vue._tcp` with Avahi once it listens: instance named by the
  store's host name, at the bound port, TXT `id` (as `/v1/host`) and `api` (as `/v1/version`). Keys
  keep their names and meanings within an API version. Tell hosts apart by `id`, since an instance
  name can be renamed on a clash, and a reinstalled host gets a new id.
- Withdrawn when the agent stops; nothing announced when bound to loopback or with no responder.
  A typed address stays supported.
- The proving host announces `audio-vue` at `audio-vue.local:19200`, TXT `id` and `api`, seen on
  two interfaces at once (Measured, `dns-sd -B`/`-L`, 2026-11-06). Its id changed between 2026-11-03
  and 2026-11-06, as a reinstall gives; read it live, never from here.
- `tools/panel.py agent stop` withdraws it on both interfaces within a second, and `agent start`
  announces it again within a few seconds (Measured, `dns-sd -B`, 2026-11-06).

## Pairing and tokens (Built, `control-service`)

- `POST /v1/pairing` shows a six-digit code on the panel for 120 s and five wrong tries, one pairing
  at a time, and a 30 s wait only after a code is withdrawn for its wrong tries. `POST /v1/pairing/confirm` gives the token once. Pairing works
  even on the audio-vue screen, where a new host with no ADC sits.
- One token per client; the app stores one per panel. `GET /v1/clients` lists clients and
  `DELETE /v1/clients/{client_id}` revokes one (Read in the proving host's `/v1/openapi.json`,
  2026-11-02).
- Every route takes a token, `/v1/openapi.json`, `/v1/host` and `/v1/events` (by its handshake's
  `Authorization` header) included, except asking for a pairing code, confirming it, and
  `GET /v1/version` (Built: audio-vue `settings-store`, archived 2026-11-04; Measured on the proving
  host, 2026-11-04: `{"detail": "pair first: this takes a token"}` with a 401). So an unpaired app
  knows only the version and the TXT record; the display shape and the contract come after pairing.
- A request with any `Origin` header is refused: HTTP with a 403, a WebSocket closed with 1008
  (Read, `NoOrigin` in `src/control_service/app.py`, 2026-11-02; the spec words it as another site's
  origin, and the code is stricter). The app must send none. `pitfalls.md`.
- A refusal is `{"detail": "<reason>"}`, worded for people. Asking for a code answers 409 when one is
  showing, 429 with `Retry-After` in the wait after a withdrawn code, 503 when the panel cannot show
  it; confirming answers 403 for a wrong code and 409 when none is showing (lapsed or withdrawn). The
  contract names only these refusals per route and declares `Retry-After` as an integer of whole
  seconds, at least 1, not marked required, so a generated client sees it as optional (audio-vue
  `control-api`, "The contract states the pairing refusals"; Read in `make openapi`'s output,
  2026-11-05). A client's `paired_at` is ISO 8601 to the second, UTC.
- A wrong code costs one of the five tries and leaves the code standing; asking for a new code
  while it stands is refused with 409. Only a code withdrawn for its wrong tries makes the next
  pairing wait; a success or a lapse lets the next be asked for at once (audio-vue `control-service`,
  "Only a withdrawn code makes the next pairing wait", archived 2026-11-05). In audio-vue but not yet
  deployed to the proving host, which still waits after every end (Measured, 2026-11-04).
- HTTP is fine on a LAN. TLS comes before the API can update software.

## Scenes and commands (Built, `control-commands`, `scene-reload`)

- A scene is identified by its id, never its `name`, which is a label: a built-in's filename stem, or
  a stored scene's UUID (`settings-store`).
- The layout grid is the panel's display's, not the scene's (audio-vue `host-grid`, 2026-11-21): 36
  rows, and columns from the display's shape (96 on the proving panel), filling the display with
  near-square cells. The state's display section gives it as `grid` (null with no display), which
  `PanelState.grid` reads. A scene's `grid:` holds only `gap`; one setting `cols` or `rows` is
  refused. A scene placing a card past the display's last column is refused when drawn: a switch
  to it, the helper (`refused: does not fit this display: …`), and the next-scene key passes over
  it. An unset `colspan` spans every column and must start at column 0. `x-min-cells` is a card's
  span on every scene. Calibration, the one fixed scene, keeps its own grid; the app lays out none.
- A switch or reload to a scene that will not load is refused, the reply carries the failure, and the
  last good scene keeps drawing.
- `reload` is refused during a calibration, as every command is on the audio-vue screen apart from
  pairing.
- There is no preview command and no draft store. Apply is save, then `switch`, which puts a stored
  scene up at its current revision whether or not it is on screen, so the app never uses `reload`
  (`scene-save` design D8).
- A done `switch` answers `SwitchOutcome`: `scene`, `capture` (`kept` or `rebuilt`), `why` (for a
  person, null when kept) and `recorded` (whether it became the panel's next start); `reload` answers
  `SceneOutcome`, the same without `recorded`. Every other command answers plain `Outcome`, `status`
  and `reason`, with 200, 409, 503 and 504 (audio-vue `control-api`, built 2026-11-07).
- `POST /v1/commands/reset` restarts the measurement: statistics, history rings and what each card
  holds, leaving capture, the scene and calibration. Refused while a calibration has the panel;
  wakes the display (audio-vue `measurement-reset`, built 2026-11-07).

## Settings (Built, `settings-schema`, `settings-store`, `card-about`; archived by 2026-11-04)

- **The schema** declares every setting once, with its type, default, label, one-line help, and unit,
  range or choices, and exports as one JSON Schema with its own version (`GET /v1/schema`). The panel
  accepts no undeclared key. The app generates its inspector from it, fetched once per host version
  (Recommended).
- **Classes** (Ruled), by one question, same audio in, does a different number come out:
  - **Appearance** never changes a number.
  - **Display range** changes which part of a scale is visible.
  - **Measurement** changes the number shown for the same audio. The setting declares which values
    are its standard's, or that none governs it, and the state and the app say when a reading
    departs from them.
  - **Chain** changes which audio is measured, such as `input.pair` or `rate`. The app warns only
    where no calibration holds for the chain and rate a scene measures at: audio-vue applies the
    newest valid record for the device and rate in use (`record.active`), so a scene at another
    calibrated rate is fine (maintainer, 2026-11-08). A card's own chain setting, such as
    `vu_meter.channel`, carries no warning.
  - **Record** is what a run states about itself.
- **Each setting's declaration** (Built, audio-vue `schema-step-and-order`; read live 2026-11-09):
  under `properties`, `type` (`boolean`, `number`, `integer`, `string`) or `enum` (an `integer` may
  carry one, as `install.input.rate` does), `minimum`/`maximum`, `pattern` `^#[0-9a-fA-F]{6}$` for a
  colour, `default` (absent on a card's colour setting, which resolves by lookup, below), a
  choice's names as `x-choice-labels` where it has them, and `x-label`, `x-help`,
  `x-unit`, `x-class`, `x-standard` (`null` off the measurement class, `{document: null, values: []}`
  where none governs it), `x-live` and `x-step` (always present, null for none, never a
  constraint). Each `card.<name>`, `block.<name>` and `install.<name>` lists its keys in declared
  order as `x-settings`, since a decoded JSON object keeps no order. A block with `x-keys` is a keyed block: its keys in `x-keys` order, each with its own `properties`, and `x-keyed-by` names the card setting that picks its key, such as the meter's `field` (`meter-scales-editor`, read 2026-11-21, `KeyedBlock`). Every card number has a range
  and a step; block numbers mostly have neither. The app reads them into `SettingGroup`
  (`SchemaFacts.settings`, by card).
- **Settings with no effect** (Built, audio-vue `unused-settings`, 2026-11-09): a card setting may
  carry `x-unused-when`, a list of `{when: {setting: [values]}, reason}`. It has no effect where any
  case matches; a case matches where every named setting holds one of its values (the console
  matches set-or-default). Display only: a scene setting it is still accepted. Read it from the
  export each time; never keep a copy of the field lists.
- **Colours** (Built, audio-vue `scene-styles`, deployed 2026-11-19; it replaced the palette, the
  `elements:` block, `x-swatches`, `x-elements` and `x-element`): a scene's `colors:` block holds
  one `#rrggbb` per role, a thing seen on screen, in the groups background, text, lines and
  signal; one per step of each meaning scale (Warnings, Stereo phase), which are scene-wide and
  never a card's; and `shadow`, an amount from 0 to 1. The root lists `x-roles` (`{id, group,
  default, help}`) and `x-scales` (`{id, label, steps}`) in declared order. A card's colour
  setting is derived from each role the card draws, named `<role>_color`, and takes a role's id or
  a colour (`anyOf` an `enum` and the pattern), with `x-role`; a colour only that card draws
  carries `x-own: {default}`, a role's id or a colour. Unset resolves by lookup: the scene's
  colour for the role, else the role's default; or the own default read the same way. A card's
  `shadow` has no default and no keyword; unset, it takes the scene's. The app's lookup is
  `SceneColours` and `SettingDeclaration.drawnColour`. Blocks declare no `x-label`.
- **Type and typeface** (Built, audio-vue `scene-styles`): `type:` holds a size per text role, a
  number in CSS reference pixels with its own bounds and no step. `typeface:` is the scene's own
  key, outside any block, a labelled choice. The host turns reference pixels into its own from the
  install's `viewing` block (`distance_in`, `display_diagonal_in`), which replaced `fonts`; until
  both are stored the state's `install.viewing_set` is false and a reference pixel is the
  display's height over 1,080.
- **Case** (Built, audio-vue `text-case`, 2026-11-22): `case:` holds `title`, `label`, `caption`
  and `notice`, each a labelled choice of `all_caps` (the default) or `title_case`. Title Case is
  the text as the card writes it; units, numbers and symbols keep their case. No per-card case. The
  helper draws it; the app only edits the block (Style tab, after Text).
- **`x-inherits`** (audio-vue `scene-editor-settings`, 2026-11-20): every setting exports it,
  null or `<document>.<block>`. Where set, the setting declares no `default`, and unset it takes
  the setting of the same key in that block: a scene's `display.saver`, `saver_after_min` and
  `sleep_after_min` name `install.display`; a card's `shadow` names `scene.colors`. The app reads
  it in `SchemaFacts.inheritedValue`. Do not match blocks by name or settings by key yourself.
- **Silence** is one fixed line on the host, with no threshold setting in either display block or
  the state. The silence reset is a scene's `analysis.reset_silence_s` (unset means never) and
  `mute_on_silence`. The install has no `loudness` block.
- **A scene needs at least one card** (read 2026-11-20): the schema's `cards` has `minItems: 1`
  and the render bundle answers "no cards: entries". So a new scene is the app's alone until it
  holds a card (maintainer, 2026-11-20): never send a scene with no cards to the helper or the
  host.
- **Styles** (Built, audio-vue `scene-styles`; the app's side is the `styles` change): a style
  holds a `name` and any of the six look categories, `colors`, `typeface`, `type`, `case`,
  `backdrop` and `glass`. A scene names styles in `styles:`; each category comes from the scene's own key, else
  the one named style holding it, else the built-in `default` style, and a category set in two
  places is refused on a scene write and on a style write alike. A scene with no backdrop draws
  `default`'s. Routes under `/v1/styles` mirror the scenes' (list, read, revisions, validate,
  create, write on `base_rev`, revert, delete); a listing entry names its `categories` and the
  `scenes` naming it; a style a stored scene names is not deleted; a write never changes the
  screen. Read the routes from the saved contract.
- **A card's measurement choices are its own** (Ruled, maintainer 2026-11-22 and 2026-11-23; audio-vue
  `rta-card-settings`, `rta-band-sets`, `rta-spectrogram`): a display choice must not restart a
  measurement, and a band set, a held peak or a history is a request a card makes. `rta_bars` holds
  `bands`, `weighting`, `hold_s`, `release` and `fall_db_s`; `spectrogram` (Spectrum, after
  `rta_bars`) holds `bands`, `quantity` and `span_s`. Cards on one scene may differ. The scene's
  `analysis:` block holds no RTA setting, so never group these under the scene. A scene write that
  changes only a card's settings answers `analysis_changed: false` and keeps capture. `bands` and
  `span_s` are integer choices with `x-choice-labels`, drawn as labelled pickers.
- **The spectrogram's `palette` is a card setting, not a colour** (Ruled, maintainer 2026-11-23): an
  ordinary choice of named colour maps whose tables the host holds. The export carries only the names.
  It is no role, no `<role>_color`, no scene colour, and no style or scene look sets it. Keep it out of
  the look and out of colour wells. A swatch per map would need swatch data, which is a request to audio-vue.
- **Card categories** (Built, `card-categories`, archived 2026-11-08): the schema's root
  `x-categories` lists `{id, label, cards}` in display order, each `cards` in the panel's order and
  naming every card, placeable or not; each `card.<name>` also carries `x-category`. The app reads
  only `x-categories` (`SchemaFacts`).
- **Scenes** (`/v1/scenes`): every scene in audio-vue's `scenes/` ships as a read-only built-in, named
  by its stem, and `default` (one centred `rta_bars` on the `rta` gradient) is among them. A stored
  scene is named by a UUID the host assigns, which never changes. A delete is refused for the scene on
  screen and the boot scene. Writing a scene never changes the screen; a reload or switch does, and a
  write that changes `analysis:` says so.
- **Install settings** (`/v1/install/{block}`): a document per block, stored only once a client writes
  it, defaults until then. A non-chain write applies at the panel's next start. A chain write names
  the keys, restarts the panel in every condition but `down`, and is refused while a calibration has
  it. `PUT` takes `{doc, base_rev}` (0 for a block never written), answers only once a restart it
  causes has finished (up to about 30 s; `pitfalls.md`), and gives `InstallWritten`:
  `rev`, `applies`, `chain_changed` and `calibration` (the host's words on what the chain change does
  to calibration). Its 409 is `Stale | Refusal`: a stale write carries `current_rev`, the refusal
  during a calibration only `detail` (a stale body also reads as a `Refusal`, so check `Stale`
  first). The console writes `input`'s `device`, `rate`,
  `fmt` and `pair` (`PanelInput`, `InputEdit`), keeping the block's other keys. An `input` write
  the attached device cannot stream is refused with 422 and one failure per setting, in the host's
  words.
- **Capture devices** (`GET /v1/host/devices`; audio-vue `capture-channels`, 2026-11-20): each
  `{name, streams}`, `streams` a list of `{format, channels, rates}`, one per way the device
  captures, or absent where the host cannot read them (unknown, not none), with a `reason` where
  the list is empty. A device's formats and rates may include ones the panel does not capture;
  offer the overlap with the schema's. The `input` block holds no channel count: the panel takes
  it from the device, and the host counts a `pair` against the most channels among the ways taking
  the format and rate. `input.device` unset is the host's default device, which is not checked.
  While a capture will not open as configured the panel waits, phase `waiting`, with its sentence
  in the state's `run.screen_status`; it is not a health fault.
- **Revisions**: each scene and install block has its own revision. A write names its base revision,
  and a stale one is refused with the current revision. 20 earlier revisions are kept
  (`KEPT_REVISIONS`, `src/host_store.py`); a revert stores one as a new revision. `/validate` routes
  check a document without storing it, with every failure by place and key.
- **A backdrop** holds exactly one of `color`, `gradient` (two or more stops) and `image`. The host
  also refuses `angle` without a gradient ("angle: applies only to a gradient",
  `src/schema/scene.py`), which its `scene-backdrop` spec does not say (found 2026-11-09). `blur`
  goes with any source.
- **Backdrop images** (`/v1/images`): PNG or JPEG, at most 16 MiB and 4,096 px a side, named by their
  SHA-256; a scene names an image by id, never a path. A delete is refused while a stored scene names
  it.
- **A card's information page** is its Markdown `about` (`GET /v1/cards/{card}/about`), fetched when
  opened, never with the schema.
- **Sizes** (Measured, 2026-11-02): every card's manifest is 21 KB as JSON with help text, a scene 287
  to 2,515 bytes, the install config 343 bytes, the state 897 bytes.
- A card unknown to the app still appears, with no app release, because the inspector comes from the
  schema.

## Scene rendering (Built, `scene-render`, 2026-11-07)

The console renders scenes itself, from audio-vue's card code and analysis bundled into the app; the
host renders nothing for it. The rulings are in `product.md`, "The decision"; audio-vue's side is its
`console-render` change and `.claude/kb/agent/host-platform.md`, "Cards are rendered by the console".
The routes are in the saved contract (`ConsoleCore/Sources/HostAPI/openapi.json`); `HostClient`
calls them:

- **The version read** gives `cards`, the code's digest, with `from`: `panel` where the running panel
  answered, `host` where the agent read its own files, the code the panel runs at its next start.
  `HostVersion.cards` holds it (`CardCode`). It is open, like the API version.
- **`GET /v1/cards/manifest`** (token) gives `from`, `digest`, `entries` (repository paths: a card
  family as its directory, `src/cards/peak_rms`, shared modules and fonts as files) and `cards`, each
  card's name mapped to its family's key in `entries` (`peak_rms_vertical` to `src/cards/peak_rms`).
  An entry no card maps to is shared. The digest is over `entries` alone. The bundle's
  `manifest.json` has the same shape. Read only when the digests differ (`HostClient.cardManifest`).
- The bundle's `requirements.txt` carries every hash `uv.lock` holds; the tool installs it with
  `--require-hashes`.
- **`GET /v1/scenes`** (token) lists each scene's `id`, `name`, `built_in` and `fixed`; a fixed scene
  is a process's, not offered to pick or duplicate. **`GET /v1/scenes/{id}`** gives its `doc` as the
  store holds it, passed to the helper whole (`SceneDocument`, `JSONValue`).
- **`GET /v1/install`** (token) gives each block's `doc` by name; the helper takes the `viewing`
  block.
- **`GET /v1/schema`** (token) is JSON Schema under `$defs`: `block.grid` with its declared defaults,
  and `card.<name>` with `x-placeable`, `x-min-cells` (on a 36-row grid), `x-sizing`, `x-aspect`.
- **`GET /v1/images/{id}`** (token) serves uploads and shipped images alike, PNG or JPEG; a 404 is
  `HostFailure.notFound`. An id is a file name with no separator (audio-vue `images.FORM`).
- **`GET /v1/images`** (token) lists `{images: [{id, shipped, format?, bytes?, width?, height?,
  added_at?}]}`, uploads then shipped. **`POST /v1/images`** takes the raw bytes as `image/png` or
  `image/jpeg` and answers 201 `{id}`, or 413, 415 or 422 with a `Refusal` `{detail}`, read as
  `HostFailure.imageRefused` (`scene-settings`, 2026-11-09).
- The display's pixel size is `/v1/host`'s, null while the panel is down.

Layers are 8-bit RGBA, premultiplied, rects in display pixels from the top left. The app stacks
them with Core Graphics (`Thumbnail.flatten`), which matched audio-vue's stacking formula
(`out = rgb + under * (1 - a / 255)`, its `scene_layers.stack`) at every pixel of the RTA scene at
1920 x 720: 0 steps apart (measured 2026-11-07, `LiveHelperTests`). audio-vue holds its stacking to
two steps of the panel's own render.

The render helper's protocol is audio-vue's (`src/render_service.py`, its docstring): `hello`,
`prepare`, `render` and `stimulus`, each a 4-byte big-endian length and JSON, layers' bytes after a
render's answer. Since `scene-styles` a `render` takes `viewing` and `styles` (`{id: document}`,
the stored styles the scene names; the bundle carries the built-in ones) and no `fonts` or
`fallback`, and its answer adds `style_notice`, naming a style it was not given. A frame carries
the band sets, held peaks and band-level histories its scene's cards ask for, and a run made under
more requests serves a scene asking fewer. `prepare` warms only a default RTA card's requests. Any
other band set, hold or spectrogram history costs one run of about a second the first time a scene
asking for it renders, and is kept from then on (audio-vue `scene-render`, read 2026-11-23).
Asks travel as handoff files in audio-vue's root (`working-notes.md`).

## Calibration (Built, audio-vue `calibration-from-the-app`, 2026-11-08)

The console runs a calibration in `make calibrate`'s order: it renders the stimulus itself, sets the
output's rate with the bundled `cal-play`, arms, and plays once the arm is done (the console's
`calibration` change; rulings in its proposal). The routes and fields are in the saved contract:

- **The stimulus** is written by the render helper, not served: `{"op": "stimulus", "kind",
  "rate", "path"}` (optional `maximum_input_db` and `internal_folding_hz` exist; the console sends
  neither, maintainer 2026-11-08), answering `ok` once
  the file is whole at `path`, `refused` with `calibration.check_stated`'s words (a rate outside the
  calibration's rates included), or `error`. The file is byte-identical to `tools/calibrate.py
  --write`'s. The console offers Calibrate… only while its bundle's digest is the panel's.
- **The rate** is the installed capture rate: `install.input.rate`, else its schema `default`. The
  live `capture.rate_hz` is not it where a scene captures at its own rate. An arm stating another
  `file_rate` makes the panel capture at it, and the installed rate returns once the hold after the
  run ends; an arm during that hold starts a new run at its own rate. So a pass of every rate
  (`CalibrationPass`) arms rate after rate and writes no install settings. The rates are the
  schema's `install.input.rate` `enum` (scenes' `analysis.capture_rate` has the same); validation
  refuses any other, and a stored install at another rate opens no capture.
- **`GET /v1/calibration`** gives each rate holding a valid record for the stored `input.device`:
  `{rate, run_id, status}`, `status` `calibrated` or `stale` (still applies), lowest first, a rate
  with none left out. Read from the records by `record.active`'s own rule, so it answers with the
  panel down. The Input section marks rates from it; `scene-settings` will share
  `HostClient.calibratedRates`.
- **`POST /v1/commands/arm`** takes `{"stated": {"kind", "file_rate", ...}}` and answers
  `ArmOutcome`; a done one gives `arm`, the arm's id. Refused while another arm listens, a run is
  under way, an arm is landing, the panel replays a clip or capture has stopped, or an update runs.
- **`POST /v1/commands/cancel`** answers `CancelOutcome`; a done one says `record_stands` where it
  ended the hold after a completed run. Refused with `nothing to cancel` or `too late -- the record
  is being written`.
- **`state.sections.calibration.lifecycle`** is an enum: `off`, `waiting` (armed, listening),
  `arming` (marker heard, one poll), `running`, `analysing`, `done`, `failed`, `expired`. The
  ended words pass to `off`, an expiry possibly between two reads, so a client never ends a run on
  them.
- **`state.sections.calibration.ended`** names the calibration that last ended, until the next arm
  lands: `arm`, `outcome` (`done`, `failed`, `expired`, `cancelled`), `kind`, `run_id`,
  `applicable`, `reason`. A client matches its run by `arm`. Every `failed` run has no record; a
  saved record ends `done`, its `reason` saying a stimulus was missing or its report failed.
- **`GET /v1/runs`** lists `run_id`, `has_report`, `kind` and `applicable` (fit to apply when
  written) and `rate` (null for older records), newest first, with the panel down too; **`GET /v1/runs/{id}/report`** is the HTML, self
  contained, with no links. No run's audio is served; `make cal-fetch-audio` fetches it.
