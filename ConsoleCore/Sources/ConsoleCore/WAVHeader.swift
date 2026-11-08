import Foundation

/// What a WAV file's header says of its audio: its rate and how long it plays, read from the `fmt `
/// and `data` chunks, so a run shows its time left without a figure written down (design D3).
public struct WAVHeader: Sendable, Equatable {
    public let rate: Int
    public let seconds: Double

    /// The header at the start of `data`, or nil where it is not a WAV's.
    public init?(_ data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count >= Self.firstChunk, Self.tag(bytes, 0) == "RIFF",
            Self.tag(bytes, Self.waveTag) == "WAVE"
        else { return nil }
        var offset = Self.firstChunk
        var byteRate: UInt32?
        var rate: UInt32?
        while offset + Self.chunkHeader <= bytes.count {
            let size = Self.word(bytes, offset + Self.sizeField)
            let body = offset + Self.chunkHeader
            switch Self.tag(bytes, offset) {
            case "fmt " where body + Self.byteRateField + Self.sizeField <= bytes.count:
                rate = Self.word(bytes, body + Self.rateField)
                byteRate = Self.word(bytes, body + Self.byteRateField)
            case "data":
                guard let rate, let byteRate, byteRate > 0 else { return nil }
                self.rate = Int(rate)
                seconds = Double(size) / Double(byteRate)
                return
            default: break
            }
            offset = body + Int(size) + Int(size % 2)
        }
        return nil
    }

    /// The header of the file at `url`, read from its first bytes.
    public init?(contentsOf url: URL) {
        guard let data = Self.firstBytes(of: url) else { return nil }
        self.init(data)
    }

    private static func firstBytes(of url: URL) -> Data? {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            return nil
        }
        defer {
            do {
                try handle.close()
            } catch {
                // Read already; a failed close loses nothing.
            }
        }
        do {
            return try handle.read(upToCount: headerBytes)
        } catch {
            return nil
        }
    }

    /// Enough of a file to hold its header and any chunks before its audio.
    private static let headerBytes = 65_536
    private static let firstChunk = 12
    private static let waveTag = 8
    private static let chunkHeader = 8
    private static let sizeField = 4
    private static let rateField = 4
    private static let byteRateField = 8

    private static func tag(_ bytes: [UInt8], _ at: Int) -> String {
        String(bytes: bytes[at..<at + sizeField], encoding: .ascii) ?? ""
    }

    private static func word(_ bytes: [UInt8], _ at: Int) -> UInt32 {
        bytes[at..<at + sizeField].reversed().reduce(0) {
            $0 << UInt32(UInt8.bitWidth) | UInt32($1)
        }
    }
}
