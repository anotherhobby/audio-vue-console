import Foundation

/// One picture of a scene reading a track: opaque 8-bit RGB, top row first, with no padding.
public struct TrackPicture: Sendable, Equatable {
    public let width: Int
    public let height: Int
    /// The sample the analysis ends at: the last whole block's end at or before the moment asked.
    public let drawn: Int
    public let rgb: Data

    public init(width: Int, height: Int, drawn: Int, rgb: Data) {
        self.width = width
        self.height = height
        self.drawn = drawn
        self.rgb = rgb
    }

    /// Red, green and blue, a byte each.
    public static let bytesPerPixel = 3

    /// The bytes an RGB picture of `width` by `height` takes.
    public static func byteCount(width: Int, height: Int) -> Int {
        width * height * bytesPerPixel
    }
}

/// What the helper said on opening a track: its length, and what it could not draw (`track-render`,
/// "The sheet says what the helper could not draw").
public struct TrackOpening: Sendable, Equatable {
    /// The track's length in samples.
    public let length: Int
    /// The helper's notice naming a backdrop image it could not draw, worded for the sheet.
    public let notice: String?
    /// The helper's notice naming a style the request did not carry.
    public let styleNotice: String?
}

/// A track open in a helper of its own, drawn at the moments asked (design D4). It sends `track`
/// once, and again before the next picture after the helper ends, since a new helper has no track
/// open (`render-helper`, "A track render's helper that ends is started again").
public actor TrackSession {
    private let helper: RenderHelper
    /// The `track` request last sent, to send again after the helper ends.
    private var opening: JSONValue?
    private var isOpen = false

    public init(helper: RenderHelper) {
        self.helper = helper
    }

    /// Asks the helper which code it carries, as before its first track (`render-helper`, "A track
    /// render's helper is greeted before its first track").
    public func greet() async throws(RenderFailure) -> String {
        try await helper.hello()
    }

    /// Opens `track` for `scene` as `context` draws it, closing any track open before.
    public func open(
        _ track: DecodedTrack, scene: JSONValue, builtIn: Bool, context: RenderContext
    ) async throws(RenderFailure) -> TrackOpening {
        var fields = context.fields(for: scene, builtIn: builtIn)
        fields["op"] = .string("track")
        fields["path"] = .string(track.samples.path(percentEncoded: false))
        fields["rate"] = .integer(track.source.rate)
        fields["channels"] = .integer(track.source.channels)
        let message = JSONValue.object(fields)
        opening = message
        isOpen = false
        let answer = try await send(message)
        isOpen = true
        return Self.opening(answer.header)
    }

    /// The picture at `moment`, in samples from the track's start. A moment earlier than the last
    /// makes the helper analyse from the first sample again.
    public func picture(at moment: Int) async throws(RenderFailure) -> TrackPicture {
        if !isOpen, let opening {
            _ = try await send(opening)
            isOpen = true
        }
        let answer = try await send(
            .object(["op": .string("picture"), "moment": .integer(moment)]))
        guard let width = answer.header["width"]?.intValue,
            let height = answer.header["height"]?.intValue,
            let drawn = answer.header["drawn"]?.intValue,
            answer.payload.count == TrackPicture.byteCount(width: width, height: height)
        else { throw .failed("The renderer's picture was not the size it stated.") }
        return TrackPicture(width: width, height: height, drawn: drawn, rgb: answer.payload)
    }

    /// Ends the helper, as the sheet does when it closes.
    public func stop() async {
        await helper.stop()
        isOpen = false
    }

    /// Sends `message`, marking the track closed where the helper ended.
    private func send(_ message: JSONValue) async throws(RenderFailure) -> HelperAnswer {
        do {
            return try await helper.ask(message)
        } catch {
            if error == .ended { isOpen = false }
            throw error
        }
    }

    private static func opening(_ header: JSONValue) -> TrackOpening {
        TrackOpening(
            length: header["length"]?.intValue ?? 0,
            notice: header["notice"]?.stringValue.map(HelperNotice.text),
            styleNotice: header["style_notice"]?.stringValue)
    }
}
