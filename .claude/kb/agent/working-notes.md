# Working Notes

Record short-lived but useful task context here. When touching `working-notes.md`, remove stale task notes that no longer help future work.

- 2026-11-02: Recommended first step per `product.md`: a two-day canvas spike (snap, resize,
  groups by drag and drop) against a stub host. Since recommended to run it inside the scaffolded
  app, after the first change, since it touches only the UI layer.
- 2026-11-02: The Swift quality gate 0.3.0 is installed and enabled at user scope. Its rules:
  `product.md`, "The quality gate".

## First change: walking skeleton (2026-11-02)

Ruled by the maintainer: full Xcode owns the project, at the repo root; Claude Code is the agent,
using Xcode's tools over MCP (`.mcp.json`, approved and working). Do not let the gate drive the
layout; if it forces a bad path, change the gate (asked first).

Ruled for the first change (maintainer, 2026-11-02): option B, the walking skeleton. The app
launches, takes a host address, calls `GET /v1/version` with no `Origin` header, and shows connected
and the API version, or a version mismatch. A `Core` local Swift package that cannot import
SwiftUI, from the start; views stay in the app target for now. The OpenAPI client generator and
`/v1/events` are change 2's first decision.

Done: the template settings (`decisions-log.md`). Not yet proposed in OpenSpec; nothing committed.

For the change to settle, from memory and unverified on macOS 27: connecting to a LAN host may need
`NSLocalNetworkUsageDescription` (local network privacy), and plain HTTP to a `.local` name needs
ATS's `NSAllowsLocalNetworking`. Also a test target or `swift test` on `Core` only.
