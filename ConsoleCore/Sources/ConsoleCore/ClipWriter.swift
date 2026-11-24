import AVFoundation
import Accelerate
import CoreVideo
import VideoToolbox

/// Where a clip's pictures come from: the open track, or a script in tests.
public protocol ClipPictures: Sendable {
    func picture(at moment: Int) async throws(RenderFailure) -> TrackPicture
}

extension TrackSession: ClipPictures {}

/// The span's sound, as the reader gives it a buffer at a time.
typealias SoundProvider = AVAssetReaderOutput.Provider<
    CMReadySampleBuffer<CMSampleBuffer.DynamicContent>
>

/// A clip: the scene reading the track over a span, as a 10-bit HEVC MP4 carrying the track's sound
/// for that span (`track-render`, "A clip is a 10-bit HEVC MP4 of a span with its audio"; design D7).
public struct ClipWriter: Sendable {
    /// The span and its frames.
    public let plan: ClipPlan
    /// The track as the user picked it, read again for the clip's sound.
    public let audio: URL
    public let channels: Int
    /// The pictures' size, the panel's display.
    public let size: PixelSize

    /// The AAC bit rate, for music.
    static let audioBitRate = 256_000
    /// The encoder's quality, 0 to 1: at 0.8 a dark gradient backdrop keeps the steps of the
    /// helper's own picture, and its file is about the size of an 8-bit H.264 one (measured
    /// 2026-11-23, design D7).
    static let videoQuality = 0.8
    private static let alpha: UInt8 = 255
    /// The two rates AAC is written at, each the base of its family of rates.
    private static let cdFamily = 44_100
    private static let videoFamily = 48_000
    /// The sound is read as 32-bit float.
    private static let floatBits = 32

    /// Where a clip is written before it is moved to its destination.
    public let scratch: URL

    /// Where clips are written while they are made: the container's temporary directory.
    public static var defaultScratch: URL {
        FileManager.default.temporaryDirectory.appending(path: "Clips")
    }

    public init(
        plan: ClipPlan, audio: URL, channels: Int, size: PixelSize,
        scratch: URL = ClipWriter.defaultScratch
    ) {
        self.scratch = scratch
        self.plan = plan
        self.audio = audio
        self.channels = channels
        self.size = size
    }

    /// The rate the clip's sound is written at: AAC is written only at 44.1 or 48 kHz
    /// (measured, design D7), so a track's own rate where it is one of those, else its family's.
    public static func soundRate(for rate: Int) -> Int {
        rate.isMultiple(of: cdFamily) ? cdFamily : videoFamily
    }

