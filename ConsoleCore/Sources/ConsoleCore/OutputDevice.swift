/// An output device on this Mac: CoreAudio's unique id, which outlasts a reconnect, and its name,
/// which is what `cal-play` is given (design D2). CoreAudio may end a name with a space, as the
/// D10s's `D10s `; the name is kept as given. Its available nominal rates and formats are read by
/// `OutputControl` (`mac-output` design D3).
public struct OutputDevice: Sendable, Hashable, Identifiable {
    public let uid: String
    public let name: String
    /// The nominal rates CoreAudio says the device can be set to, in Hz, each a range or a single
    /// rate.
    public let availableRates: [ClosedRange<Double>]
    /// The formats its output stream offers, each with the rates it is offered at (`mac-output`
    /// design D2).
    public let formats: [OutputFormatRange]
    public var id: String { uid }

    public init(
        uid: String, name: String, availableRates: [ClosedRange<Double>] = [],
        formats: [OutputFormatRange] = []
    ) {
        self.uid = uid
        self.name = name
        self.availableRates = availableRates
        self.formats = formats
    }

    /// The distinct formats the device offers at `hertz`, deepest first.
    public func formats(at hertz: Int) -> [OutputFormat] {
        let rate = Double(hertz)
        let offered = formats.filter {
            rate >= $0.rates.lowerBound - Self.tolerance
                && rate <= $0.rates.upperBound + Self.tolerance
        }
        return Array(Set(offered.map(\.format))).sorted(by: OutputFormat.deeperFirst)
    }

    /// The deepest integer format's bits at `hertz`, or nil where it offers no integer format.
    public func deepestInteger(at hertz: Int) -> Int? {
        formats(at: hertz).first { !$0.isFloat }?.bits
    }

    /// How far from a range a rate may fall and still be in it, for rates CoreAudio reports as
    /// doubles.
    private static let tolerance = 0.5

    /// Whether the device can be set to `hertz`.
    public func offers(_ hertz: Int) -> Bool {
        let rate = Double(hertz)
        return availableRates.contains {
            rate >= $0.lowerBound - Self.tolerance && rate <= $0.upperBound + Self.tolerance
        }
    }
}
