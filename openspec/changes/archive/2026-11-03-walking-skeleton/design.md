# Design

## Context

The app target is Xcode 27's App template, already set to macOS 27.2 only, Swift 6 with warnings as
errors, and the App Sandbox with outgoing network connections (`decisions-log.md`). There is no
package, no test target, and no specs. The host side is built: `GET /v1/version` returns
`{"api": "1.0.0", "schema": <int or null>}`, where the contract requires only `api` and allows more
fields, is open to unpaired clients, and like every route refuses
any request carrying an `Origin` header with 403 (audio-vue `control-api`; `host-contract.md`).

The quality gate type-checks SwiftPM packages at Stop but not the Xcode project, and it bans
`@unchecked Sendable`, `nonisolated(unsafe)`, `try?`, force unwraps and magic numbers (`product.md`,
"The quality gate"). Several decisions below follow from that.

## Goals / Non-Goals

**Goals:**

- A package layout every later change extends without moving files.
- Everything decidable without a network (address parsing, version compatibility, and the
  connection's state changes) tested by `swift test` in seconds.
- One manual run against the real proving host, which is the only proof of the sandbox, local
  network privacy and App Transport Security together.

**Non-Goals:**

- Choosing the OpenAPI client generator. `/v1/version` is decoded by hand, and the generator is
  change 2's first decision. That client will replace this decoding.
- IPv6 addresses, host discovery and retry or backoff.
- Telling "local network access denied" apart from "unreachable". Both report unreachable for now.

## Decisions

### A local package, `ConsoleCore`, at the repository root

`ConsoleCore/Package.swift` with one library target, `ConsoleCore`, and one test target using Swift
Testing. The app target depends on it as a local package. The module name isn't the bare `Core`
because that name is generic enough to collide with other modules.

- *Alternatives:* a framework target inside the Xcode project, which the gate would not type-check
  and which `swift test` cannot run; or several packages now (Core, UI), which is more structure than
  one screen needs. A UI package can come later if the boundary test proves too weak.

### Logic and state in the core, views in the app target

The core holds `HostAddress` (parse and validate), `APIVersion` (semantic version and the compatibility
verdict), a `HostClient` that reads the version, and a `@MainActor @Observable` connection model that
the view binds to. Observation is not a UI framework, so the model can live in the core and be tested
there. The app target's real code is only the `App` and one view, which keeps the code the gate
cannot compile small. The throwaway UI sketch (`AudioVueConsole/Sketches/`) stays beside it as a
second window, opened from the Window menu in Debug builds only (maintainer, 2026-11-03), until the
canvas spike replaces it.

- *Alternative:* a view model in the app target. Its logic would be untested by `swift test` and
  unchecked by the gate.
- The app target defaults to main-actor isolation; the package keeps Swift's default, nonisolated.
  The model is marked `@MainActor` explicitly, and the address, version and client types are
  `Sendable` values, so nothing in the core depends on the app's setting.
- The client decodes `schema` as optional: a missing field reads as null, which the view shows as the
  panel not answering. Unknown fields are ignored, since the contract leaves the object open.

### A transport protocol as the test seam

`HostClient` sends through a small `HostTransport` protocol (`GET` a URL, return data and an HTTP
response). The real one wraps an ephemeral `URLSession` with a 5 s request timeout. Tests use a fake
that records each request and returns canned answers, so the no-`Origin` and URL scenarios are
asserted on the actual request the client builds.

- *Alternative:* a `URLProtocol` stub. It needs shared mutable static state, which Swift 6 strict
  concurrency rejects unless the code reaches for the escapes the gate bans.
- `URLSession` adds no `Origin` header on its own. The manual run confirms this end to end: a 200 from
  the host is proof, since any `Origin` gets a 403.

### Compatibility is semantic versioning with one supported major

This is an assumption, since audio-vue states no compatibility rule. The core declares one supported
major version, 1. A host whose API has major 1 is compatible whatever its minor and patch; minor
releases are taken to be additive. A higher major means the host is newer, and a lower one means it
is older. A version with a pre-release or build suffix is read by its numeric core. If audio-vue later
states a rule, this decision and the `host-connection` requirement change together.

### Address handling

The input is `host[:port]`. The host is an IPv4 address or an RFC 1123 hostname, and the port is
1-65535, defaulting to 19200. Surrounding whitespace is trimmed. Text with a scheme, such as
`http://audio-vue`, or a path is not an address and is refused as invalid. The URL is built from
validated parts, never by pasting the user's text
into a URL string. The last address is saved when the host answers with a version, compatible or not.
It goes in `UserDefaults` behind a small protocol, so tests use an in-memory store.

### Info.plist for LAN HTTP

- `INFOPLIST_KEY_NSLocalNetworkUsageDescription` build setting: macOS's local network privacy asks
  the user once, with this text, before the first LAN connection.
- `NSAppTransportSecurity` → `NSAllowsArbitraryLoads` (maintainer, 2026-11-02): plain HTTP to any
  host. The proving host is named by a fully qualified name, `audio-vue.cabin.hobbysprawl.com`, which
  `NSAllowsLocalNetworking` does not cover, and the host API is HTTP-only until the host serves TLS.
  The app only talks to hosts the user names, so this states what it does. Revisit when the host gains
  TLS.
  - *Alternatives:* `NSAllowsLocalNetworking`, which covers only `.local`, unqualified names and IP
    addresses; or an `NSExceptionDomains` entry for `hobbysprawl.com`, which writes the maintainer's
    network into the app and fails anyone else's host.
- A dictionary cannot be set through an `INFOPLIST_KEY_` build setting, so it goes in a partial
  Info.plist (`INFOPLIST_FILE`) that Xcode merges with the generated one. That file sits outside the
  synchronized `AudioVueConsole/` folder, so it isn't also copied as a resource.

### Boundary tests read source files

A test in the core's test target finds the repository from `#filePath` and scans
`ConsoleCore/Sources` for `import SwiftUI` or `import AppKit`, and `AudioVueConsole/` for `import
Network` or `URLSession`. It names any offending file.

- *Alternative:* a separate UI package, which would make the compiler enforce "UI cannot reach the
  network", but only once views live in a package. That was deferred (maintainer, 2026-11-02). A
  text scan is crude, but it is a test that runs on every `swift test`.

## Risks / Trade-offs

- [The local network privacy prompt, or a denial, blocks the first connection] → The manual run
  covers it. If the user denies access, the app reports unreachable, as stated above. The first
  connect may also time out at 5 s while the prompt waits for an answer; connecting again after
  answering it is expected to work, and task 6.1 records what happened.
- [Allowing all HTTP lets a mistyped or hostile address load over plain HTTP] → The app reads only
  `/v1/version` from the address and decodes nothing but that answer, and pairing tokens (a later
  change) travel only to a host the user paired with. TLS on the host is the real fix.
- [The partial Info.plist collides with the generated one or is copied as a resource] → Keep it
  outside the synchronized folder. Xcode's build log shows a collision at once.
- [The text-scan boundary test misses an indirect route, such as a helper type that wraps
  `URLSession`] → Accepted for now. The move to a UI package is the stronger fix, and it stays
  available.
- [The gate cannot compile the app target] → The app target's real code is two small files, and the
  sketch is throwaway. Xcode's build through MCP covers both, and SwiftLint and swift-format check
  every file.

## Migration Plan

None. Nothing ships yet, so there is nothing to migrate or roll back. Removing the change means
deleting `ConsoleCore/` and restoring the template files.
