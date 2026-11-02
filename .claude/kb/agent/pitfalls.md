# Pitfalls

Record recurring mistakes, broken assumptions, environment quirks, and sharp edges.

## Calibration: set the rate, wait, then arm (2026-11-02)

`cal-play` holds `SETTLE_S`, 12 s, after any change of the device's rate; a chain was measured settling
in 9.9 to 10.5 s. An armed panel waits 10 s for the stimulus. So a `play` that changes the rate spends
the whole arm deadline settling, and the calibration fails. Run `cal-play rate` first, then arm, then
play, as `make calibrate` does. `../audio-vue/.claude/kb/agent/cal-play.md`, "A rate change holds for
the chain".

## The host refuses any `Origin` header (2026-11-02)

The agent answers a request carrying an `Origin` header with a 403, and closes such a WebSocket with
1008, whatever the origin (`host-contract.md`). From memory, not checked: some Swift WebSocket
libraries add an `Origin` by default. Check what the chosen client sends before blaming the token.

## Identify scenes by spec, never by name (2026-11-02)

A scene's `name` is a label (`Glass check`); its spec is the filename stem the host resolves. In
audio-vue this hid on macOS, where a case-insensitive filesystem resolved labels that differed only in
case, and failed on the Pi. Anything the app hands back to the host as a scene's identity uses the
spec. `../audio-vue/.claude/kb/agent/pitfalls.md`, "A scene's `name` is a label".

## A token can stop working without a revocation (2026-11-02)

audio-vue is unreleased, and a host store on another version is deleted and made again, so its clients
must pair again. Treat a 401 on a stored token as "pair again", not as a fault.

## The gate's type check builds SwiftPM packages only (2026-11-02)

The quality gate's Stop-hook type check does not build an Xcode project, so code in the app shell goes
unchecked there. Keep logic in packages and the shell thin.
