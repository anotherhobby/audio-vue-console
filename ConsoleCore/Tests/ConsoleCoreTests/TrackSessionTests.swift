import Foundation
import Synchronization
import Testing

@testable import ConsoleCore

/// The track session: `track` and `picture` (audio-vue `render_service.py`), and `render-helper`,
/// "A track render's helper that ends is started again".
struct TrackSessionTests {
    /// A helper's answers to `track` and `picture`, a 2 x 1 picture of 6 bytes.
    static func reply(to request: JSONValue) -> ScriptedReply {
        switch request["op"]?.stringValue {
        case "track":
            .answer(#"{"ok": true, "length": 480000, "notice": null, "style_notice": null}"#)
        case "picture":
            .answer(
                #"{"ok": true, "width": 2, "height": 1, "drawn": 47616, "bytes": 6}"#,
                payload: Data([1, 2, 3, 4, 5, 6]))
        default: .answer(#"{"ok": true, "cards": "d1"}"#)
        }
    }

    static let context = RenderContext(
        display: PixelSize(width: 1920, height: 720), viewing: .object(["distance_m": .integer(2)]),
        images: URL(filePath: "/images"),
        styles: ["mine": .object(["colors": .object([:])]), "other": .object([:])])

    static let scene = JSONValue.object([
        "name": .string("Mine"), "styles": .array([.string("mine")]),
        "cards": .array([.object(["card": .string("rta_bars")])]),
    ])

    static let track = DecodedTrack(
        source: TrackSource(
            url: URL(filePath: "/music/song.flac"), rate: 48_000, channels: 2,
            frames: 480_000),
        samples: URL(filePath: "/tmp/Tracks/abc.f32"), frames: 480_000)

    @Test func theTrackRequestCarriesTheSceneTheSamplesAndTheContext() async throws {
        let launcher = ScriptedLauncher { Self.reply(to: $0) }
        let session = TrackSession(helper: RenderHelper(launcher: launcher))
        let opening = try await session.open(
            Self.track, scene: Self.scene, builtIn: false, context: Self.context)
        #expect(opening == TrackOpening(length: 480_000, notice: nil, styleNotice: nil))
        let sent = try #require(launcher.requests.first)
        #expect(sent["op"] == .string("track"))
        #expect(sent["path"] == .string("/tmp/Tracks/abc.f32"))
        #expect(sent["rate"] == .integer(48_000))
        #expect(sent["channels"] == .integer(2))
        #expect(sent["scene"] == Self.scene)
        #expect(sent["built_in"] == .bool(false))
        #expect(sent["display"] == .array([.integer(1920), .integer(720)]))
        #expect(sent["viewing"] == Self.context.viewing)
        #expect(sent["images"] == .string("/images"))
        #expect(sent["styles"] == .object(["mine": .object(["colors": .object([:])])]))
        #expect(sent["plates"] == nil)
        #expect(sent["backdrop"] == nil)
    }

    @Test func aPictureIsItsBytes() async throws {
        let launcher = ScriptedLauncher { Self.reply(to: $0) }
        let session = TrackSession(helper: RenderHelper(launcher: launcher))
        _ = try await session.open(
            Self.track, scene: Self.scene, builtIn: false, context: Self.context)
        let picture = try await session.picture(at: 48_000)
        #expect(
            picture
                == TrackPicture(width: 2, height: 1, drawn: 47_616, rgb: Data([1, 2, 3, 4, 5, 6])))
        #expect(
            launcher.requests.last
                == .object(["op": .string("picture"), "moment": .integer(48_000)]))
    }

    @Test func theNoticesAreWordedForTheSheet() async throws {
        let launcher = ScriptedLauncher { _ in
            .answer(
                #"{"ok": true, "length": 1, "notice": "BACKDROP IMAGE MISSING", "#
                    + #""style_notice": "Style mine was not given."}"#)
        }
        let session = TrackSession(helper: RenderHelper(launcher: launcher))
        let opening = try await session.open(
            Self.track, scene: Self.scene, builtIn: false, context: Self.context)
        #expect(opening.notice == "The backdrop image is missing, so the default is shown.")
        #expect(opening.styleNotice == "Style mine was not given.")
    }

    @Test func aRefusedTrackSaysTheHelpersWords() async {
        let launcher = ScriptedLauncher { _ in
            .answer(#"{"ok": false, "refused": "the panel runs at 44100, 48000 Hz"}"#)
        }
        let session = TrackSession(helper: RenderHelper(launcher: launcher))
        await #expect(throws: RenderFailure.refused("the panel runs at 44100, 48000 Hz")) {
            try await session.open(
                Self.track, scene: Self.scene, builtIn: false, context: Self.context)
        }
    }

    @Test func aPictureOfAnotherSizeThanStatedFails() async throws {
        let launcher = ScriptedLauncher { request in
            request["op"] == .string("picture")
                ? .answer(
                    #"{"ok": true, "width": 2, "height": 2, "drawn": 0, "bytes": 6}"#,
                    payload: Data(count: 6))
                : Self.reply(to: request)
        }
        let session = TrackSession(helper: RenderHelper(launcher: launcher))
        _ = try await session.open(
            Self.track, scene: Self.scene, builtIn: false, context: Self.context)
        await #expect(throws: RenderFailure.self) { try await session.picture(at: 0) }
    }

    @Test func afterTheHelperEndsTheTrackIsOpenedAgainBeforeThePicture() async throws {
        let pictures = Mutex(0)
        let launcher = ScriptedLauncher { request in
            guard request["op"] == .string("picture") else { return Self.reply(to: request) }
            let count = pictures.withLock { count in
                count += 1
                return count
            }
            return count == 1 ? .end : Self.reply(to: request)
        }
        let session = TrackSession(helper: RenderHelper(launcher: launcher))
        _ = try await session.open(
            Self.track, scene: Self.scene, builtIn: false, context: Self.context)
        await #expect(throws: RenderFailure.ended) { try await session.picture(at: 96_000) }
        _ = try await session.picture(at: 96_000)
        #expect(launcher.launches == 2)
        #expect(
            launcher.requests.map { $0["op"]?.stringValue }
                == ["track", "picture", "track", "picture"])
    }
}
