/// One of the host's capture devices and each way it streams, as the host's listing gives them
/// (audio-vue `control-api`, "Each capture device says how it streams"; `capture-input`).
public struct CaptureDevice: Sendable, Equatable, Identifiable {
    /// One way the device captures: a format, a channel count and the rates it takes that way.
    public struct Stream: Sendable, Equatable {
        /// The sample format, as ALSA names it; it may be one the panel does not capture.
        public let format: String
        public let channels: Int
        /// In Hz; they may include rates the panel does not capture.
        public let rates: [Int]

        public init(format: String, channels: Int, rates: [Int]) {
            self.format = format
            self.channels = channels
            self.rates = rates
        }
    }

    /// The device, as ALSA names it and capture opens it.
    public let name: String
    /// Each way it streams, or nil where the host cannot read them: unknown, not none.
    public let streams: [Stream]?

    public var id: String { name }

    public init(name: String, streams: [Stream]? = nil) {
        self.name = name
        self.streams = streams
    }

    /// Those of `declared`, the formats the panel captures, that the device streams, in their
    /// order; all of them where how it streams is not known.
    public func formats(among declared: [String]) -> [String] {
        guard let streams else { return declared }
        return declared.filter { format in streams.contains { $0.format == format } }
    }

    /// Those of `declared`, the rates the panel captures, that the device takes in `format`, in
    /// their order; all of them where how it streams is not known.
    public func rates(among declared: [Int], format: String?) -> [Int] {
        guard let ways = ways(format: format) else { return declared }
        return declared.filter { rate in ways.contains { $0.rates.contains(rate) } }
    }

    /// The most channels the device streams in `format` at `rate`, which is what the host counts
    /// a pair against; nil where how it streams is not known, or it has no such way.
    public func channels(format: String?, rate: Int) -> Int? {
        ways(format: format)?.filter { $0.rates.contains(rate) }.map(\.channels).max()
    }

    /// The ways that take `format`, every way for no format; nil where they are not known.
    private func ways(format: String?) -> [Stream]? {
        streams?.filter { format == nil || $0.format == format }
    }
}

/// A device, rate, format and channel pair for the panel's input: a nil device is the host's
/// default device, and a nil format one the host declares none of.
public struct InputChoice: Sendable, Equatable {
    public var device: String?
    public var rate: Int
    public var format: String?
    /// Which two of the stream's channels are measured, as left and right, counted from 0.
    public var pair: [Int]

    /// The pair a block that sets none takes where the schema declares no default.
    public static let firstPair = [0, 1]

    public init(
        device: String? = nil, rate: Int, format: String? = nil, pair: [Int] = firstPair
    ) {
        self.device = device
        self.rate = rate
        self.format = format
        self.pair = pair
    }

    /// This choice as `device` can stream it, `formats` and `rates` being those the panel
    /// captures: the format kept where the device offers it, else its first; the rate kept where
    /// it takes it in that format, else the nearest it takes; and the pair put back to the first
    /// two channels where it reaches past the channels streamed. A device whose ways are not
    /// known, or the default device, changes nothing.
    public func fitted(to device: CaptureDevice?, formats: [String], rates: [Int]) -> InputChoice {
        guard let device, device.streams != nil else { return self }
        var fitted = self
        let offered = device.formats(among: formats)
        if let format, !offered.contains(format), let first = offered.first {
            fitted.format = first
        }
        let taken = device.rates(among: rates, format: fitted.format)
        if !taken.contains(rate), let nearest = taken.min(by: { abs($0 - rate) < abs($1 - rate) }) {
            fitted.rate = nearest
        }
        if let channels = device.channels(format: fitted.format, rate: fitted.rate),
            pair.contains(where: { $0 >= channels })
        {
            fitted.pair = Self.firstPair
        }
        return fitted
    }
}
