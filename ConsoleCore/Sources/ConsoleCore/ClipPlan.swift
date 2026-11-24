/// The frames of a clip: each one's moment in the track, in samples (`track-render`, "A clip runs at
/// 30 or 60 frames a second"; audio-vue `track-render` hand-off).
public struct ClipPlan: Sendable, Equatable {
    /// The frame rate a clip is made at unless the user asks for the other (maintainer,
    /// 2026-11-23).
    public static let defaultFrameRate = 30
    /// The other frame rate a clip is offered at.
    public static let smoothFrameRate = 60
    /// The frame rates a clip is offered at, the default first.
    public static let frameRates = [defaultFrameRate, smoothFrameRate]

    /// The track's rate, in Hz.
    public let rate: Int
    /// Frames a second.
    public let fps: Int
    /// The span's start and end, in seconds from the track's start.
    public let start: Double
    public let end: Double

    public init(rate: Int, fps: Int, start: Double, end: Double) {
        self.rate = rate
        self.fps = fps
        self.start = start
        self.end = end
    }

    /// How many frames the span holds: every frame whose time is before its end.
    public var count: Int {
        guard end > start else { return 0 }
        let exact = (end - start) * Double(fps)
        let whole = exact.rounded(.down)
        return Int(whole == exact ? whole : whole + 1)
    }

    /// Frame `index`'s moment: `round(rate × (start + index / fps))`.
    public func moment(_ index: Int) -> Int {
        Int((Double(rate) * (start + Double(index) / Double(fps))).rounded())
    }

    /// Every frame's moment, in order.
    public var moments: [Int] { (0..<count).map(moment) }
}
