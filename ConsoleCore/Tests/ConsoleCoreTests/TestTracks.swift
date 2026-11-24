import AVFoundation
import Foundation
import Testing

@testable import ConsoleCore

/// Audio files made for the track tests, each a sine in its own new directory, removed with it.
enum TestTracks {
    /// A frequency well inside every rate's band.
    static let sineHz = 1000.0
    private static let level: Float = 0.25

    /// A fresh directory in the temporary directory, for one test's files.
    static func directory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TrackTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// A float WAV of a sine, each channel the same, in `directory`.
    static func wav(rate: Int, channels: Int, seconds: Double, in directory: URL) throws -> URL {
        let url = directory.appending(path: "sine-\(rate)-\(channels).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: Double(rate),
            AVNumberOfChannelsKey: channels, AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true, AVLinearPCMIsNonInterleaved: false,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)
        let frames = AVAudioFrameCount((Double(rate) * seconds).rounded())
        let buffer = try #require(
            AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames))
        buffer.frameLength = frames
        let planes = try #require(buffer.floatChannelData)
        for frame in 0..<Int(frames) {
            let value = sample(frame, rate: rate)
            for channel in 0..<channels { planes[channel][frame] = value }
        }
        try file.write(from: buffer)
        return url
    }

    /// The value `wav` writes at `frame`.
    static func sample(_ frame: Int, rate: Int) -> Float {
        level * Float(sin(2 * .pi * sineHz * Double(frame) / Double(rate)))
    }

    /// The rates the fixture schema lists for `install.input.rate`.
    static func panelRates() throws -> [Int] {
        let file = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "Fixtures/schema-trimmed.json")
        let schema = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: file))
        return try #require(SchemaFacts.inputRates(schema))
    }
}
