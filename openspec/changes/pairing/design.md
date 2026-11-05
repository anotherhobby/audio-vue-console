# Design

## Context

`ConsoleCore` reads one route today: `HostClient.version(at:)` sends a `GET` through
`HostTransport.get`, and `HostConnection` turns the answer into the connect view's state. The last
address is kept in `UserDefaults` by `AddressStore`. `APIVersion` accepts major 1.

The proving host runs audio-vue's `settings-store`: API 2.0.0, every route but `POST /v1/pairing`,
`POST /v1/pairing/confirm` and `GET /v1/version` answers 401 with no token (Measured, 2026-11-04). The
host's refusals are `{"detail": "<reason>"}`, worded for people; a 429 also carries `Retry-After`
(Read, `src/control_service/app.py`, `_refused`). Confirming gives `{"token", "client_id"}` once.

Ad-hoc signed, the app cannot use the data-protection keychain, and the login keychain asks every new
build for the login password (`pitfalls.md`). The maintainer ruled a file in the container
(`decisions-log.md`, 2026-11-04).

## Goals / Non-Goals

**Goals:**

- Every request but the version and pairing goes out with the right token, from one place.
- Token storage sits behind a seam the Keychain can replace without touching pairing.
- The pairing and clients flows are testable in `ConsoleCore` against a fake transport, as the connect
  flow is.

**Non-Goals:**

- Finding a paired host at a new address. That needs the host's id before a token, which only
  discovery's TXT record gives (the `discovery` change).
- A general request layer for the panel client. This change adds the requests pairing needs, by hand;
  the client generator is decided in the next change.

## Decisions

### D1. Tokens are kept by host id, with addresses pointing at ids

The store keeps, per host id, the token and the `client_id` the host gave, and separately which host
id each address led to. A connect looks up address, then id, then token.

The confirm reply has no host id, so right after confirming the app reads `GET /v1/host` with the new
token and records the id. Its answer is a `HostIdentity`, not a `Host`, which is Foundation's class
and is used in D8 (F7). That read also proves the token works before it is kept.

Alternatives: keying by address alone is simpler today, but a reinstalled host at the same address and
a known host at a new one look the same, and discovery would have to rekey everything. Trying every
kept token at an unknown address would hand tokens to whatever answers there. Rejected.

### D2. Pairing again revokes the app's earlier client

When the id read in D1 already has a token, the app revokes that entry's `client_id` with the new
token before replacing it, so the host lists this Mac once (`host-pairing`, "Pairing again"). A 404 is
taken as already gone. Any other failure keeps the new token and leaves the old client listed, for the
user to revoke by hand.

### D3. The token file

One JSON file, `pairings.json`, in the container's Application Support, which a new container lacks
until the first save creates it. Each save writes a temporary file in the same directory, created at
mode `0600`, and moves it over the old one, so the file is never readable by others, not even between
a write and a `chmod` (alignment F9). A `TokenStore` protocol in `ConsoleCore` (load, save, forget, by
host id and address), with `FileTokenStore` the only implementation and an in-memory one for tests.
Unlike `AddressStore`, it has no default at `init`, so no test can reach the real file (F10).

Alternatives: the Keychain (measured, ruled out); `UserDefaults`, which is also a file in the container
but puts a secret among preferences and offers no file mode. Rejected.

### D4. One send, the token per request

`HostTransport.get` becomes `send(_ request: URLRequest)`, which sends any method. `HostClient`
builds every request in one function that sets the method, a JSON body where there is one, no
`Origin`, and `Authorization: Bearer` when given a token. The version and the two pairing calls are
the calls that take no token argument, so a token cannot reach them by mistake.

`HostFailure` gains `.tokenRefused` (401, on a request that carried a token; the version's 401 stays
an unexpected answer) and `.pairingRefused(PairingRefusal)`, where `PairingRefusal` is the kind and
the host's `detail`. The kind depends on the call as well as the status, since the host's 409 means
opposite things on the two routes (`src/control_service/pairing.py`, alignment F1): asking gives
`busy` 409, `tooSoon(seconds)` 429 and `noPanel` 503; confirming gives `wrongCode` 403 and `noCode`
409, a code that lapsed or was withdrawn. A 422 is an unexpected answer, since the app sends only
what the contract allows.

