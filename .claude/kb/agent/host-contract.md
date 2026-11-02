# The host contract

What the app relies on from the host, as a consumer. This is a view, and it drifts. The authorities,
in order: the running agent's `/v1/openapi.json`; audio-vue's specs `control-api`, `control-service`,
`host-store`, `control-state` and `control-commands` (`../audio-vue/openspec/specs/`); its open changes
`settings-schema` and `settings-documents` (`../audio-vue/openspec/changes/`); and
`../audio-vue/.claude/kb/agent/host-platform.md`. Check them before building against anything here.

Each item is **Built** (in audio-vue and running on the proving host) or **Planned** (an open change or
a ruling with no change yet). As of 2026-11-02.

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

## Pairing and tokens (Built, `control-service`)

- `POST /v1/pairing` shows a six-digit code on the panel for 120 s and five wrong tries, one pairing
  at a time and 30 s between them. `POST /v1/pairing/confirm` gives the token once. Pairing works
  even on the audio-vue screen, where a new host with no ADC sits.
- One token per client; the app stores one per panel. Revoking a client is Recommended.
- Reads are open on the network. Anything that changes state takes a token, and so do logs and the
  capture devices. An unpaired client cannot start a stopped panel.
- A request with any `Origin` header is refused: HTTP with a 403, a WebSocket closed with 1008
  (Read, `NoOrigin` in `src/control_service/app.py`, 2026-11-02; the spec words it as another site's
  origin, and the code is stricter). The app must send none. `pitfalls.md`.
- HTTP is fine on a LAN. TLS comes before the API can update software.

## Scenes and commands (Built, `control-commands`, `scene-reload`)

- A scene is identified by its spec, the filename stem, never its `name`, which is a label.
- A scene's shape is its grid's `cols:rows`: 64x36 at 16:9, 96x36 at 8:3. The host fits it to the
  largest centred region at that aspect, with the backdrop outside.
- A switch or reload to a scene that will not load is refused, the reply carries the failure, and the
  last good scene keeps drawing.
- `reload` is refused during a calibration, as every command is on the audio-vue screen apart from
  pairing.
- There is no preview command and no draft store. Apply is save, then `reload`.

## Settings (Planned, `settings-schema`, `settings-documents`)

- **The schema** declares every setting once, with its type, label, unit, range, step and a one-line
  help text. The app generates its inspector from it. It is fetched once per host version.
- **Classes** (Ruled), by one question, same audio in, does a different number come out:
  - **Appearance** never changes a number.
  - **Display range** changes which part of a scale is visible.
  - **Measurement** changes the number shown for the same audio. The setting declares which values
    are its standard's, and the state and the app say when a reading departs from them.
  - **Chain** changes which audio is measured, such as `input.pair` or `rate`. The app warns that
    calibration no longer applies.
- **Documents**: scenes and settings are stored on the host and served one at a time, with a revision
  counter for two clients. Built-in scenes are read-only. The default scene is generated at first boot
  and is an ordinary editable scene. Backdrop images upload through the API.
- **A card's information page** is its `about.md`, fetched when opened, never with the schema.
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
