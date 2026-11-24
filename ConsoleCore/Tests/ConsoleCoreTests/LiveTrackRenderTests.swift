import Foundation
import Testing

@testable import ConsoleCore

/// The real render helper drawing from a track (audio-vue `track-render`), run only when
/// `RENDER_HELPER_LIVE=1` (`commands.md`). It prints its timings.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["RENDER_HELPER_LIVE"] == "1"))
struct LiveTrackRenderTests {
    private static let display = PixelSize(width: 1920, height: 720)

    @Test func theRTASceneReadsATrackAndMakesAClip() async throws {
        let directory = try TestTracks.directory()
        defer { DecodedTrack.discard(directory) }
        let wav = try TestTracks.wav(rate: 48_000, channels: 2, seconds: 10, in: directory)
        let track = try await TrackSource.open(wav, rates: try TestTracks.panelRates())
            .decode(into: directory)
        let scene = try JSONDecoder().decode(
            JSONValue.self, from: Data(contentsOf: LiveHelperTests.fixture))
        let session = TrackSession(helper: LiveHelperTests.helper())
        _ = try await session.greet()
        let context = RenderContext(
            display: Self.display, viewing: .object([:]), images: directory)
        let opening = try await LiveHelperTests.timed("track") {
            try await session.open(track, scene: scene, builtIn: true, context: context)
        }
        #expect(opening.length == 480_000)

        let early = try await LiveHelperTests.timed("picture at 1 s") {
            try await session.picture(at: 48_000)
        }
        #expect(early.width == 1920)
        #expect(early.height == 720)
        #expect(early.drawn <= 48_000)
        let later = try await LiveHelperTests.timed("picture at 5 s") {
            try await session.picture(at: 240_000)
        }
        #expect(later.rgb != early.rgb)

        let writer = ClipWriter(
            plan: ClipPlan(rate: 48_000, fps: 30, start: 3, end: 5), audio: wav, channels: 2,
            size: Self.display, scratch: directory.appending(path: "Clips"))
        let clip = directory.appending(path: "clip.mp4")
        try await LiveHelperTests.timed("clip, 2 s at 30 fps from 3 s") {
            try await writer.write(to: clip, from: session)
        }
        #expect(FileManager.default.fileExists(atPath: clip.path))
        await session.stop()
    }
}
