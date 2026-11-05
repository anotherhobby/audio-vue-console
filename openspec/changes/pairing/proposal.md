# Proposal

## Why

Since audio-vue's `settings-store` (archived and deployed, 2026-11-04), a host answers every route but
pairing and its version only with a token, `/v1/host` and the contract included, and states API 2.0.0
for it. The app accepts major 1 only, so it refuses the proving host, and once past that it can connect
and do nothing else. So pairing comes before the panel client (maintainer, 2026-11-03). The token has
to be kept somewhere that an ad-hoc signed app can read after every update without asking. The
Keychain fails that test: each new build has to type the login password to read its own item
(Measured, 2026-11-04, `pitfalls.md`).

## What Changes

- The app pairs with a host: it asks for a code, which the panel shows, and sends back the six digits
  the user reads off it. It names itself by the Mac's computer name. The host's refusals are told
  apart: a wrong code with the tries left, a code withdrawn, a pairing already under way, the wait
  before the next one, and a panel not running.
- `ConsoleCore` keeps one token per host in a file in the app's sandbox container, readable by the
  owner only, behind a token store the app can swap for a Keychain one if it ever gets a team
  (maintainer, 2026-11-04, `decisions-log.md`).
- Every request to a paired host carries its token as `Authorization: Bearer`. The version read stays
  open and carries none.
- On connect, the app says whether it is paired with the host. A stored token the host answers with a
  401 means pair again, not a fault, and the app forgets it (`pitfalls.md`).
- A paired app lists the host's paired clients, marks itself among them, and revokes any of them.
  Revoking itself forgets its token.
- **BREAKING** The app supports API major 2 and no longer major 1 (maintainer, 2026-11-04): a 1.x
  host had open reads, and none is left to talk to.
- `HostClient` learns `POST` and `DELETE`, and the transport with it.

Out of scope: the Keychain, the generated OpenAPI client and `/v1/events` (the panel client, next),
discovering hosts, more than one host on screen at once, and renaming a client.

## Capabilities

### New Capabilities

- `host-pairing`: gaining a token from a host by the code on its panel, keeping one token per host,
  sending it, pairing again when the host no longer takes it, and listing and revoking the host's
  paired clients.

### Modified Capabilities

- `host-connection`: the supported API major becomes 2, and connecting also says whether this app is
  paired with the host.

## Impact

- Changed: `ConsoleCore/` (the client's requests, a token store, pairing and clients) and its tests;
  `AudioVueConsole/` gains the pairing and clients views, which reach the host only through the core
  (`app-boundaries`).
- The host is unchanged. The app relies on these audio-vue specs:
  - `audio-vue:control-service`: pairing by a code on the panel, its expiry, tries and one-at-a-time
    rule, a token per client, listing and revoking clients, and which routes take a token.
  - `audio-vue:control-api`: the refusal of any `Origin` header, and the version read without a token,
    which states API 2.0.0 (Measured on the proving host, 2026-11-04).
  - `audio-vue:host-store`: paired clients survive a restart, and the store holds no token.
- The proving host runs `settings-store`: `/v1/version` answers, and `/v1/host`, `/v1/openapi.json`
  and `/v1/clients` answer 401 with no token (Measured, 2026-11-04).
