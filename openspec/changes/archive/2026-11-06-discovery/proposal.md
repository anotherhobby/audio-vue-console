# Proposal

## Why

The app finds a panel only by an address the user types, and a paired panel reached at any other
address looks unpaired, because the app cannot know it is the same host before it sends a token. The
host agent already announces itself on the LAN with its id, so the app can list the panels it finds,
and recognise a paired one wherever it is announced.

## What Changes

- **The app browses the LAN for panels.** While it runs, the app looks for `_audio-vue._tcp`
  announcements, and reads each one's address and port and the host id in its TXT record. One host
  seen more than once, on two interfaces or under a renamed instance, is one panel by its id. A
  panel drops from the list when its announcement is withdrawn.
- **The picker lists the panels found.** Each panel found is listed alongside the one the app holds,
  and choosing one connects to it. The app still holds one panel at a time. Add Panel… stays, for a
  host that is not announced or a typed address.
- **A paired panel is recognised by its id.** When a found panel's id is one the app holds a token
  for, the app connects with that token at the announced address, then checks that the host's own
  id, read with the token, is the one announced. A typed address behaves as it does now.
- **The app remembers the last panel's id.** At launch, if the remembered address does not answer,
  the app connects to the panel announced with that id.
- **A found panel is named before pairing.** Before the app can read the host's name, the picker
  shows an unpaired found panel by its instance name, not its address.
- **The app asks for local network access to browse.** If the user denies it, the picker says the
  app may not reach the local network and where to allow it, since the denial stops a connection to
  a LAN host by address too.

## Capabilities

### New Capabilities

- `host-discovery`: How the app finds panels on the LAN: the service it browses for, what it reads
  from each announcement, how announcements of one host merge by id, when a panel leaves the list,
  and what the app shows when it may not browse.

### Modified Capabilities

- `panel-window`: The picker lists the panels found as well as the one held, and choosing one
  connects to it; an unpaired found panel is named by its instance name.
- `host-connection`: The app remembers the last panel's id with its address, and a launch that
  cannot reach the address connects where that id is announced; a found panel whose id the app holds
  a token for connects paired at the announced address.

`host-pairing` is unchanged: tokens are already kept by host id, and a request carries the token
kept for that host.

## Impact

- **Code:** `ConsoleCore` gains the browser, behind a seam the tests can script, as `EventSource` is
  for the live state, and the merged list of found panels; `HostConnection` connects to a found
  panel and falls back to it at launch. The app target's picker lists found panels. Browsing stays
  out of the UI (`app-boundaries`).
- **App configuration:** the Info.plist declares the `_audio-vue._tcp` service, which macOS needs
  before the app can browse; the reason for local network access, already set, is reworded.
- **Dependencies:** none. Browsing uses the system's Network framework, and resolving its dnssd.
- **Referenced specs:** `audio-vue:control-api` ("The announcement is part of the contract": the
  service type and the TXT `id`; the host's identity read with the token), `audio-vue:control-service`
  (the announcement, its withdrawal, a renamed instance on a clash, nothing announced on loopback,
  and tokens), `audio-vue:host-store` (the identity and the paired clients kept in one store).
