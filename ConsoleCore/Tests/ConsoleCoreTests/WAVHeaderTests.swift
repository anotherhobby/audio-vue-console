import Foundation
import Testing

@testable import ConsoleCore

/// A WAV's rate and length, read from its header (design D3).
struct WAVHeaderTests {
    /// A 24-bit stereo WAV header for `seconds` at `rate`, with a chunk before `fmt ` as some
    /// writers put, and no samples after it.
    static func header(rate: Int, seconds: Double) -> Data {
        let channels = 2
        let bytesPerSample = 3
        let byteRate = rate * channels * bytesPerSample
        let dataSize = Int(Double(byteRate) * seconds)
        var data = Data("RIFF".utf8)
        data.append(word(UInt32(36 + dataSize + 12)))
        data.append(contentsOf: Data("WAVE".utf8))
        data.append(contentsOf: Data("LIST".utf8) + word(4) + Data("INFO".utf8))
        data.append(contentsOf: Data("fmt ".utf8) + word(16))
        data.append(contentsOf: half(1) + half(UInt16(channels)) + word(UInt32(rate)))
        data.append(contentsOf: word(UInt32(byteRate)) + half(UInt16(channels * bytesPerSample)))
        data.append(contentsOf: half(UInt16(bytesPerSample * 8)))
        data.append(contentsOf: Data("data".utf8) + word(UInt32(dataSize)))
        return data
    }

    private static func word(_ value: UInt32) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    private static func half(_ value: UInt16) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    @Test func aCalibrationsRateAndLength() throws {
        let header = try #require(WAVHeader(Self.header(rate: 96_000, seconds: 12.2)))
        #expect(header.rate == 96_000)
        #expect(abs(header.seconds - 12.2) < 0.001)
    }

    @Test func somethingElseIsNotAHeader() {
        #expect(WAVHeader(Data("not a wav file at all".utf8)) == nil)
    }

    @Test func theRealCalibrationFileIfThere() throws {
        let file = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../../audio-vue/local/calibration-96k.wav").standardized
        guard FileManager.default.fileExists(atPath: file.path()) else { return }
        let header = try #require(WAVHeader(contentsOf: file))
        #expect(header.rate == 96_000)
        #expect(abs(header.seconds - 12.2) < 0.05)
    }
}
