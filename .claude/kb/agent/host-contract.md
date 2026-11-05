# The host contract

What the app relies on from the host, as a consumer. This is a view, and it drifts. The authorities,
in order: the running agent's `/v1/openapi.json`; audio-vue's specs `control-api`, `control-service`,
`host-store`, `control-state` and `control-commands` (`../audio-vue/openspec/specs/`); its open changes
`settings-schema` and `settings-documents` (`../audio-vue/openspec/changes/`); and
`../audio-vue/.claude/kb/agent/host-platform.md`. Check them before building against anything here.

Each item is **Built** (in audio-vue and running on the proving host) or **Planned** (an open change or
a ruling with no change yet). As of 2026-11-02; pairing and settings as of 2026-11-04.

## Reaching a panel (Built, `control-service`)

- The host agent serves HTTP and a WebSocket under `/v1`, on port 19200 on every IPv4 interface by
  default; the host's own `tools/agent.py set` changes both.
- The contract is `/v1/openapi.json`. State is pushed on `/v1/events`. The agent polls the panel at
  4 Hz only while a client is connected or has just read.
- The panel is `up`, `down`, `stale`, `capture_stopped` or `no_audio`.
- The agent outlives the panel: after a stop it stays up and reports the panel stopped, and can start
  it again. It also gives start, stop, status, logs, run history (calibration runs by id), and the
  host's id, name, display size and capture devices.
- The API states its own version. The app checks it on connect, since it can fall behind its host.
- The proving host runs Pi OS (since 2026-11-02; audio-vue ships an SD image by default, with manual
  install as an option). It answers as `audio-vue.local`, and the LAN's DNS names it
  `audio-vue.cabin.hobbysprawl.com`, or `audio-vue` by the search domain (Measured, 2026-11-03;
  the host was `audio-image` before). `GET /v1/version` answers `{"api": "1.0.0", "schema": 1}`, and
  any `Origin` header gets a 403 (Measured, 2026-11-02); `{"api": "2.0.0", "schema": 1}` since
  `settings-store` (Measured, 2026-11-04). The contract requires only `api`, so treat a
  missing `schema` as null.
- The agent's default port, 19200, is `DEFAULT_PORT` in `../audio-vue/src/host_store.py`; no spec
  names it (2026-11-03).

## Discovery (Built, `control-service`)

- The agent registers DNS-SD type `_audio-vue._tcp` with Avahi once it listens: instance named by the
  store's host name, at the bound port, TXT `id` (as `/v1/host`) and `api` (as `/v1/version`). Keys
  keep their names and meanings within an API version. Tell hosts apart by `id`, since an instance
  name can be renamed on a clash, and a reinstalled host gets a new id.
- Withdrawn when the agent stops; nothing announced when bound to loopback or with no responder.
  A typed address stays supported.
- The proving host announces `audio-vue` at `audio-vue.local:19200`, TXT `id=779b365c-...`,
  `api=1.0.0` (Measured, `dns-sd -L`, 2026-11-03).

## Pairing and tokens (Built, `control-service`)

- `POST /v1/pairing` shows a six-digit code on the panel for 120 s and five wrong tries, one pairing
  at a time and 30 s between them. `POST /v1/pairing/confirm` gives the token once. Pairing works
  even on the audio-vue screen, where a new host with no ADC sits.
- One token per client; the app stores one per panel. `GET /v1/clients` lists clients and
  `DELETE /v1/clients/{client_id}` revokes one (Read in the proving host's `/v1/openapi.json`,
  2026-11-02).
- Every route takes a token, `/v1/openapi.json`, `/v1/host` and `/v1/events` (by its handshake's
  `Authorization` header) included, except asking for a pairing code, confirming it, and
  `GET /v1/version` (Built: audio-vue `settings-store`, archived 2026-11-04; Measured on the proving
  host, 2026-11-04: `{"detail": "pair first: this takes a token"}` with a 401). So an unpaired app
  knows only the version and the TXT record; the display shape and the contract come after pairing.
- Closing the reads made the API 2.0.0 (audio-vue `6eb0c3e`). The app supports major 2 only from the
  `pairing` change (maintainer, 2026-11-04).
