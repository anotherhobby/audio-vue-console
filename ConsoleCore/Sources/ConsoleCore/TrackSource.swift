import AVFoundation

/// Why a track cannot be rendered from (`track-render`).
public enum TrackRefusal: Error, Sendable, Equatable, CustomStringConvertible {
    /// The Mac cannot read the file as audio, and why.
    case unreadable(String)
    /// The track is at a rate the panel does not run at: the track's rate, then the panel's.
    case rate(Int, panel: [Int])
    /// The track has more than two channels.
    case channels(Int)
    /// The file holds no audio.
    case empty
    /// Decoding stopped part way, and why.
    case failed(String)
    /// Decoding was stopped by its caller.
    case cancelled

    public var description: String {
        switch self {
        case .unreadable(let reason): "This file can't be read as audio. \(reason)"
        case .rate(let rate, let panel):
            "This track is at \(RateText.text(rate)). The panel runs at \(Self.list(panel))."
        case .channels(let count):
            "This track has \(count) channels. A track for the panel has one or two."
        case .empty: "This file holds no audio."
        case .failed(let reason): "The track could not be decoded. \(reason)"
        case .cancelled: "Decoding was stopped."
        }
    }

    /// `rates` as one list in kilohertz, the unit said once: "44.1, 48 and 96 kHz".
    private static func list(_ rates: [Int]) -> String {
        let numbers = rates.map { RateText.text($0).replacing(" kHz", with: "") }
        return "\(numbers.formatted(.list(type: .and))) kHz"
    }
}

/// A music track the user picked, opened but not yet decoded: what the sheet shows of it, checked
/// against what the panel takes before any of it is decoded (`track-render`, "A track is decoded at
/// its own rate" and "A track of more than two channels is refused").
public struct TrackSource: Sendable, Equatable {
    /// The file as the user picked it.
    public let url: URL
    /// The track's own rate, in Hz.
    public let rate: Int
    /// One or two.
    public let channels: Int
    /// The track's length in sample frames, as the file states it.
    public let frames: Int

    /// The file's name, as the sheet shows it.
    public var name: String { url.lastPathComponent }
    /// The track's length in seconds.
    public var seconds: Double { Double(frames) / Double(rate) }

    /// The frames decoded at a time, so a long track is never held whole (design D3).
    static let chunkFrames: AVAudioFrameCount = 65_536
    /// The status `AVAudioFile` reads with past the last frame (`eofErr`).
    private static let endOfFile = -39

    /// Opens `url` and checks it against `rates`, the rates the panel runs at as the host's schema
    /// lists them.
    public static func open(_ url: URL, rates: [Int]) throws(TrackRefusal) -> TrackSource {
        let file = try audioFile(url)
        let rate = Int(file.fileFormat.sampleRate.rounded())
        let channels = Int(file.fileFormat.channelCount)
        guard rates.contains(rate) else { throw .rate(rate, panel: rates) }
        guard channels <= 2 else { throw .channels(channels) }
        guard file.length > 0 else { throw .empty }
        return TrackSource(url: url, rate: rate, channels: channels, frames: Int(file.length))
    }

    /// Where decoded tracks are written: the container's temporary directory, which the helper's
    /// sandbox can read (`pitfalls.md`).
    public static var defaultDirectory: URL {
        FileManager.default.temporaryDirectory.appending(path: "Tracks")
    }

    /// The track's samples as the helper reads them: 32-bit float, little-endian, interleaved, no
    /// header, at the track's own rate, in a new file in `directory`. A cancelled or failed decode
    /// leaves no file.
    @concurrent
    public func decode(into directory: URL = TrackSource.defaultDirectory)
        async throws(TrackRefusal)
        -> DecodedTrack
    {
        let samples = directory.appending(path: "\(UUID().uuidString).f32")
        do {
            let frames = try write(to: samples, in: directory)
            guard frames > 0 else { throw TrackRefusal.empty }
            return DecodedTrack(source: self, samples: samples, frames: frames)
        } catch {
            DecodedTrack.discard(samples)
            throw error as? TrackRefusal ?? .failed(error.localizedDescription)
        }
    }

    /// Writes the interleaved samples to `samples`, answering the frames written. A close that
    /// fails after a whole write is a failed write, since the last bytes may not have reached disk.
    private func write(to samples: URL, in directory: URL) throws -> Int {
        let file = try Self.audioFile(url)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: samples.path, contents: nil)
        let handle = try FileHandle(forWritingTo: samples)
        let written: Int
        do {
            written = try fill(handle, from: file)
        } catch {
            do {
                try handle.close()
            } catch {
                // The write failed already, and the caller removes the file.
            }
            throw error
        }
        try handle.close()
        return written
    }

    /// Decodes `file` into `handle` a chunk at a time, answering the frames written.
    private func fill(_ handle: FileHandle, from file: AVAudioFile) throws -> Int {
        guard
            let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat, frameCapacity: Self.chunkFrames)
        else { throw TrackRefusal.failed("No buffer could be made for its format.") }
        var written = 0
        while file.framePosition < file.length {
            if Task.isCancelled { throw TrackRefusal.cancelled }
            let left = AVAudioFrameCount(clamping: file.length - file.framePosition)
            do {
                try file.read(into: buffer, frameCount: min(Self.chunkFrames, left))
            } catch let error as NSError where error.code == Self.endOfFile {
                // A compressed file can state more frames than it decodes to.
                return written
            }
            guard buffer.frameLength > 0 else { return written }
            try handle.write(contentsOf: Self.interleaved(buffer, channels: channels))
            written += Int(buffer.frameLength)
        }
        return written
    }

    /// `buffer`'s first `channels` channels, frame by frame, each sample little-endian.
    static func interleaved(_ buffer: AVAudioPCMBuffer, channels: Int) -> Data {
        let frames = Int(buffer.frameLength)
        guard let planes = buffer.floatChannelData else { return Data() }
        var bits = [UInt32](repeating: 0, count: frames * channels)
        for frame in 0..<frames {
            for channel in 0..<channels {
                bits[frame * channels + channel] = planes[channel][frame].bitPattern.littleEndian
            }
        }
        return bits.withUnsafeBytes { Data($0) }
    }

    private static func audioFile(_ url: URL) throws(TrackRefusal) -> AVAudioFile {
        do {
            return try AVAudioFile(forReading: url)
        } catch {
            throw .unreadable(error.localizedDescription)
        }
    }

}

/// A track decoded for the helper: its source and the file of its samples, kept only while the
/// sheet is open (`track-render`, "The decoded samples are removed with the sheet").
public struct DecodedTrack: Sendable, Equatable {
    public let source: TrackSource
    /// The file of interleaved float32 samples.
    public let samples: URL
    /// The frames decoded, which a compressed file may state only roughly.
    public let frames: Int

    /// Deletes the decoded samples.
    public func remove() {
        Self.discard(samples)
    }

    static func discard(_ file: URL) {
        do {
            try FileManager.default.removeItem(at: file)
        } catch {
            // Already gone, or in the temporary directory the system clears.
        }
    }
}
