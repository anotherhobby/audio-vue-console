/// A physical format an output device plays at: its bit depth, and whether its samples are
/// integers or floats (`mac-output` design D2).
public struct OutputFormat: Sendable, Hashable {
    public let bits: Int
    public let isFloat: Bool

    public init(bits: Int, isFloat: Bool) {
        self.bits = bits
        self.isFloat = isFloat
    }

    /// The depth under which a device limits the noise floor the panel can read: the player's
    /// bit-perfect path holds from 24 bits (audio-vue `cal-play.md`).
    public static let fullDepthBits = 24

    /// Whether the format is shallower than the player's bit-perfect path needs.
    public var isShallow: Bool { bits < Self.fullDepthBits }

    /// Deepest first, integer before float at the same depth.
    static func deeperFirst(_ lhs: OutputFormat, _ rhs: OutputFormat) -> Bool {
        lhs.bits != rhs.bits ? lhs.bits > rhs.bits : !lhs.isFloat && rhs.isFloat
    }
}

/// A format a device offers, with the nominal rates it offers it at, as Core Audio lists its output
/// stream's available physical formats.
public struct OutputFormatRange: Sendable, Hashable {
    public let format: OutputFormat
    public let rates: ClosedRange<Double>

    public init(format: OutputFormat, rates: ClosedRange<Double>) {
        self.format = format
        self.rates = rates
    }
}