Each call's statuses are mapped where the call is, and the calls live in extensions by subject
(`HostClient+Pairing.swift`, `HostClient+Clients.swift`) so `HostClient` stays inside the gate's 200
lines a type (F8).

Alternative: adding `post` and `delete` beside `get` triples the transport's surface and every fake's,
for no difference in behaviour. Rejected.

### D5. Refusals are told apart by status and worded by the host

The app picks its message's kind from the call and status (D4) and shows the host's `detail` under
it. A 503 is also the host's answer when a running panel would not show a code, so the kind reads
"the panel can't show a code" and the detail says which (F11). Whether a
wrong code left tries or withdrew the code is only in the detail, so the app does not parse it; after a
403, it offers to send another code and to ask for a new one, and the host's answer to either says
which applies. The `Retry-After` seconds of a 429 enable asking again when they have passed.

Alternative: counting tries from `PairingShown.tries`. It duplicates the host's count and goes wrong
if the host changes its rule. Rejected.

### D6. Connect checks the token with `GET /v1/host`

After a compatible version, `HostConnection` looks up a token for the address (D1). With none, the
state is connected and not paired. With one, it reads `GET /v1/host`: a 200 is paired, a 401 forgets
the token (`host-pairing`, "A refused token means pair again") and is not paired. Any other failure of
that read is reported as a failed connection, as today.

`/v1/host` is chosen over `/v1/clients` since its answer is the next change's display shape and id;
either checks the token.

### D7. The models and the views

`HostConnection.State.connected` gains whether the app is paired. A new `@Observable` `HostPairing`
in `ConsoleCore` runs one pairing (asking, waiting for a code, confirming, refused), and a
`PairedClients` model loads, lists and revokes, marking this app by its `client_id`.

`HostConnection` owns the `HostClient` and the `TokenStore`, and makes a `HostPairing` or a
`PairedClients` for the host it is connected to when the view opens a sheet. Each reports back to the
connection that made it, which moves to paired or not paired. `ConnectView` keeps its one `@State`
connection, so no view wires models to one another (F6). The app target adds a pairing sheet and a
clients list, which call these models only (`app-boundaries`).

A client's `paired_at` is a string in the contract; the store writes ISO 8601 to the second with an
offset (`host_store.py`, `add_client`). The app reads it as ISO 8601 and shows the date, or the text as
given where it does not parse (F5).

### D8. The name sent

`Host.current().localizedName` (Foundation), cut to 64 Unicode scalars, since the host counts Python
characters, which are code points. Measured inside the sandbox on 2026-11-04: it gives the computer
name (`hobbymac`) in under a millisecond, as `SCDynamicStoreCopyComputerName` does, while
`ProcessInfo.hostName` gives the network name (`hobbymac.local`). An empty name falls back to the app's
name, since the host refuses an empty one.

### D9. Major 2 only

`APIVersion`'s supported major becomes 2. There are no 1.x hosts left (proposal, maintainer).

## Risks / Trade-offs

- [A token at rest can be read by any unsandboxed process running as the user] → Ruled acceptable: the
  token reaches only a LAN host and is revoked per client. The `TokenStore` seam lets a Keychain store
  replace it once there is a team.
- [A paired host reached at a second address pairs again, and needs someone at the panel] → D2 keeps
  the host's list to one entry for this Mac. Discovery removes the cause.
- [A crash between confirming and recording leaves a token the app never kept] → The host lists a
  client the app cannot use, which the user can revoke. The window is one read long.
- [The pairing sheet is open while another client pairs] → The host refuses with 409 and the sheet
  says so (D5); nothing to coordinate on the app's side.

## Migration Plan

None on disk: no build of the app has kept a token. A host on API 1 is told it is older than the app.
