import Foundation
import Synchronization
import Testing

@testable import ConsoleCore

/// The Render with Track sheet's state: `render-helper`, "A track render's helper is greeted
/// before its first track"; `track-render`, "The sheet shows the picture at the moment chosen" and
/// "The decoded samples are removed with the sheet".
@MainActor
struct TrackRenderTests {
    private static func render(_ launcher: ScriptedLauncher, in directory: URL) throws
        -> TrackRender
    {
        TrackRender(
            helper: RenderHelper(launcher: launcher), scene: TrackSessionTests.scene,
            builtIn: false, context: TrackSessionTests.context, rates: try TestTracks.panelRates(),
            tracks: directory.appending(path: "Tracks"))
    }

    @Test func pickingATrackGreetsOpensAndDrawsItsStart() async throws {
        let directory = try TestTracks.directory()
        defer { DecodedTrack.discard(directory) }
        let launcher = ScriptedLauncher { TrackSessionTests.reply(to: $0) }
        let render = try Self.render(launcher, in: directory)
        await render.choose(
            try TestTracks.wav(rate: 48_000, channels: 2, seconds: 1, in: directory))
        #expect(render.failure == nil)
        #expect(render.picture?.width == 2)
        #expect(
            launcher.requests.map { $0["op"]?.stringValue } == ["hello", "track", "picture"])
        #expect(launcher.requests.last?["moment"] == .integer(0))
        #expect(render.seconds == 10)
    }

    @Test func aTrackThePanelCannotTakeIsNeverSent() async throws {
        let directory = try TestTracks.directory()
        defer { DecodedTrack.discard(directory) }
        let launcher = ScriptedLauncher { TrackSessionTests.reply(to: $0) }
        let render = try Self.render(launcher, in: directory)
        await render.choose(
            try TestTracks.wav(rate: 22_050, channels: 2, seconds: 0.1, in: directory))
        #expect(render.failure?.hasPrefix("This track is at 22.05 kHz.") == true)
        #expect(render.source == nil)
        #expect(launcher.launches == 0)
    }

    @Test func whileAPictureIsDrawnOnlyTheNewestMomentWaits() async throws {
        let directory = try TestTracks.directory()
        defer { DecodedTrack.discard(directory) }
        let pictures = Mutex(0)
        let launcher = ScriptedLauncher { request in
            guard request["op"] == .string("picture") else {
                return TrackSessionTests.reply(to: request)
            }
            let count = pictures.withLock { count in
                count += 1
                return count
            }
            return count == 2
                ? .heldWith(
                    #"{"ok": true, "width": 2, "height": 1, "drawn": 0, "bytes": 6}"#,
                    payload: Data(count: 6))
                : TrackSessionTests.reply(to: request)
        }
        let render = try Self.render(launcher, in: directory)
        await render.choose(
            try TestTracks.wav(rate: 48_000, channels: 2, seconds: 1, in: directory))
        let first = Task { await render.show(1) }
        for _ in 0..<200 where pictures.withLock({ $0 }) < 2 {
            try await Task.sleep(for: .milliseconds(5))
        }
        await render.show(2)
        await render.show(3)
        launcher.releaseHeld()
        await first.value
        let moments = launcher.requests.filter { $0["op"] == .string("picture") }.map(\.["moment"])
        #expect(moments == [.integer(0), .integer(48_000), .integer(144_000)])
        #expect(render.shownSeconds == 3)
    }

    @Test func closingEndsTheHelperAndRemovesTheSamples() async throws {
        let directory = try TestTracks.directory()
        defer { DecodedTrack.discard(directory) }
        let launcher = ScriptedLauncher { TrackSessionTests.reply(to: $0) }
        let render = try Self.render(launcher, in: directory)
        let track = try TestTracks.wav(rate: 48_000, channels: 2, seconds: 1, in: directory)
        await render.choose(track)
        let tracks = directory.appending(path: "Tracks")
        #expect(try FileManager.default.contentsOfDirectory(atPath: tracks.path).count == 1)
        await render.close()
        #expect(try FileManager.default.contentsOfDirectory(atPath: tracks.path).isEmpty)
        #expect(render.picture == nil)
    }
}
