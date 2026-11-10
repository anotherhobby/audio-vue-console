# Proposal

## Why

A calibration measures the whole path from the file to the capture. It sets this Mac's output to
the run's rate, so nothing on the way resamples. A rate chosen on the Capture page changes only the
panel's capture rate. Afterwards the Mac plays at one rate while the panel captures at another, and
the path the panel measures is not the one that was calibrated. Nothing on the page shows that.
Bit depth has the same gap on both sides. The panel's capture format (`input.fmt`) defaults to 16
bits and is not shown. A calibration never sets the Mac's bit depth, so an output left at 16 bits
puts its quantization floor into the record.

## What Changes

- **The Input section shows this Mac's output beside the panel's input** (maintainer, 2026-11-09):
  - Capture Device (audio-vue)
  - Capture Rate (audio-vue)
  - Capture Format (audio-vue)
  - Output Device (this Mac)
  - Output Rate (this Mac)
  - Output Format (this Mac)
  - Synchronize Rates
- **Capture Format** reads and writes the `input` block's `fmt` from the choices the host's schema
  declares, the same way as the device and rate.
- **Output Device** is the device remembered for the panel. Choosing it moves from Calibrate… to the
  Input section, and Calibrate… plays through the device chosen there.
- **Output Rate and Output Format** show the device's rate and bit depth as Core Audio reports them,
  following changes made elsewhere. Choosing one sets the device directly through Core Audio,
  without `cal-play`'s settling wait.
- **Synchronize Rates**, remembered per panel, makes the capture rate lead:
  - Turning it on, or changing the capture rate, sets the Mac's output to match.
  - Changing the output rate while it is on writes the capture rate too, asking first as a capture
    change does.
  - A change made in Audio MIDI Setup or by another client is not followed. It shows as a mismatch.
- **A mismatch is shown.** Where the Mac's rate differs from the capture rate, the section says so,
  whether or not Synchronize Rates is on. That includes a capture rate the output cannot play.
- **A format below 24 bits is flagged** on either side, because it limits the noise floor the panel
  can read.
- **A calibration with Synchronize Rates on ends with the output at the capture rate.** After a
  pass of every rate, the output goes back to the capture rate. This replaces leaving it at the last
  rate played for a synchronized output.
- **A calibration sets the output's bit depth as well as its rate.** `cal-play`'s rate command is
  asked to set the deepest integer format the device offers at the rate, in the same settling wait.
  Calibrate… warns when the output offers nothing deeper than 16 bits.

Out of scope:
- Synchronizing bit depth. A bit-depth mismatch adds no resampler; each side should simply be at 24
  bits or more.
- Following the music's own rate.
- Outputs on another machine.
- Whether the host should treat the capture format as part of the chain a record applies to.

## Capabilities

### New Capabilities

- `mac-output`: this Mac's output on the Capture page. Covers the device feeding the panel, its rate
  and bit depth read from and set through Core Audio, Synchronize Rates, the mismatch and low-depth
  flags, and returning a synchronized output to the capture rate after a calibration.

### Modified Capabilities

- `capture-input`:
  - "The Input section shows the installed device and rate" shows the capture format too.
  - A new requirement chooses the format from the formats the host declares.
  - "A change is written to the host on the block's revision" writes `fmt` with the device and
    rate.
- `calibration-run`: "A run names the output device feeding the panel" takes the device chosen in
  the Input section, and Calibrate… cannot start without one.
- `calibration-player`: "The rate is set before the arm" sets the output's bit depth with its rate,
  and Calibrate… warns about an output with no format deeper than 16 bits.

## Impact

- **Code:**
  - `ConsoleCore` gains a Core Audio model of one output device: its rate, its formats, setting
    either, and following changes. `OutputDevices` and `CoreAudioOutputDevices` gain the reads and
    writes behind it.
  - `PanelInput` and `InputEdit` gain `fmt` and the schema's formats (`SchemaFacts`).
  - `PlaybackDeviceMemory` remembers Synchronize Rates per panel.
  - In the app target, `InputSection` gains the capture format. A new view holds the output rows
    and Synchronize Rates. `CalibrateSheet` loses its output picker and names the chosen device.
    `CapturePage` returns a synchronized output to the capture rate when a pass ends.
- **Sequencing:** only the calibration's bit depth waits on audio-vue. Everything else can be built
  now.
- **Host:** one new ask, `mac-output-handoff.md` in audio-vue's root. It asks for `cal-play rate` to
  set the deepest integer format the device offers at the rate, holding its settle if either the
  rate or the format changed, and to say what it set.
- **Referenced specs relied on:**
  - `audio-vue:settings-schema`: `input.fmt` is declared, with its choices and chain class.
  - `audio-vue:settings-store`: an install block is written on its revision, and a chain write
    restarts a running panel and is refused during a calibration.
  - `audio-vue:control-api`: `PUT /v1/install/{block}` and `GET /v1/schema`.
  - `audio-vue:calibration-record`: the newest valid record for device and rate is in force.
  - `audio-vue:calibration-lifecycle`: the hold after a run ends only on a held level, so a click
    from a rate change does not end it; and the chain settles after a rate change.