    /// Writes the clip to `destination`, a frame at a time, calling `progress` with the frames
    /// written. It is written to a temporary file first and moved there whole, so a cancelled or
    /// failed clip leaves nothing at `destination`.
    @concurrent
    public func write(
        to destination: URL, from pictures: some ClipPictures,
        progress: @escaping @Sendable (Int) -> Void = { _ in }
    ) async throws(ExportFailure) {
        let temporary = scratch.appending(path: "\(UUID().uuidString).mp4")
        do {
            try FileManager.default.createDirectory(
                at: temporary.deletingLastPathComponent(), withIntermediateDirectories: true)
            try await encode(to: temporary, from: pictures, progress: progress)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temporary, to: destination)
        } catch {
            DecodedTrack.discard(temporary)
            throw Self.failure(error)
        }
    }

    private func encode(
        to file: URL, from pictures: some ClipPictures, progress: @escaping @Sendable (Int) -> Void
    ) async throws {
        let writer = try AVAssetWriter(outputURL: file, fileType: .mp4)
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let sound = AVAssetWriterInput(mediaType: .audio, outputSettings: soundSettings)
        let frames = writer.inputPixelBufferReceiver(for: video, pixelBufferAttributes: attributes)
        let samples = writer.inputReceiver(for: sound)
        let (reader, output) = try await soundReader()
        let provider = reader.outputProvider(for: output)
        let pool = try CVMutablePixelBuffer.Pool(pixelBufferAttributes: attributes)
        try writer.start()
        try reader.start()
        writer.startSession(atSourceTime: startTime)
        do {
            // Each input is fed as the writer takes from it, so the writer interleaves them.
            async let sound: Void = Self.feed(samples, from: provider)
            async let video: Void = feed(frames, pool: pool, from: pictures, progress: progress)
            _ = try await (sound, video)
        } catch {
            reader.cancelReading()
            writer.cancelWriting()
            throw error
        }
        writer.endSession(atSourceTime: endTime)
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw ExportFailure.failed(
                writer.error?.localizedDescription ?? "The clip did not finish.")
        }
    }

    /// Appends the span's sound as the writer takes it, then finishes it.
    private static func feed(
        _ receiver: AVAssetWriterInput.SampleBufferReceiver,
        from provider: SoundProvider
    ) async throws {
        while let buffer = try await provider.next() {
            try await receiver.append(buffer)
        }
        receiver.finish()
    }

    /// Appends each frame as the writer takes it, asking for its picture only then, so at most one
    /// picture is held; then finishes.
    private func feed(
        _ receiver: AVAssetWriterInput.PixelBufferReceiver, pool: CVMutablePixelBuffer.Pool,
        from pictures: some ClipPictures, progress: @Sendable (Int) -> Void
    ) async throws {
        for index in 0..<plan.count {
            try Task.checkCancellation()
            let picture = try await pictures.picture(at: plan.moment(index))
            guard picture.width == size.width, picture.height == size.height else {
                throw ExportFailure.unusablePicture
            }
            var buffer = try pool.makeMutablePixelBuffer()
            try Self.convert(picture, into: &buffer)
            let time = CMTimeAdd(
                startTime, CMTime(value: CMTimeValue(index), timescale: Int32(plan.fps)))
            try await receiver.append(CVReadOnlyPixelBuffer(buffer), with: time)
            progress(index + 1)
        }
        receiver.finish()
    }

    /// Copies `picture`'s RGB into `buffer` as BGRA, opaque.
    private static func convert(
        _ picture: TrackPicture, into buffer: inout CVMutablePixelBuffer
    ) throws {
        var rgb = picture.rgb
        let status = rgb.withUnsafeMutableBytes { raw in
            buffer.accessUnsafeMutableRawPlaneBytes { planes in
                guard let plane = planes.first else { return kvImageInvalidParameter }
                var source = vImage_Buffer(
                    data: raw.baseAddress, height: vImagePixelCount(picture.height),
                    width: vImagePixelCount(picture.width),
                    rowBytes: picture.width * TrackPicture.bytesPerPixel)
                var target = vImage_Buffer(
                    data: plane.bytes.baseAddress, height: vImagePixelCount(picture.height),
                    width: vImagePixelCount(picture.width),
                    rowBytes: plane.properties.bytesPerRow)
                return vImageConvert_RGB888toBGRA8888(
                    &source, nil, alpha, &target, false, vImage_Flags(kvImageNoFlags))
            }
        }
        guard status == kvImageNoError else { throw ExportFailure.unusablePicture }
    }

    /// A reader of the track's sound over the span, as interleaved float at the clip's sound rate.
    private func soundReader() async throws -> (AVAssetReader, AVAssetReaderTrackOutput) {
        let asset = AVURLAsset(url: audio)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw ExportFailure.failed("The track's sound could not be read.")
        }
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: startTime, end: endTime)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: Self.floatBits,
                AVLinearPCMIsFloatKey: true, AVLinearPCMIsNonInterleaved: false,
                AVLinearPCMIsBigEndianKey: false, AVSampleRateKey: Self.soundRate(for: plan.rate),
                AVNumberOfChannelsKey: channels,
            ])
        return (reader, output)
    }

    private var startTime: CMTime {
        CMTime(seconds: plan.start, preferredTimescale: Int32(plan.rate))
    }
    private var endTime: CMTime { CMTime(seconds: plan.end, preferredTimescale: Int32(plan.rate)) }

    /// 10-bit HEVC: 8-bit 4:2:0 H.264 cannot hold a dark, slow gradient without banding (design D7).
    /// Tagged with the sRGB curve, which the helper's pixels are in, so a player shows the panel's
    /// colours.
    private var videoSettings: [String: Any] {
        [
            AVVideoCodecKey: AVVideoCodecType.hevc, AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel,
                AVVideoQualityKey: Self.videoQuality,
            ],
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_IEC_sRGB,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ]
    }

    private var attributes: CVPixelBufferCreationAttributes {
        CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA),
            size: CVImageSize(width: size.width, height: size.height))
    }

    private var soundSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: Self.soundRate(for: plan.rate),
            AVNumberOfChannelsKey: channels, AVEncoderBitRateKey: Self.audioBitRate,
        ]
    }

    private static func failure(_ error: any Error) -> ExportFailure {
        if let failure = error as? ExportFailure { return failure }
        if error is CancellationError || Task.isCancelled { return .cancelled }
        if let render = error as? RenderFailure { return .failed(String(describing: render)) }
        return .failed(error.localizedDescription)
    }
}
