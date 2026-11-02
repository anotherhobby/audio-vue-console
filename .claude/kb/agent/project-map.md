# Project Map

Record repository structure, main behavior locations, and concise architecture notes explaining what is being built and why. This is not a junk drawer.

## What this is

audio-vue-console is the SwiftUI macOS desktop app that is the console and control plane for
audio-vue (`../audio-vue`). The host is an appliance and this app is its companion: all truth is
on the host, and the app knows only the API. Read
`../audio-vue/.claude/kb/agent/desktop-app.md` for the full product statement and its rulings;
it is the authority, and this file only points at it. (Read 2026-11-02.)

Key facts from that statement, as of 2026-11-02:

- Reaches a panel by address and the API alone: HTTP/WebSocket under `/v1` on the host agent,
  port 19200 by default, contract at `/v1/openapi.json`, state pushed on `/v1/events`.
- Pairing is a six-digit code shown on the panel (`POST /v1/pairing`, then
  `POST /v1/pairing/confirm`); one token per client, stored per panel.
- Cards are rendered by the host; the app draws only the grid, handles and drag.
- Recommended structure: a `Core` package that cannot import SwiftUI, a client generated from
  the OpenAPI document, a UI layer that cannot touch the network, all testable with `swift test`
  in a thin Xcode shell.

## Repository structure

Nothing is built yet. Only the KB exists (2026-11-02).
