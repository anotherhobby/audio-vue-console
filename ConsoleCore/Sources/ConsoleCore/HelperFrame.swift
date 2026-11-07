import Foundation

/// One answer from the render helper: its JSON, and the layers' bytes that follow it, in the order
/// its `layers` list them (audio-vue `scene-render`).
public struct HelperAnswer: Sendable, Equatable {
    public let header: JSONValue
    public let payload: Data
}

/// Why the helper's output could not be read as its protocol frames it.
enum HelperFrameError: Error, Equatable {
    case malformed
}

/// The render helper's framing: each message a 4-byte big-endian length and that many bytes of
/// UTF-8 JSON, an answer's layers' bytes after it.
enum HelperFrame {
    static let lengthSize = 4
    /// The longest header the app reads, far over any answer's: a longer length is a broken stream.
    static let headerLimit = 16_777_216

    /// `message` framed for the helper's standard input.
    static func encode(_ message: JSONValue) throws -> Data {
        let body = try message.encoded()
        let length = UInt32(body.count).bigEndian
        return withUnsafeBytes(of: length) { Data($0) } + body
    }

    /// The bytes a header says follow it: the sum of its layers' `bytes`.
    static func payloadLength(of header: JSONValue) throws(HelperFrameError) -> Int {
        guard let layers = header["layers"] else { return 0 }
        guard let list = layers.arrayValue else { throw .malformed }
        var total = 0
        for layer in list {
            guard let bytes = layer["bytes"]?.intValue, bytes >= 0 else { throw .malformed }
            total += bytes
        }
        return total
    }
}

/// Reassembles the helper's answers from its output, however the chunks fall.
struct HelperAnswerReader {
    private var buffer = Data()

    mutating func append(_ chunk: Data) {
        buffer.append(chunk)
    }

    /// The next whole answer, or nil until enough has arrived.
    mutating func next() throws(HelperFrameError) -> HelperAnswer? {
        guard buffer.count >= HelperFrame.lengthSize else { return nil }
        let length = Int(
            UInt32(
                bigEndian: buffer.prefix(HelperFrame.lengthSize).withUnsafeBytes {
                    $0.loadUnaligned(as: UInt32.self)
                }))
        guard length <= HelperFrame.headerLimit else { throw .malformed }
        let headerEnd = HelperFrame.lengthSize + length
        guard buffer.count >= headerEnd else { return nil }
        let header = try Self.header(buffer.dropFirst(HelperFrame.lengthSize).prefix(length))
        let end = headerEnd + (try HelperFrame.payloadLength(of: header))
        guard buffer.count >= end else { return nil }
        let payload = Data(buffer.dropFirst(headerEnd).prefix(end - headerEnd))
        buffer = Data(buffer.dropFirst(end))
        return HelperAnswer(header: header, payload: payload)
    }

    private static func header(_ bytes: Data) throws(HelperFrameError) -> JSONValue {
        do {
            return try JSONDecoder().decode(JSONValue.self, from: Data(bytes))
        } catch {
            throw .malformed
        }
    }
}
