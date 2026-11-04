# Spec Delta

## Purpose

Keeps the app's logic portable and its networking in one place, so the UI can be rewritten for another
platform and every request the app makes goes through code that follows the host's rules.

## ADDED Requirements

### Requirement: The core imports no UI framework

The app's core logic SHALL live in a package that imports neither SwiftUI nor AppKit, and a test SHALL
fail if any of its sources does.

Source: `product.md` and `project-map.md` (Recommended), confirmed by the maintainer 2026-11-02: a
Windows port rewrites the UI only.

#### Scenario: A UI import in the core

- **WHEN** a source file in the core package imports SwiftUI or AppKit
- **THEN** the boundary test fails and names the file

### Requirement: The UI does no networking

The app target's sources SHALL make no network requests of their own; they reach a host only through
the core. A test SHALL fail if an app-target source imports Network or uses `URLSession`.

Source: `project-map.md` (Recommended), confirmed by the maintainer 2026-11-02: every request must
follow the host's rules, such as sending no `Origin` header.

#### Scenario: Networking in the UI

- **WHEN** a source file in the app target imports Network or uses `URLSession`
- **THEN** the boundary test fails and names the file
