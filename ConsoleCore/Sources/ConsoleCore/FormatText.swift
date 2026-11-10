/// A sample format in the words the Input and Output section shows it in (`mac-output` design D1,
/// D2).
public enum FormatText {
    /// A capture format the host names as ALSA does: `S16_LE` is 16-bit, and `S32_LE`, which the
    /// host declares as 24 bits in 32, is 24-bit in 32-bit. Any other is shown by its own name.
    public static func capture(_ name: String) -> String {
        switch name {
        case "S16_LE": "16-bit"
        case "S32_LE": "24-bit in 32-bit"
        default: name
        }
    }

    /// Whether a capture format the host names is 16 bits, which limits the noise floor the panel
    /// can read.
    public static func isShallowCapture(_ name: String) -> Bool {
        name == "S16_LE"
    }

    /// An output format as Audio MIDI Setup words it: `24-bit Integer`, `32-bit Float`.
    public static func output(_ format: OutputFormat) -> String {
        "\(format.bits)-bit \(format.isFloat ? "Float" : "Integer")"
    }
}
