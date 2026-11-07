# Spec Delta

## Purpose

How the app runs the render helper it carries, the child process that draws scenes from the panel's
own code: when it starts, what it may write, how its requests and failures are handled.

## ADDED Requirements

### Requirement: The helper is a child of the app

The app SHALL run the render helper it carries as a child process, speaking its protocol over the
child's standard input and output, and SHALL end it when the app quits. The app SHALL run no code it
received from a host.

Source: `product.md`, "The decision" (maintainer, 2026-11-06): the card code is bundled into the app,
never downloaded. audio-vue `scene-render`: the helper speaks over its standard streams.

#### Scenario: Quitting

- **WHEN** the app quits while the helper is running
- **THEN** the helper's standard input is closed and the helper ends

### Requirement: The helper starts once the app is paired

The app SHALL start the helper when it is paired with a host, SHALL ask it which code it carries,
and SHALL then ask it to make the run for the default analysis settings at the preview rate,
48 000 Hz. While not paired it SHALL start none.

Source: Decision (maintainer, 2026-11-07): wait to launch the helper until connected; the rate does
not matter to a preview, so pick one. audio-vue `scene-render`: the helper prepares a frame on
request.

#### Scenario: Pairing

- **WHEN** the app becomes paired with a host whose installed rate is 96 000 Hz
- **THEN** the helper is started, asked for its code's digest, then asked to prepare the default run at
  48 000 Hz

#### Scenario: Not paired

- **WHEN** the app launches and the host it holds does not take its token
- **THEN** no helper is started

### Requirement: The helper's caches live in the app's container

The app SHALL give the helper a directory of the app's own for its compiled-code cache, and one for
Python's bytecode, both in the app's container, so a start after the first does not pay the cache's
cost again.

Source: audio-vue's handoff (2026-11-07): every `@njit` caches its code in the directory
`NUMBA_CACHE_DIR` names, and a signed app cannot write inside itself. Measured (2026-11-07), the
bundled helper sandboxed: the default scene took 7.2 s with both caches empty and 2.0 s filled.

#### Scenario: A second start

- **WHEN** the app starts the same helper a second time
- **THEN** the helper finds the compiled code the first start cached

### Requirement: The helper's error output is read

The app SHALL read everything the helper writes to its standard error while it runs, and SHALL
keep it in the app's log, so a full pipe never stops the helper.

Source: audio-vue's handoff (2026-11-07): notices and tracebacks go to standard error, and a pipe
nobody reads fills and blocks the helper (inferred).

#### Scenario: A traceback

- **WHEN** the helper writes a traceback to standard error and ends
- **THEN** the traceback is in the app's log

### Requirement: Requests are answered one at a time, in order

The app SHALL send the helper one request at a time and SHALL read each answer, with its layers'
bytes, before sending the next.

Source: audio-vue `scene-render`: requests are answered one at a time, in the order sent.

#### Scenario: Two requests at once

- **WHEN** the canvas asks for a plate while a thumbnail's render is under way
- **THEN** the plate's request is sent after the thumbnail's answer has been read

### Requirement: A helper that ends is started again

When the helper ends, or answers with anything the protocol does not allow, the app SHALL treat what
it was asked as failed, saying so where it was asked, and SHALL start a new helper for the next
request. A request the helper refuses SHALL NOT start it again.

Source: audio-vue's handoff (2026-11-07): anything the helper cannot do ends it, with the traceback on
standard error: restart it. A refused scene is an answer, not an end.

#### Scenario: The helper crashes

- **WHEN** the helper ends while drawing a scene
- **THEN** the canvas says the scene could not be drawn, and the next request starts a new helper

#### Scenario: A refused scene

- **WHEN** the helper refuses a scene, giving the panel's reason
- **THEN** the canvas shows the reason, and the same helper answers the next request
