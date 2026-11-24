import Foundation
import Testing

@testable import ConsoleCore

/// `track-render`, "A track is decoded at its own rate", "A track of more than two channels is
/// refused" and "The decoded samples are removed with the sheet".
struct TrackSourceTests {
    @Test func aStereoTrackDecodesInterleavedAtItsOwnRate() async throws {
        let directory = try TestTracks.directory()
        defer { DecodedTrack.discard(directory) }
        let url = try TestTracks.wav(rate: 48_000, channels: 2, seconds: 1, in: directory)
        let source = try TrackSource.open(url, rates: try TestTracks.panelRates())
        #expect(source.rate == 48_000)
        #expect(source.channels == 2)
        #expect(source.frames == 48_000)
        #expect(source.name == "sine-48000-2.wav")
        let track = try await source.decode(into: directory)
        #expect(track.frames == 48_000)
        let data = try Data(contentsOf: track.samples)
        #expect(data.count == 384_000)
        let floats = Self.floats(data)
        for frame in [0, 1, 17, 47_999] {
            #expect(floats[frame * 2] == TestTracks.sample(frame, rate: 48_000))
            #expect(floats[frame * 2 + 1] == TestTracks.sample(frame, rate: 48_000))
        }
    }

    @Test func aMonoTrackStaysOneChannel() async throws {
        let directory = try TestTracks.directory()
        defer { DecodedTrack.discard(directory) }
        let url = try TestTracks.wav(rate: 44_100, channels: 1, seconds: 0.5, in: directory)
        let source = try TrackSource.open(url, rates: try TestTracks.panelRates())
        #expect(source.channels == 1)
        let track = try await source.decode(into: directory)
        #expect(try Data(contentsOf: track.samples).count == 22_050 * 4)
    }

    @Test func aRateThePanelDoesNotRunAtIsRefusedNamingItsRates() throws {
        let directory = try TestTracks.directory()
        defer { DecodedTrack.discard(directory) }
        let url = try TestTracks.wav(rate: 22_050, channels: 2, seconds: 0.1, in: directory)
        let refusal = #expect(throws: TrackRefusal.self) {
            try TrackSource.open(url, rates: try TestTracks.panelRates())
        }
        #expect(
            refusal?.description
                == "This track is at 22.05 kHz. The panel runs at 44.1, 48, 88.2, 96, and 192 kHz.")
    }

    @Test func moreThanTwoChannelsIsRefused() throws {
        let directory = try TestTracks.directory()
        defer { DecodedTrack.discard(directory) }
        let url = try TestTracks.wav(rate: 48_000, channels: 6, seconds: 0.1, in: directory)
        #expect(throws: TrackRefusal.channels(6)) {
            try TrackSource.open(url, rates: try TestTracks.panelRates())
        }
    }

    @Test func aFileThatIsNotAudioIsRefused() throws {
        let directory = try TestTracks.directory()
        defer { DecodedTrack.discard(directory) }
        let url = directory.appending(path: "notes.wav")
        try Data("not audio".utf8).write(to: url)
        #expect {
            try TrackSource.open(url, rates: try TestTracks.panelRates())
        } throws: { error in
            if case .unreadable = error as? TrackRefusal { return true }
            return false
        }
    }

    @Test func removingLeavesNoFile() async throws {
        let directory = try TestTracks.directory()
        defer { DecodedTrack.discard(directory) }
        let url = try TestTracks.wav(rate: 96_000, channels: 2, seconds: 0.2, in: directory)
        let track = try await TrackSource.open(url, rates: try TestTracks.panelRates())
            .decode(into: directory)
        #expect(FileManager.default.fileExists(atPath: track.samples.path))
        track.remove()
        #expect(!FileManager.default.fileExists(atPath: track.samples.path))
    }

    private static func floats(_ data: Data) -> [Float] {
        data.withUnsafeBytes { raw in
            raw.bindMemory(to: UInt32.self).map { Float(bitPattern: UInt32(littleEndian: $0)) }
        }
    }
}
