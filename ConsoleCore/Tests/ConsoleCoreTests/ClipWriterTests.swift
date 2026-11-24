import AVFoundation
import Foundation
import Synchronization
import Testing

@testable import ConsoleCore

/// `track-render`, "A clip is a 10-bit HEVC MP4 of a span with its audio" and "A clip's export shows its
/// progress and can be cancelled".
struct ClipWriterTests {
    private static let size = PixelSize(width: 64, height: 32)

    /// Pictures of one grey that brightens frame by frame, counting the moments asked for.
    final class ScriptedPictures: ClipPictures {
        let asked = Mutex([Int]())
        private let stopAfter: Int?
        private let task = Mutex<Task<Void, any Error>?>(nil)

        init(stopAfter: Int? = nil) {
            self.stopAfter = stopAfter
        }

        func cancel(_ export: Task<Void, any Error>) {
            task.withLock { $0 = export }
        }

        func picture(at moment: Int) async throws(RenderFailure) -> TrackPicture {
            let count = asked.withLock { asked in
                asked.append(moment)
                return asked.count
            }
            if count == stopAfter { task.withLock { $0 }?.cancel() }
            let grey = UInt8(truncatingIfNeeded: count * 4)
            return TrackPicture(
                width: size.width, height: size.height, drawn: moment,
                rgb: Data(
                    repeating: grey,
                    count: TrackPicture.byteCount(width: size.width, height: size.height)))
        }
    }

    private static func clip(rate: Int, in directory: URL) throws -> ClipWriter {
        let audio = try TestTracks.wav(rate: rate, channels: 2, seconds: 3, in: directory)
        return ClipWriter(
            plan: ClipPlan(rate: rate, fps: 30, start: 0.5, end: 2.5), audio: audio, channels: 2,
            size: size, scratch: directory.appending(path: "Clips"))
    }

    @Test(arguments: [(96_000, 48_000.0), (88_200, 44_100.0)])
    func aTwoSecondClipAtThirty(rate: Int, soundRate: Double) async throws {
        let directory = try TestTracks.directory()
        defer { DecodedTrack.discard(directory) }
        let writer = try Self.clip(rate: rate, in: directory)
        let pictures = ScriptedPictures()
        let written = Mutex(0)
        let destination = directory.appending(path: "clip.mp4")
        try await writer.write(to: destination, from: pictures) { count in
            written.withLock { $0 = count }
        }
        #expect(written.withLock { $0 } == 60)
        #expect(pictures.asked.withLock { $0 }.first == rate / 2)

        let asset = AVURLAsset(url: destination)
        let seconds = try await asset.load(.duration).seconds
        #expect(abs(seconds - 2.0) < 0.05)
        let video = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let (naturalSize, formats) = try await video.load(.naturalSize, .formatDescriptions)
        #expect(naturalSize == CGSize(width: 64, height: 32))
        let format = try #require(formats.first)
        #expect(CMFormatDescriptionGetMediaSubType(format) == kCMVideoCodecType_HEVC)
        #expect(
            Self.extension(kCMFormatDescriptionExtension_BitsPerComponent, of: format) as? Int == 10
        )
        #expect(
            Self.extension(kCMFormatDescriptionExtension_TransferFunction, of: format) as? String
                == kCMFormatDescriptionTransferFunction_sRGB as String)
        let frames = try await Self.frameCount(of: video, in: asset)
        #expect(frames == 60)
        let sound = try #require(try await asset.loadTracks(withMediaType: .audio).first)
        let description = try #require(try await sound.load(.formatDescriptions).first)
        let basic = try #require(CMAudioFormatDescriptionGetStreamBasicDescription(description))
        #expect(basic.pointee.mFormatID == kAudioFormatMPEG4AAC)
        #expect(basic.pointee.mSampleRate == soundRate)
    }

    @Test func aCancelledClipLeavesNoFile() async throws {
        let directory = try TestTracks.directory()
        defer { DecodedTrack.discard(directory) }
        let writer = try Self.clip(rate: 48_000, in: directory)
        let pictures = ScriptedPictures(stopAfter: 10)
        let destination = directory.appending(path: "clip.mp4")
        let export = Task { try await writer.write(to: destination, from: pictures) }
        pictures.cancel(export)
        await #expect(throws: ExportFailure.cancelled) { try await export.value }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
        #expect(try Self.files(in: writer.scratch).isEmpty)
    }

    /// The files in `directory`, none where it does not exist yet.
    private static func files(in directory: URL) throws -> Set<String> {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return Set(try FileManager.default.contentsOfDirectory(atPath: directory.path))
    }

    private static func `extension`(_ key: CFString, of format: CMFormatDescription) -> Any? {
        CMFormatDescriptionGetExtension(format, extensionKey: key)
    }

    private static func frameCount(of track: AVAssetTrack, in asset: AVAsset) async throws -> Int {
        let reader = try AVAssetReader(asset: asset)
        let provider = reader.outputProvider(
            for: AVAssetReaderTrackOutput(track: track, outputSettings: nil))
        try reader.start()
        var count = 0
        while let buffer = try await provider.next() {
            count += buffer.sampleCount
        }
        return count
    }
}
