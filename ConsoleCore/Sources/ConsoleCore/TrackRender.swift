import CoreGraphics
import Foundation
import Observation

/// The Render with Track sheet's state (`track-render`; design D4, D5): the track picked, the
/// picture at the moment chosen, and the still or clip being exported, through a helper of the
/// sheet's own.
@MainActor @Observable
public final class TrackRender: Identifiable {
    /// How long the moment must rest before its picture is asked for (maintainer, 2026-11-23).
    public static let rest = Duration.milliseconds(restMilliseconds)
    private static let restMilliseconds: Int64 = 200
    /// A new clip's length, from the moment shown (maintainer, 2026-11-23).
    public static let clipSeconds = 20.0

    /// The track picked, once it passes the panel's checks.
    public private(set) var source: TrackSource?
    /// Why the last track picked could not be used, or why the last picture or export failed.
    public private(set) var failure: String?
    /// What the helper said on opening the track.
    public private(set) var opening: TrackOpening?
    /// The picture shown, and the moment it was asked at, in seconds.
    public private(set) var picture: TrackPicture?
    public private(set) var shownSeconds = 0.0
    /// True while a track is decoded and opened, or a picture is drawn.
    public private(set) var isWorking = false
    /// Frames written of the clip under way, nil when none is.
    public private(set) var written: Int?

    private let session: TrackSession
    private let scene: JSONValue
    private let builtIn: Bool
    private let context: RenderContext
    private let rates: [Int]
    /// Where the picked track is decoded to.
    private let tracks: URL
    private var track: DecodedTrack?
    private var greeted = false
    /// The newest moment asked for while a picture was being drawn.
    private var waiting: Double?
    private var resting: Task<Void, Never>?
    private var clip: Task<Void, Never>?

    public init(
        helper: RenderHelper, scene: JSONValue, builtIn: Bool, context: RenderContext,
        rates: [Int], tracks: URL = TrackSource.defaultDirectory
    ) {
        session = TrackSession(helper: helper)
        self.tracks = tracks
        self.scene = scene
        self.builtIn = builtIn
        self.context = context
        self.rates = rates
    }

    /// The size every picture is drawn at: the panel's display.
    public var display: PixelSize { context.display }

    /// The track's length in seconds, by the helper's count once opened.
    public var seconds: Double {
        guard let source else { return 0 }
        let samples = opening?.length ?? source.frames
        return Double(samples) / Double(source.rate)
    }

    /// Whether a picture is shown and nothing is under way, so a still or a clip can be exported.
    public var canExport: Bool { picture != nil && !isWorking && written == nil }

    /// Picks `url` as the track: checks it, decodes it, greets the helper the first time, opens the
    /// track, and draws its first moment. The last track's samples are removed.
    public func choose(_ url: URL) async {
        discardTrack()
        failure = nil
        do {
            source = try TrackSource.open(url, rates: rates)
        } catch {
            failure = error.description
            return
        }
        isWorking = true
        defer { isWorking = false }
        await open()
    }

    private func open() async {
        guard let source else { return }
        do {
            let decoded = try await source.decode(into: tracks)
            track = decoded
            if !greeted {
                _ = try await session.greet()
                greeted = true
            }
            opening = try await session.open(
                decoded, scene: scene, builtIn: builtIn, context: context)
        } catch let refusal as TrackRefusal {
            failure = refusal.description
            return
        } catch {
            failure = Self.words(error)
            return
        }
        await draw(at: 0)
    }

    /// The moment moving: its picture is asked for once it has rested.
    public func scrub(to seconds: Double) {
        resting?.cancel()
        resting = Task {
            do {
                try await Task.sleep(for: Self.rest)
            } catch {
                return
            }
            await show(seconds)
        }
    }

    /// The moment let go: its picture is asked for at once.
    public func release(at seconds: Double) {
        resting?.cancel()
        Task { await show(seconds) }
    }

    /// Asks for the picture at `seconds`, or, while one is drawn, keeps it as the one to draw next,
    /// in place of any kept before (design D5).
    func show(_ seconds: Double) async {
        guard track != nil else { return }
        guard !isWorking else {
            waiting = seconds
            return
        }
        isWorking = true
        defer { isWorking = false }
        var next: Double? = seconds
        while let wanted = next {
            await draw(at: wanted)
            next = waiting
            waiting = nil
        }
    }

    private func draw(at seconds: Double) async {
        guard let source else { return }
        do throws(RenderFailure) {
            picture = try await session.picture(at: moment(seconds, rate: source.rate))
            shownSeconds = seconds
            failure = nil
        } catch {
            failure = "The picture could not be drawn. \(Self.words(error))"
        }
    }

    /// `seconds` as a sample, kept within the track.
    private func moment(_ seconds: Double, rate: Int) -> Int {
        let last = max((opening?.length ?? 0) - 1, 0)
        return min(max(Int((Double(rate) * seconds).rounded()), 0), last)
    }

    /// Saves the picture shown as a PNG at `url`.
    public func exportStill(to url: URL) {
        guard let picture else { return }
        do {
            try StillWriter.write(picture, to: url)
        } catch {
            failure = error.description
        }
    }

    /// Writes the clip from `start` to `end` at `fps` to `url`, counting the frames written.
    public func exportClip(from start: Double, to end: Double, fps: Int, at url: URL) {
        guard let source, clip == nil else { return }
        let writer = ClipWriter(
            plan: ClipPlan(rate: source.rate, fps: fps, start: start, end: min(end, seconds)),
            audio: source.url, channels: source.channels, size: context.display)
        written = 0
        failure = nil
        clip = Task { [session] in
            do throws(ExportFailure) {
                try await writer.write(to: url, from: session) { count in
                    Task { @MainActor in self.written = count }
                }
            } catch {
                if error != .cancelled { failure = error.description }
            }
            written = nil
            clip = nil
        }
    }

    /// Stops the clip under way, leaving no file.
    public func cancelClip() {
        clip?.cancel()
    }

    /// Ends the sheet's helper and removes the decoded samples, as the sheet closes.
    public func close() async {
        resting?.cancel()
        clip?.cancel()
        await clip?.value
        await session.stop()
        discardTrack()
    }

    private func discardTrack() {
        track?.remove()
        track = nil
        source = nil
        opening = nil
        picture = nil
        shownSeconds = 0
    }

    private static func words(_ error: any Error) -> String {
        switch error as? RenderFailure {
        case .refused(let reason)?, .failed(let reason)?, .unavailable(let reason)?: reason
        case .ended?: "The renderer stopped."
        case nil: error.localizedDescription
        }
    }
}
