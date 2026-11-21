# Code alignment

## Read

Pass 1, 2026-11-20, on `dev` at `e47c193` with `scene-settings`' rebuild uncommitted; audio-vue at
`e4d8e71` by its hand-off, its listing and block read from the regenerated contract.

- `HostClient+Install.swift`: `captureDevices` (names only), `writeInstall` (422 as `.invalid`).
- `PanelInput.swift`: `devices`, `formatChoices`, `rateChoices`, `write(device:rate:format:)`,
  `refused`, `show`.
- `InputEdit.swift`: `doc(block:device:rate:format:)`.
- `AudioVueConsole/Calibration/InputSection.swift` (`InputChoice`, `InputShown`, `choose`, `write`,
  the output's rate path) and `InputRows.swift`.
- `PanelState.swift`: the sections read; no `run`.
- The saved contract: `Device`, `Stream`, `Devices`, `Run` (`phase`, `screen_status`).
- The standing `capture-input` spec, every requirement.
- `grep 'write(device'` and `'InputChoice('` over the app and tests: every caller updated.

## Findings

- **F1. The listing is objects, not names** (resolved)
  - Code: `Devices.devices` is `[Device]`; `captureDevices` returned `[String]`.
  - Goes to: design D1, task 1.1.
- **F2. The hand-off's `streams: null` is an absent key in the saved contract** (resolved)
  - Code: `tools/optional_nullables.py` writes a nullable as optional, so `Device.streams` is
    optional; a JSON null decodes as nil too. Checked by `PanelInputTests`, whose listing sends
    null.
  - Goes to: nothing.
- **F3. A refused input read as an unexpected answer** (resolved)
  - Code: `PanelInput.refused` sent `.invalid` to `Note.failed`, worded "answered in a way this app
    didn't expect".
  - Goes to: design D5, task 1.3.
- **F4. The standing scenario "A new rate" keeps `pair` `[2, 3]`** (resolved)
  - Code: the pair now rides in the choice, read from the block at load, so a rate change still
    sends it. `PanelInputTests` holds it.
  - Goes to: nothing.

## Questions for the maintainer

None open. Ruled (maintainer, 2026-11-20): fix the cause, not the setting.

## Confirmed

- `stream_channels` is not in the schema's `install.input`, and the app never wrote it.
- The pair's default is declared (`[0, 1]`), read by `SchemaFacts.inputPairDefault`.
- The app reads `run` from the same state message the Panel page uses; no new route.