- A request with any `Origin` header is refused: HTTP with a 403, a WebSocket closed with 1008
  (Read, `NoOrigin` in `src/control_service/app.py`, 2026-11-02; the spec words it as another site's
  origin, and the code is stricter). The app must send none. `pitfalls.md`.
- A refusal is `{"detail": "<reason>"}`, worded for people. Asking for a code answers 409 when one is
  showing, 429 with `Retry-After` in the wait after one ends, 503 when the panel cannot show it;
  confirming answers 403 for a wrong code and 409 when none is showing (lapsed or withdrawn). The
  header is in the code, not the contract (Read, `pairing.py` and `app.py`, 2026-11-04; the maintainer
  is asking audio-vue to declare it). A client's `paired_at` is ISO 8601 to the second, UTC.
- A wrong code costs one of the five tries and leaves the code standing; asking for a new code
  while it stands is refused with 409, and the 30 s wait follows every end, a success or a lapse as
  well as a withdrawal (Measured, the maintainer's run, 2026-11-04: an app that asked again after a
  typo waited out the 120 s code, then 30 s). The maintainer is asking audio-vue to keep the wait
  for a withdrawal only.
- HTTP is fine on a LAN. TLS comes before the API can update software.

## Scenes and commands (Built, `control-commands`, `scene-reload`)

- A scene is identified by its id, never its `name`, which is a label: a built-in's filename stem, or
  a stored scene's UUID (`settings-store`).
- A scene's shape is its grid's `cols:rows`: 64x36 at 16:9, 96x36 at 8:3. The host fits it to the
  largest centred region at that aspect, with the backdrop outside.
- A switch or reload to a scene that will not load is refused, the reply carries the failure, and the
  last good scene keeps drawing.
- `reload` is refused during a calibration, as every command is on the audio-vue screen apart from
  pairing.
- There is no preview command and no draft store. Apply is save, then `reload`.

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
  - **Chain** changes which audio is measured, such as `input.pair` or `rate`. The app warns that
    calibration no longer applies.
  - **Record** is what a run states about itself.
- **Scenes** (`/v1/scenes`): every scene in audio-vue's `scenes/` ships as a read-only built-in, named
  by its stem, and `default` (one centred `rta_bars` on the `rta` gradient) is among them. A stored
  scene is named by a UUID the host assigns, which never changes. A delete is refused for the scene on
  screen and the boot scene. Writing a scene never changes the screen; a reload or switch does, and a
  write that changes `analysis:` says so.
- **Install settings** (`/v1/install/{block}`): a document per block, stored only once a client writes
  it, defaults until then. A non-chain write applies at the panel's next start. A chain write names
  the keys, restarts a running panel and is refused while a calibration has it.
- **Revisions**: each scene and install block has its own revision. A write names its base revision,
  and a stale one is refused with the current revision. 20 earlier revisions are kept
  (`KEPT_REVISIONS`, `src/host_store.py`); a revert stores one as a new revision. `/validate` routes
  check a document without storing it, with every failure by place and key.
- **Backdrop images** (`/v1/images`): PNG or JPEG, at most 16 MiB and 4,096 px a side, named by their
  SHA-256; a scene names an image by id, never a path. A delete is refused while a stored scene names
  it.
- **A card's information page** is its Markdown `about` (`GET /v1/cards/{card}/about`), fetched when
  opened, never with the schema.
- **Sizes** (Measured, 2026-11-02): every card's manifest is 21 KB as JSON with help text, a scene 287
  to 2,515 bytes, the install config 343 bytes, the state 897 bytes.
- A card unknown to the app still appears, with no app release, because the inspector comes from the
  schema.

## Card tiles (Planned, no change yet)

- Each tile is an image the host renders at its true pixel size, from the real card code, on fixture
  data. The app deals in grid cells and the host owns pixels.
- While a card is dragged the app scales its bitmap; on release a fresh render replaces it.
- A render may report that text clipped, the fit check the host lacks today.
- If the panel has to pause to render, it shows a "configuring" screen and the state says so.
